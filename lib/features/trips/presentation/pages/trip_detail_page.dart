import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../group_travel/data/group_trip_providers.dart';
import '../../../group_travel/data/trip_live_location_publisher_providers.dart';
import '../../../group_travel/data/trip_live_location_sharing_service.dart';
import '../../../group_travel/data/trip_invitation_providers.dart';
import '../../../group_travel/domain/group_trip_state.dart';
import '../../../group_travel/domain/trip_invitation.dart';
import '../../../group_travel/domain/trip_invitation_request.dart';
import '../../../group_travel/domain/trip_member.dart';
import '../../../group_travel/domain/trip_member_view.dart';
import '../../../group_travel/presentation/trip_group_live_map_page.dart';
import '../../../group_travel/presentation/trip_checkpoint_management_page.dart';
import '../../../vehicle/data/vehicle_providers.dart';
import '../../../vehicle/domain/vehicle.dart';
import '../../data/trip_budget_providers.dart';
import '../../data/trip_providers.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip.dart';
import '../../domain/trip_budget_item.dart';

class TripDetailPage extends ConsumerWidget {
  const TripDetailPage({required this.tripId, super.key});

  final String tripId;

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

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Chưa chọn';
    }

    final local = value.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} '
        '$hour:$minute';
  }

  String _formatDistance(int? meters) {
    if (meters == null) {
      return 'Chưa tính';
    }

    if (meters < 1000) {
      return '$meters m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) {
      return 'Chưa tính';
    }

    final totalMinutes = (seconds / 60).round();

    final hours = totalMinutes ~/ 60;

    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return '$minutes phút';
    }

    if (minutes == 0) {
      return '$hours giờ';
    }

    return '$hours giờ $minutes phút';
  }

  String _formatFuel(double? liters) {
    if (liters == null) {
      return 'Chưa tính';
    }

    return '${liters.toStringAsFixed(1)} lít';
  }

  String _formatVnd(double? value) {
    if (value == null) {
      return 'Chưa tính';
    }

    final negative = value < 0;

    final digits = value.abs().round().toString();

    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(digits[i]);
    }

    return '${negative ? '-' : ''}'
        '${buffer.toString()} VND';
  }

  String _tankEquivalent(Trip trip, Vehicle? vehicle) {
    final fuel = trip.estimatedFuelL;

    final tank = vehicle?.fuelTankCapacityL;

    if (fuel == null || tank == null || tank <= 0) {
      return 'Chưa tính';
    }

    return '${(fuel / tank).toStringAsFixed(2)} bình';
  }

  TripBudgetItem? _findFuelItem(List<TripBudgetItem> items) {
    for (final item in items) {
      if (item.category == 'fuel') {
        return item;
      }
    }

    return null;
  }

  String _derivedUnitPrice({
    required Trip trip,
    required TripBudgetItem? fuelItem,
  }) {
    final fuel = trip.estimatedFuelL;

    final fuelCost = fuelItem?.amountVnd;

    if (fuel == null || fuel <= 0 || fuelCost == null || fuelCost <= 0) {
      return 'Chưa tính';
    }

    return '${_formatVnd(fuelCost / fuel)}/lít';
  }

  Future<void> _editTrip(BuildContext context, WidgetRef ref) async {
    await context.push('/trips/$tripId/edit');

    ref.invalidate(tripByIdProvider(tripId));

    ref.invalidate(tripBudgetItemsProvider(tripId));

    ref.invalidate(currentTripsProvider);
  }

  Future<void> _viewRoute(BuildContext context, WidgetRef ref) async {
    await context.push('/trips/$tripId/route');

    ref.invalidate(tripByIdProvider(tripId));

    ref.invalidate(tripBudgetItemsProvider(tripId));

    ref.invalidate(currentTripsProvider);
  }

  Future<void> _viewGroupLiveMap(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return TripGroupLiveMapPage(tripId: tripId);
        },
      ),
    );
  }

  Future<void> _viewTripCheckpoints(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TripCheckpointManagementPage(tripId: tripId),
      ),
    );
  }

  Future<void> _enableGroupTrip(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Bật chuyến đi nhóm?'),
          content: const Text(
            'Sau khi bật, chuyến đi này có thể sử dụng các chức năng '
            'nhóm như mời thành viên, chia sẻ vị trí và theo dõi đoàn '
            'ở các bước tiếp theo.',
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
              child: const Text('Bật chuyến đi nhóm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(groupTripRepositoryProvider).enableGroupTrip(tripId);

      ref.invalidate(groupTripStateProvider(tripId));

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã bật chuyến đi nhóm.')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể bật chuyến đi nhóm: $error')),
      );
    }
  }

  Future<void> _inviteTripMember(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    var selectedRole = TripInvitationRole.member;
    String? validationError;

    try {
      final input = await showDialog<CreateTripInvitationInput>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Mời thành viên'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Nhập chính xác email tài khoản PhuotThu '
                        'của người anh muốn mời.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'rider@example.com',
                          errorText: validationError,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          if (validationError != null) {
                            setDialogState(() {
                              validationError = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Vai trò khi tham gia',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<TripInvitationRole>(
                        value: selectedRole,
                        isExpanded: true,
                        items: TripInvitationRole.values
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(role.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (role) {
                          if (role == null) {
                            return;
                          }

                          setDialogState(() {
                            selectedRole = role;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Lời mời có hiệu lực trong 7 ngày. '
                        'Chủ chuyến không thể được tạo bằng lời mời.',
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Hủy'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      try {
                        final value = CreateTripInvitationInput(
                          tripId: tripId,
                          email: emailController.text,
                          role: selectedRole,
                        );

                        Navigator.of(dialogContext).pop(value);
                      } on ArgumentError {
                        setDialogState(() {
                          validationError = 'Email không hợp lệ.';
                        });
                      }
                    },
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Gửi lời mời'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (input == null) {
        return;
      }

      await ref.read(tripInvitationRepositoryProvider).inviteByEmail(input);

      ref.invalidate(tripInvitationsProvider(tripId));
      ref.invalidate(groupTripStateProvider(tripId));

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã gửi lời mời đến ${input.email}.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể gửi lời mời: $error')));
    } finally {
      emailController.dispose();
    }
  }

  void _invalidateGroupData(WidgetRef ref) {
    ref.invalidate(groupTripStateProvider(tripId));
    ref.invalidate(tripMemberViewsProvider(tripId));
    ref.invalidate(tripInvitationsProvider(tripId));
    ref.invalidate(currentTripsProvider);
  }

  Future<void> _setMemberRole(
    BuildContext context,
    WidgetRef ref, {
    required TripMemberView member,
    required TripMemberRole role,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Thay đổi vai trò?'),
          content: Text(
            'Đổi vai trò của "${member.displayName}" '
            'thành ${role.label}?',
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
              child: const Text('Xác nhận'),
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
          .read(groupTripRepositoryProvider)
          .setMemberRole(
            tripId: tripId,
            memberUserId: member.userId,
            role: role,
          );

      _invalidateGroupData(ref);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã cập nhật ${member.displayName} thành ${role.label}.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể thay đổi vai trò: $error')),
      );
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref, {
    required TripMemberView member,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Loại thành viên?'),
          content: Text(
            'Bạn có chắc muốn loại "${member.displayName}" '
            'khỏi chuyến đi này?',
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
              child: const Text('Loại thành viên'),
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
          .read(groupTripRepositoryProvider)
          .removeMember(tripId: tripId, memberUserId: member.userId);

      _invalidateGroupData(ref);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã loại ${member.displayName} khỏi chuyến đi.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể loại thành viên: $error')),
      );
    }
  }

  Future<void> _leaveGroupTrip(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rời chuyến đi?'),
          content: const Text(
            'Sau khi rời chuyến, bạn sẽ không còn quyền xem '
            'dữ liệu nhóm của chuyến này.',
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
              child: const Text('Rời chuyến'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final publisher = ref.read(tripLiveLocationPublisherProvider);

      if (publisher.status.tripId == tripId) {
        try {
          await publisher.stop(clearRemote: false);
        } catch (_) {
          // Backend leave_trip() vẫn là nguồn sự thật.
          // Trigger DB sẽ xóa live location sau khi rời chuyến.
        }
      }

      await ref.read(groupTripRepositoryProvider).leaveTrip(tripId);

      _invalidateGroupData(ref);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bạn đã rời chuyến đi.')));

      context.pop();
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể rời chuyến đi: $error')),
      );
    }
  }

  TripMember? _activeMembershipForUser(
    GroupTripState groupState,
    String? userId,
  ) {
    if (userId == null) {
      return null;
    }

    for (final member in groupState.members) {
      if (member.userId == userId && member.isActive) {
        return member;
      }
    }

    return null;
  }

  bool _canRemoveMember(
    GroupTripState groupState,
    TripMemberView member, {
    required String? currentUserId,
  }) {
    if (currentUserId == null ||
        member.isOwner ||
        member.userId == currentUserId) {
      return false;
    }

    final viewerIsOwner = groupState.ownerId == currentUserId;

    if (viewerIsOwner) {
      return true;
    }

    final viewerMembership = _activeMembershipForUser(
      groupState,
      currentUserId,
    );

    return viewerMembership?.role == TripMemberRole.leader &&
        member.role == TripMemberRole.member;
  }

  Widget _buildTripMembersSection(
    BuildContext context,
    WidgetRef ref, {
    required GroupTripState groupState,
    required AsyncValue<List<TripMemberView>> membersAsync,
    required String? currentUserId,
  }) {
    return membersAsync.when(
      loading: () {
        return const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Đang tải danh sách thành viên...')),
            ],
          ),
        );
      },
      error: (error, stackTrace) {
        return ListTile(
          leading: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Không thể tải danh sách thành viên'),
          subtitle: const Text('Nhấn thử lại để tải lại.'),
          trailing: IconButton(
            onPressed: () {
              ref.invalidate(tripMemberViewsProvider(tripId));
            },
            tooltip: 'Thử lại',
            icon: const Icon(Icons.refresh),
          ),
        );
      },
      data: (members) {
        if (members.isEmpty) {
          return const ListTile(
            leading: Icon(Icons.people_outline),
            title: Text('Thành viên chuyến đi'),
            subtitle: Text('Chưa có thành viên đang hoạt động.'),
          );
        }

        final viewerIsOwner =
            currentUserId != null && groupState.ownerId == currentUserId;

        final viewerMembership = _activeMembershipForUser(
          groupState,
          currentUserId,
        );

        final viewerCanLeave =
            !viewerIsOwner && (viewerMembership?.canLeave ?? false);

        return Column(
          children: [
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Thành viên chuyến đi'),
              subtitle: Text('${members.length} thành viên đang hoạt động'),
            ),
            ...members.expand((member) {
              final isViewer =
                  currentUserId != null && member.userId == currentUserId;

              final canChangeRole =
                  viewerIsOwner && !member.isOwner && !isViewer;

              final canRemove = _canRemoveMember(
                groupState,
                member,
                currentUserId: currentUserId,
              );

              final hasMenu = canChangeRole || canRemove;

              return [
                ListTile(
                  leading: CircleAvatar(child: Text(member.initials)),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isViewer) ...[
                        const SizedBox(width: 8),
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Bạn'),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(member.subtitle),
                  trailing: hasMenu
                      ? PopupMenuButton<String>(
                          tooltip: 'Quản lý thành viên',
                          onSelected: (value) {
                            switch (value) {
                              case 'leader':
                                _setMemberRole(
                                  context,
                                  ref,
                                  member: member,
                                  role: TripMemberRole.leader,
                                );
                                break;
                              case 'member':
                                _setMemberRole(
                                  context,
                                  ref,
                                  member: member,
                                  role: TripMemberRole.member,
                                );
                                break;
                              case 'remove':
                                _removeMember(context, ref, member: member);
                                break;
                            }
                          },
                          itemBuilder: (context) {
                            return [
                              if (canChangeRole &&
                                  member.role != TripMemberRole.leader)
                                const PopupMenuItem(
                                  value: 'leader',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.shield_outlined),
                                    title: Text('Đặt làm Trưởng nhóm'),
                                  ),
                                ),
                              if (canChangeRole &&
                                  member.role != TripMemberRole.member)
                                const PopupMenuItem(
                                  value: 'member',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.person_outline),
                                    title: Text('Đặt làm Thành viên'),
                                  ),
                                ),
                              if (canRemove)
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.person_remove_outlined),
                                    title: Text('Loại khỏi chuyến'),
                                  ),
                                ),
                            ];
                          },
                        )
                      : null,
                ),
                if (isViewer)
                  _TripLiveLocationSharingTile(
                    tripId: tripId,
                    sharingEnabled: member.locationSharing,
                    onDataChanged: () {
                      _invalidateGroupData(ref);
                    },
                  ),
              ];
            }),
            if (viewerCanLeave)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _leaveGroupTrip(context, ref);
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Rời chuyến đi'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGroupTravelCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<GroupTripState> groupAsync,
    AsyncValue<List<TripInvitation>> invitationsAsync,
    AsyncValue<List<TripMemberView>> membersAsync, {
    required String? currentUserId,
  }) {
    return Card(
      child: groupAsync.when(
        loading: () {
          return const ListTile(
            leading: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Chuyến đi nhóm'),
            subtitle: Text('Đang tải trạng thái nhóm...'),
          );
        },
        error: (error, stackTrace) {
          return ListTile(
            leading: Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Chuyến đi nhóm'),
            subtitle: const Text('Không thể tải trạng thái nhóm.'),
            trailing: IconButton(
              onPressed: () {
                ref.invalidate(groupTripStateProvider(tripId));
              },
              tooltip: 'Thử lại',
              icon: const Icon(Icons.refresh),
            ),
          );
        },
        data: (groupState) {
          final viewerIsOwner =
              currentUserId != null && groupState.ownerId == currentUserId;

          final viewerMembership = _activeMembershipForUser(
            groupState,
            currentUserId,
          );

          final viewerCanManageMembers =
              viewerIsOwner || (viewerMembership?.canManageMembers ?? false);

          if (groupState.isGroupEnabled) {
            final memberDescription = groupState.hasOtherActiveMembers
                ? '${groupState.activeMemberCount} '
                      'thành viên đang tham gia'
                : 'Chưa có thành viên khác';

            final invitationSummary = invitationsAsync.when(
              data: (invitations) {
                final now = DateTime.now();

                final pendingCount = invitations
                    .where((invitation) => invitation.isActionableAt(now))
                    .length;

                return '$pendingCount lời mời đang chờ';
              },
              loading: () => 'Đang tải lời mời...',
              error: (error, stackTrace) => 'Không thể tải lời mời.',
            );

            return Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Chuyến đi nhóm'),
                  subtitle: Text('Đã bật • $memberDescription'),
                  trailing: const Chip(label: Text('Đã bật')),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        _viewGroupLiveMap(context);
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Bản đồ nhóm trực tiếp'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        _viewTripCheckpoints(context);
                      },
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Điểm hẹn / Checkpoint'),
                    ),
                  ),
                ),
                if (viewerCanManageMembers) ...[
                  ListTile(
                    leading: const Icon(Icons.mark_email_unread_outlined),
                    title: const Text('Lời mời'),
                    subtitle: Text(invitationSummary),
                    trailing: invitationsAsync.hasError
                        ? IconButton(
                            onPressed: () {
                              ref.invalidate(tripInvitationsProvider(tripId));
                            },
                            tooltip: 'Tải lại lời mời',
                            icon: const Icon(Icons.refresh),
                          )
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          _inviteTripMember(context, ref);
                        },
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Mời thành viên'),
                      ),
                    ),
                  ),
                ],
                if (viewerIsOwner)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bạn là chủ chuyến. '
                        'Owner và leader có thể mời '
                        'thành viên vào chuyến đi.',
                      ),
                    ),
                  ),
                _buildTripMembersSection(
                  context,
                  ref,
                  groupState: groupState,
                  membersAsync: membersAsync,
                  currentUserId: currentUserId,
                ),
              ],
            );
          }

          return Column(
            children: [
              const ListTile(
                leading: Icon(Icons.group_add_outlined),
                title: Text('Chuyến đi nhóm'),
                subtitle: Text(
                  'Bật chế độ nhóm để chuẩn bị '
                  'mời thành viên và sử dụng các '
                  'tính năng đi theo đoàn.',
                ),
              ),
              if (viewerIsOwner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        _enableGroupTrip(context, ref);
                      },
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('Bật chuyến đi nhóm'),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chỉ chủ chuyến mới có thể '
                      'bật chế độ nhóm.',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _viewBudget(BuildContext context, WidgetRef ref) async {
    await context.push('/trips/$tripId/budget');

    ref.invalidate(tripByIdProvider(tripId));

    ref.invalidate(tripBudgetItemsProvider(tripId));

    ref.invalidate(currentTripsProvider);
  }

  Future<void> _changePlanStatus(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    String newStatus;

    if (trip.status == 'draft') {
      final missingFields = <String>[];

      if (trip.vehicleId == null) {
        missingFields.add('phương tiện');
      }

      if (trip.startName == null ||
          trip.startName!.trim().isEmpty ||
          trip.startPlaceId == null ||
          trip.startPlaceId!.trim().isEmpty) {
        missingFields.add('điểm bắt đầu trên bản đồ');
      }

      if (trip.destinationName == null ||
          trip.destinationName!.trim().isEmpty ||
          trip.destinationPlaceId == null ||
          trip.destinationPlaceId!.trim().isEmpty) {
        missingFields.add('điểm đến trên bản đồ');
      }

      if (trip.plannedStartAt == null) {
        missingFields.add('thời gian bắt đầu');
      }

      if (missingFields.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chưa thể lên kế hoạch. '
              'Cần bổ sung: '
              '${missingFields.join(', ')}.',
            ),
          ),
        );

        return;
      }

      newStatus = 'planned';
    } else if (trip.status == 'planned') {
      newStatus = 'draft';
    } else {
      return;
    }

    try {
      await ref
          .read(tripRepositoryProvider)
          .updateTripStatus(tripId: trip.id, status: newStatus);

      ref.invalidate(tripByIdProvider(trip.id));

      ref.invalidate(currentTripsProvider);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể cập nhật '
            'trạng thái: $error',
          ),
        ),
      );
    }
  }

  Future<void> _deleteTrip(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa chuyến đi?'),
          content: Text(
            'Chuyến "${trip.name}" '
            'và dữ liệu liên quan '
            'sẽ bị xóa.',
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
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(tripRepositoryProvider).deleteTrip(trip.id);

      ref.invalidate(currentTripsProvider);

      if (!context.mounted) {
        return;
      }

      context.pop();
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa chuyến đi: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final tripAsync = ref.watch(tripByIdProvider(tripId));

    final budgetItemsAsync = ref.watch(tripBudgetItemsProvider(tripId));

    final groupTripAsync = ref.watch(groupTripStateProvider(tripId));

    final invitationsAsync = ref.watch(tripInvitationsProvider(tripId));

    final memberViewsAsync = ref.watch(tripMemberViewsProvider(tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết chuyến đi')),
      body: SafeArea(
        child: tripAsync.when(
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
                    const Text('Không thể tải chuyến đi.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(tripByIdProvider(tripId));

                        ref.invalidate(tripBudgetItemsProvider(tripId));
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (trip) {
            final vehiclesAsync = ref.watch(currentVehiclesProvider);

            final selectedVehicle = vehiclesAsync.maybeWhen<Vehicle?>(
              data: (vehicles) {
                if (trip.vehicleId == null) {
                  return null;
                }

                for (final vehicle in vehicles) {
                  if (vehicle.id == trip.vehicleId) {
                    return vehicle;
                  }
                }

                return null;
              },
              orElse: () => null,
            );

            final vehicleName =
                selectedVehicle?.name ??
                (trip.vehicleId == null ? 'Chưa chọn' : 'Đang tải...');

            final canViewRoute =
                trip.startPlaceId != null &&
                trip.startPlaceId!.trim().isNotEmpty &&
                trip.destinationPlaceId != null &&
                trip.destinationPlaceId!.trim().isNotEmpty;

            final isElectric = selectedVehicle?.fuelType == 'electric';

            final fuelItem = budgetItemsAsync.maybeWhen<TripBudgetItem?>(
              data: (items) {
                return _findFuelItem(items);
              },
              orElse: () => null,
            );

            final budgetItemsLoading = budgetItemsAsync.isLoading;

            final fuelCost = fuelItem?.amountVnd;

            final remainingBudget =
                trip.budgetTotal != null && trip.estimatedMinCost != null
                ? trip.budgetTotal! - trip.estimatedMinCost!
                : null;

            final budgetUsagePercent =
                trip.budgetTotal != null &&
                    trip.budgetTotal! > 0 &&
                    trip.estimatedMinCost != null
                ? trip.estimatedMinCost! / trip.budgetTotal! * 100
                : null;

            final exceedsBudget =
                remainingBudget != null && remainingBudget < 0;

            final viewerIsTripOwner = groupTripAsync.maybeWhen(
              data: (groupState) =>
                  currentUserId != null && groupState.ownerId == currentUserId,
              orElse: () => false,
            );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  trip.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(label: Text(_statusLabel(trip.status))),
                ),

                if (trip.description != null &&
                    trip.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(trip.description!),
                ],

                const SizedBox(height: 16),

                _buildGroupTravelCard(
                  context,
                  ref,
                  groupTripAsync,
                  invitationsAsync,
                  memberViewsAsync,
                  currentUserId: currentUserId,
                ),

                const SizedBox(height: 8),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.directions_car_outlined),
                        title: const Text('Phương tiện'),
                        subtitle: Text(vehicleName),
                      ),
                      ListTile(
                        leading: const Icon(Icons.trip_origin),
                        title: const Text('Điểm bắt đầu'),
                        subtitle: Text(
                          trip.startAddress ?? trip.startName ?? 'Chưa chọn',
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: const Text('Điểm đến'),
                        subtitle: Text(
                          trip.destinationAddress ??
                              trip.destinationName ??
                              'Chưa chọn',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.calendar_month_outlined),
                        title: const Text('Bắt đầu'),
                        subtitle: Text(_formatDateTime(trip.plannedStartAt)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.event_available_outlined),
                        title: const Text('Dự kiến kết thúc'),
                        subtitle: Text(_formatDateTime(trip.plannedEndAt)),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.account_balance_wallet_outlined,
                        ),
                        title: const Text('Ngân sách'),
                        subtitle: Text(_formatVnd(trip.budgetTotal)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.route),
                        title: const Text('Khoảng cách tuyến'),
                        subtitle: Text(_formatDistance(trip.routeDistanceM)),
                      ),

                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Thời gian di chuyển'),
                        subtitle: Text(_formatDuration(trip.routeDurationS)),
                      ),

                      ListTile(
                        leading: Icon(
                          isElectric
                              ? Icons.electric_bolt_outlined
                              : Icons.local_gas_station_outlined,
                        ),
                        title: Text(
                          isElectric
                              ? 'Năng lượng dự kiến'
                              : 'Nhiên liệu dự kiến',
                        ),
                        subtitle: Text(
                          isElectric
                              ? 'Chưa hỗ trợ tính kWh/100 km'
                              : _formatFuel(trip.estimatedFuelL),
                        ),
                      ),

                      if (!isElectric && trip.estimatedFuelL != null)
                        ListTile(
                          leading: const Icon(Icons.gas_meter_outlined),
                          title: const Text('Số bình tương đương'),
                          subtitle: Text(
                            _tankEquivalent(trip, selectedVehicle),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.payments_outlined),
                        title: const Text('Đơn giá nhiên liệu'),
                        subtitle: Text(
                          budgetItemsLoading
                              ? 'Đang tải...'
                              : _derivedUnitPrice(
                                  trip: trip,
                                  fuelItem: fuelItem,
                                ),
                        ),
                      ),

                      ListTile(
                        leading: const Icon(Icons.local_gas_station_outlined),
                        title: const Text('Chi phí nhiên liệu'),
                        subtitle: Text(
                          budgetItemsLoading
                              ? 'Đang tải...'
                              : _formatVnd(fuelCost),
                        ),
                      ),

                      ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: const Text('Tổng chi phí dự kiến'),
                        subtitle: Text(
                          _formatVnd(trip.estimatedMinCost),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                      if (remainingBudget != null)
                        ListTile(
                          leading: Icon(
                            exceedsBudget
                                ? Icons.warning_amber_outlined
                                : Icons.savings_outlined,
                          ),
                          title: Text(
                            exceedsBudget
                                ? 'Vượt ngân sách'
                                : 'Ngân sách còn lại',
                          ),
                          subtitle: Text(
                            _formatVnd(remainingBudget),
                            style: TextStyle(
                              color: exceedsBudget
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      if (budgetUsagePercent != null)
                        ListTile(
                          leading: const Icon(Icons.percent),
                          title: const Text('Tỷ lệ ngân sách'),
                          subtitle: Text(
                            '${budgetUsagePercent.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: exceedsBudget
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: () {
                    _viewBudget(context, ref);
                  },
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Mô phỏng ngân sách'),
                ),

                const SizedBox(height: 12),

                if (canViewRoute) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      _viewRoute(context, ref);
                    },
                    icon: const Icon(Icons.route),
                    label: const Text('Xem / tính lại tuyến đường'),
                  ),

                  const SizedBox(height: 12),
                ],

                if (viewerIsTripOwner) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      _editTrip(context, ref);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Chỉnh sửa chuyến đi'),
                  ),

                  const SizedBox(height: 12),
                ],

                if (viewerIsTripOwner &&
                    (trip.status == 'draft' || trip.status == 'planned'))
                  OutlinedButton.icon(
                    onPressed: () {
                      _changePlanStatus(context, ref, trip);
                    },
                    icon: Icon(
                      trip.status == 'draft'
                          ? Icons.check_circle_outline
                          : Icons.edit_note_outlined,
                    ),
                    label: Text(
                      trip.status == 'draft'
                          ? 'Đánh dấu đã lên kế hoạch'
                          : 'Chuyển về bản nháp',
                    ),
                  ),

                if (viewerIsTripOwner) ...[
                  const SizedBox(height: 12),

                  TextButton.icon(
                    onPressed: () {
                      _deleteTrip(context, ref, trip);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa chuyến đi'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TripLiveLocationSharingTile extends ConsumerStatefulWidget {
  const _TripLiveLocationSharingTile({
    required this.tripId,
    required this.sharingEnabled,
    required this.onDataChanged,
  });

  final String tripId;
  final bool sharingEnabled;
  final VoidCallback onDataChanged;

  @override
  ConsumerState<_TripLiveLocationSharingTile> createState() =>
      _TripLiveLocationSharingTileState();
}

class _TripLiveLocationSharingTileState
    extends ConsumerState<_TripLiveLocationSharingTile> {
  bool _busy = false;
  bool _resumeScheduled = false;

  TripLiveLocationSharingResult? _runtimeResult;

  @override
  void initState() {
    super.initState();

    _scheduleResumeIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _TripLiveLocationSharingTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tripId != widget.tripId) {
      _runtimeResult = null;
      _resumeScheduled = false;
      _scheduleResumeIfNeeded();
      return;
    }

    if (!oldWidget.sharingEnabled && widget.sharingEnabled) {
      _scheduleResumeIfNeeded();
    }

    if (oldWidget.sharingEnabled && !widget.sharingEnabled) {
      _runtimeResult = TripLiveLocationSharingResult.disabled;
    }
  }

  void _scheduleResumeIfNeeded() {
    if (!widget.sharingEnabled || _resumeScheduled) {
      return;
    }

    _resumeScheduled = true;

    Future<void>.microtask(() async {
      try {
        final result = await ref
            .read(tripLiveLocationSharingServiceProvider)
            .resumeIfEnabled(tripId: widget.tripId, enabled: true);

        if (!mounted) {
          return;
        }

        setState(() {
          _runtimeResult = result;
        });
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _runtimeResult = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể khôi phục Live Location: '
              '$error',
            ),
          ),
        );
      } finally {
        _resumeScheduled = false;
      }
    });
  }

  Future<void> _toggle(bool enabled) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final result = await ref
          .read(tripLiveLocationSharingServiceProvider)
          .setEnabled(tripId: widget.tripId, enabled: enabled);

      widget.onDataChanged();

      if (!mounted) {
        return;
      }

      setState(() {
        _runtimeResult = result;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_messageForResult(result))));
    } catch (error) {
      widget.onDataChanged();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể cập nhật Live Location: '
            '$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _messageForResult(TripLiveLocationSharingResult result) {
    switch (result) {
      case TripLiveLocationSharingResult.enabled:
        return 'Đã bật Live Location cho chuyến đi.';
      case TripLiveLocationSharingResult.disabled:
        return 'Đã tắt Live Location cho chuyến đi.';
      case TripLiveLocationSharingResult.serviceDisabled:
        return 'Không thể bật Live Location vì '
            'dịch vụ vị trí đang tắt.';
      case TripLiveLocationSharingResult.permissionDenied:
        return 'Không thể bật Live Location vì '
            'chưa được cấp quyền vị trí.';
      case TripLiveLocationSharingResult.permissionDeniedForever:
        return 'Quyền vị trí đã bị từ chối vĩnh viễn. '
            'Hãy bật lại trong Cài đặt ứng dụng.';
    }
  }

  String _subtitle() {
    if (_busy) {
      return 'Đang cập nhật Live Location...';
    }

    if (!widget.sharingEnabled) {
      return 'Đang tắt. Vị trí hiện tại '
          'không được gửi cho thành viên khác.';
    }

    switch (_runtimeResult) {
      case TripLiveLocationSharingResult.enabled:
        return 'Đang chia sẻ vị trí trực tiếp '
            'cho các thành viên đang hoạt động.';
      case TripLiveLocationSharingResult.serviceDisabled:
        return 'Đã bật chia sẻ nhưng GPS/dịch vụ vị trí '
            'đang tắt trên thiết bị.';
      case TripLiveLocationSharingResult.permissionDenied:
        return 'Đã bật chia sẻ nhưng ứng dụng '
            'chưa có quyền truy cập vị trí.';
      case TripLiveLocationSharingResult.permissionDeniedForever:
        return 'Đã bật chia sẻ nhưng quyền vị trí '
            'đã bị chặn trong Cài đặt.';
      case TripLiveLocationSharingResult.disabled:
        return 'Đang tắt. Vị trí hiện tại '
            'không được gửi cho thành viên khác.';
      case null:
        return 'Đang khởi tạo Live Location...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.location_on_outlined),
      title: const Text('Chia sẻ vị trí của tôi'),
      subtitle: Text(_subtitle()),
      value: widget.sharingEnabled,
      onChanged: _busy ? null : _toggle,
    );
  }
}
