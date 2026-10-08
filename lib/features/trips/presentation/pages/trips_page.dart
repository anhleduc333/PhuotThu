import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(currentTripsProvider);

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
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (trips) {
            if (trips.isEmpty) {
              return const _EmptyTripsView();
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentTripsProvider);

                await ref.read(currentTripsProvider.future);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: trips.length,
                separatorBuilder: (context, index) {
                  return const SizedBox(height: 8);
                },
                itemBuilder: (context, index) {
                  final trip = trips[index];

                  return _TripCard(
                    trip: trip,
                    statusLabel: _statusLabel(trip.status),
                    startDate: _formatDate(trip.plannedStartAt),
                    onTap: () async {
                      await context.push('/trips/${trip.id}');

                      ref.invalidate(currentTripsProvider);
                    },
                  );
                },
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
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
