import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../vehicle/data/vehicle_providers.dart';
import '../../data/trip_providers.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip.dart';

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

    return '$day/$month/${local.year} $hour:$minute';
  }

  String _formatBudget(Trip trip) {
    if (trip.budgetTotal == null) {
      return 'Chưa đặt';
    }

    return '${trip.budgetTotal!.toStringAsFixed(0)} ${trip.currency}';
  }

  Future<void> _editTrip(BuildContext context, WidgetRef ref) async {
    await context.push('/trips/$tripId/edit');

    ref.invalidate(tripByIdProvider(tripId));

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

      if (trip.startName == null || trip.startName!.trim().isEmpty) {
        missingFields.add('điểm bắt đầu');
      }

      if (trip.destinationName == null ||
          trip.destinationName!.trim().isEmpty) {
        missingFields.add('điểm đến');
      }

      if (trip.plannedStartAt == null) {
        missingFields.add('thời gian bắt đầu');
      }

      if (missingFields.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chưa thể lên kế hoạch. '
              'Cần bổ sung: ${missingFields.join(', ')}.',
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
        SnackBar(content: Text('Không thể cập nhật trạng thái: $error')),
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
            'Chuyến "${trip.name}" và dữ liệu '
            'thành viên liên quan sẽ bị xóa.',
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
    final tripAsync = ref.watch(tripByIdProvider(tripId));

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

            final vehicleName = vehiclesAsync.maybeWhen(
              data: (vehicles) {
                if (trip.vehicleId == null) {
                  return 'Chưa chọn';
                }

                for (final vehicle in vehicles) {
                  if (vehicle.id == trip.vehicleId) {
                    return vehicle.name;
                  }
                }

                return 'Không xác định';
              },
              orElse: () {
                return trip.vehicleId == null ? 'Chưa chọn' : 'Đang tải...';
              },
            );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  trip.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),

                const SizedBox(height: 8),

                Chip(label: Text(_statusLabel(trip.status))),

                if (trip.description != null &&
                    trip.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(trip.description!),
                ],

                const SizedBox(height: 16),

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
                        subtitle: Text(trip.startName ?? 'Chưa chọn'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: const Text('Điểm đến'),
                        subtitle: Text(trip.destinationName ?? 'Chưa chọn'),
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
                        subtitle: Text(_formatBudget(trip)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: () {
                    _editTrip(context, ref);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Chỉnh sửa chuyến đi'),
                ),

                const SizedBox(height: 12),

                if (trip.status == 'draft' || trip.status == 'planned')
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

                const SizedBox(height: 12),

                TextButton.icon(
                  onPressed: () {
                    _deleteTrip(context, ref, trip);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Xóa chuyến đi'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
