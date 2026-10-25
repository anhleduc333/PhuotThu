import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../group_travel/data/trip_invitation_providers.dart';
import '../../../group_travel/domain/trip_invitation.dart';
import '../../../group_travel/domain/trip_invitation_inbox_item.dart';
import '../../data/trip_providers.dart';
import '../../domain/trip.dart';

class TripsPage extends ConsumerWidget {
  const TripsPage({super.key});

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Bản nháp';
      case 'planned':
        return 'Đã lên kế hoạch';
      case 'active':
        return 'Đang diễn ra';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Chưa đặt thời gian';
    }

    final local = value.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} • $hour:$minute';
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(currentTripsProvider);
    ref.invalidate(myPendingTripInvitationsProvider);

    try {
      await Future.wait([
        ref.read(currentTripsProvider.future),
        ref.read(myPendingTripInvitationsProvider.future),
      ]);
    } catch (_) {
      // Các AsyncValue tương ứng sẽ tự hiển thị lỗi trên UI.
    }
  }

  Future<void> _respondToInvitation(
    BuildContext context,
    WidgetRef ref, {
    required TripInvitationInboxItem invitation,
    required bool accept,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(accept ? 'Chấp nhận lời mời?' : 'Từ chối lời mời?'),
          content: Text(
            accept
                ? 'Bạn sẽ tham gia chuyến '
                      '"${invitation.tripName}" với vai trò '
                      '${invitation.role.label}.'
                : 'Bạn có chắc muốn từ chối lời mời tham gia '
                      'chuyến "${invitation.tripName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(accept ? 'Chấp nhận' : 'Từ chối'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(tripInvitationRepositoryProvider)
          .respondToInvitation(
            invitationId: invitation.invitationId,
            accept: accept,
          );

      ref.invalidate(myPendingTripInvitationsProvider);
      ref.invalidate(currentTripsProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Đã chấp nhận lời mời tham gia '
                      '"${invitation.tripName}".'
                : 'Đã từ chối lời mời tham gia '
                      '"${invitation.tripName}".',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Không thể chấp nhận lời mời: $error'
                : 'Không thể từ chối lời mời: $error',
          ),
        ),
      );
    }
  }

  List<Widget> _buildInvitationSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TripInvitationInboxItem>> invitationsAsync,
  ) {
    return invitationsAsync.when(
      loading: () {
        return [
          const Card(
            child: ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Lời mời chuyến đi'),
              subtitle: Text('Đang kiểm tra lời mời...'),
            ),
          ),
          const SizedBox(height: 16),
        ];
      },
      error: (error, stackTrace) {
        return [
          Card(
            child: ListTile(
              leading: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Không thể tải lời mời chuyến đi'),
              subtitle: const Text('Nhấn thử lại để tải danh sách lời mời.'),
              trailing: IconButton(
                onPressed: () {
                  ref.invalidate(myPendingTripInvitationsProvider);
                },
                tooltip: 'Thử lại',
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ];
      },
      data: (invitations) {
        if (invitations.isEmpty) {
          return const [];
        }

        return [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Lời mời chuyến đi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Chip(label: Text('${invitations.length}')),
            ],
          ),
          const SizedBox(height: 8),
          ...invitations.expand(
            (invitation) => [
              _TripInvitationCard(
                invitation: invitation,
                expiresAt: _formatDate(invitation.expiresAt),
                onDecline: () {
                  _respondToInvitation(
                    context,
                    ref,
                    invitation: invitation,
                    accept: false,
                  );
                },
                onAccept: () {
                  _respondToInvitation(
                    context,
                    ref,
                    invitation: invitation,
                    accept: true,
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
          const SizedBox(height: 8),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(currentTripsProvider);

    final invitationsAsync = ref.watch(myPendingTripInvitationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chuyến đi')),
      body: SafeArea(
        child: tripsAsync.when(
          loading: () {
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, stackTrace) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    const Text('Không thể tải danh sách chuyến đi.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(currentTripsProvider);

                        ref.invalidate(myPendingTripInvitationsProvider);
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (trips) {
            final invitationWidgets = _buildInvitationSection(
              context,
              ref,
              invitationsAsync,
            );

            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  ...invitationWidgets,

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Chuyến đi của tôi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (trips.isNotEmpty)
                        Chip(label: Text('${trips.length}')),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (trips.isEmpty)
                    const _EmptyTripsView()
                  else
                    ...trips.expand(
                      (trip) => [
                        _TripCard(
                          trip: trip,
                          statusLabel: _statusLabel(trip.status),
                          startDate: _formatDate(trip.plannedStartAt),
                          onTap: () async {
                            await context.push('/trips/${trip.id}');

                            ref.invalidate(currentTripsProvider);

                            ref.invalidate(myPendingTripInvitationsProvider);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),

                  const SizedBox(height: 88),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/trips/create');

          ref.invalidate(currentTripsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo chuyến'),
      ),
    );
  }
}

class _EmptyTripsView extends StatelessWidget {
  const _EmptyTripsView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_outlined, size: 72),
          SizedBox(height: 16),
          Text(
            'Chưa có chuyến đi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Tạo chuyến đi đầu tiên để bắt đầu '
            'lập kế hoạch cùng PhuotThu.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TripInvitationCard extends StatelessWidget {
  const _TripInvitationCard({
    required this.invitation,
    required this.expiresAt,
    required this.onDecline,
    required this.onAccept,
  });

  final TripInvitationInboxItem invitation;
  final String expiresAt;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.group_add_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.tripName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('Vai trò: ${invitation.role.label}'),
                    ],
                  ),
                ),
              ],
            ),

            if (invitation.routeLabel != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.route_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(invitation.routeLabel!)),
                ],
              ),
            ],

            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Hết hạn: $expiresAt')),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDecline,
                    icon: const Icon(Icons.close),
                    label: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check),
                    label: const Text('Chấp nhận'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.statusLabel,
    required this.startDate,
    required this.onTap,
  });

  final Trip trip;
  final String statusLabel;
  final String startDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final routeText = [
      if (trip.startName != null && trip.startName!.isNotEmpty) trip.startName!,
      if (trip.destinationName != null && trip.destinationName!.isNotEmpty)
        trip.destinationName!,
    ].join(' → ');

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(child: Icon(Icons.route)),
        title: Text(trip.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (routeText.isNotEmpty) Text(routeText),
            Text(startDate),
            Text(statusLabel),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
