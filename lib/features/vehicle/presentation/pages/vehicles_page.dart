import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/vehicle_providers.dart';
import '../../domain/vehicle.dart';

class VehiclesPage extends ConsumerWidget {
  const VehiclesPage({super.key});

  String _vehicleTypeLabel(String type) {
    switch (type) {
      case 'motorcycle':
        return 'Xe máy';

      case 'car':
        return 'Ô tô';

      default:
        return 'Phương tiện khác';
    }
  }

  IconData _vehicleIcon(String type) {
    switch (type) {
      case 'motorcycle':
        return Icons.two_wheeler;

      case 'car':
        return Icons.directions_car;

      default:
        return Icons.commute;
    }
  }

  Future<void> _openAddVehicle(BuildContext context, WidgetRef ref) async {
    await context.push('/profile/vehicles/add');

    ref.invalidate(currentVehiclesProvider);
  }

  Future<void> _openVehicle(
    BuildContext context,
    WidgetRef ref,
    String vehicleId,
  ) async {
    await context.push('/profile/vehicles/$vehicleId/edit');

    ref.invalidate(currentVehiclesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(currentVehiclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Phương tiện của tôi')),
      body: SafeArea(
        child: vehiclesAsync.when(
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
                    const Text(
                      'Không thể tải danh sách phương tiện.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(currentVehiclesProvider);
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (vehicles) {
            if (vehicles.isEmpty) {
              return const _EmptyVehicleView();
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentVehiclesProvider);

                await ref.read(currentVehiclesProvider.future);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: vehicles.length,
                separatorBuilder: (context, index) {
                  return const SizedBox(height: 8);
                },
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];

                  return _VehicleCard(
                    vehicle: vehicle,
                    typeLabel: _vehicleTypeLabel(vehicle.vehicleType),
                    icon: _vehicleIcon(vehicle.vehicleType),
                    onTap: () {
                      _openVehicle(context, ref, vehicle.id);
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openAddVehicle(context, ref);
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm xe'),
      ),
    );
  }
}

class _EmptyVehicleView extends StatelessWidget {
  const _EmptyVehicleView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_outlined, size: 72),
            SizedBox(height: 16),
            Text(
              'Chưa có phương tiện',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Thêm phương tiện để PhuotThu có thể '
              'tính nhiên liệu và hỗ trợ lập kế hoạch hành trình.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.typeLabel,
    required this.icon,
    required this.onTap,
  });

  final Vehicle vehicle;
  final String typeLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brandAndModel = <String>[
      if (vehicle.brand != null && vehicle.brand!.trim().isNotEmpty)
        vehicle.brand!.trim(),

      if (vehicle.model != null && vehicle.model!.trim().isNotEmpty)
        vehicle.model!.trim(),
    ];

    final subtitleItems = <String>[
      typeLabel,

      if (brandAndModel.isNotEmpty) brandAndModel.join(' '),

      if (vehicle.plateNumber != null && vehicle.plateNumber!.trim().isNotEmpty)
        vehicle.plateNumber!.trim(),
    ];

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(icon)),
        title: Row(
          children: [
            Expanded(child: Text(vehicle.name)),

            if (vehicle.isDefault) ...[
              const SizedBox(width: 8),
              const Chip(label: Text('Mặc định')),
            ],
          ],
        ),
        subtitle: Text(subtitleItems.join(' • ')),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
