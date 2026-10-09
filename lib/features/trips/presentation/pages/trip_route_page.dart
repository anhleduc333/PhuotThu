import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../map/data/route_providers.dart';
import '../../../map/domain/route_result.dart';
import '../../../vehicle/data/vehicle_repository.dart';
import '../../data/fuel_price_repository.dart';
import '../../data/trip_providers.dart';
import '../../data/trip_repository.dart';
import '../../data/trip_route_repository.dart';
import '../../domain/trip.dart';
import '../../domain/trip_cost_estimator.dart';
import '../../domain/trip_fuel_estimator.dart';
import '../../domain/trip_route_points.dart';

class TripRoutePage extends ConsumerStatefulWidget {
  const TripRoutePage({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<TripRoutePage> createState() => _TripRoutePageState();
}

class _TripRoutePageState extends ConsumerState<TripRoutePage> {
  final MapController _mapController = MapController();

  TripRoutePoints? _routePoints;
  RouteResult? _route;

  double? _estimatedFuelLiters;
  double? _tankEquivalent;

  double? _unitFuelPrice;
  double? _estimatedFuelCost;
  double? _remainingBudget;
  double? _budgetUsagePercent;

  bool _exceedsBudget = false;

  String? _estimateMessage;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    Future.microtask(_loadRoute);
  }

  Future<void> _loadRoute() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;

        _estimatedFuelLiters = null;
        _tankEquivalent = null;

        _unitFuelPrice = null;
        _estimatedFuelCost = null;
        _remainingBudget = null;
        _budgetUsagePercent = null;

        _exceedsBudget = false;
        _estimateMessage = null;
      });
    }

    try {
      final routeRepository = ref.read(tripRouteRepositoryProvider);

      final routePoints = await routeRepository.getRoutePoints(widget.tripId);

      final routeService = ref.read(routeServiceProvider);

      final route = await routeService.getRoute(
        startLatitude: routePoints.startLatitude,
        startLongitude: routePoints.startLongitude,
        destinationLatitude: routePoints.destinationLatitude,
        destinationLongitude: routePoints.destinationLongitude,
      );

      await routeRepository.updateRouteSummary(
        tripId: widget.tripId,
        distanceMeters: route.distanceMeters,
        durationSeconds: route.durationSeconds,
      );

      await _calculateFuelAndCost(route);

      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = routePoints;
        _route = route;
        _isLoading = false;
      });

      ref.invalidate(tripByIdProvider(widget.tripId));

      ref.invalidate(currentTripsProvider);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fitRoute();
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tính tuyến đường.\n$error';
      });
    }
  }

  Future<void> _calculateFuelAndCost(RouteResult route) async {
    final tripRepository = ref.read(tripRepositoryProvider);

    try {
      final trip = await tripRepository.getTripById(widget.tripId);

      if (trip.vehicleId == null) {
        await tripRepository.updateTripEstimates(
          tripId: widget.tripId,
          estimatedFuelL: null,
          estimatedMinCost: null,
        );

        if (mounted) {
          setState(() {
            _estimateMessage = 'Chuyến đi chưa chọn phương tiện.';
          });
        }

        return;
      }

      final vehicle = await ref
          .read(vehicleRepositoryProvider)
          .getVehicleById(trip.vehicleId!);

      if (vehicle.fuelType == 'electric') {
        await tripRepository.updateTripEstimates(
          tripId: widget.tripId,
          estimatedFuelL: null,
          estimatedMinCost: null,
        );

        if (mounted) {
          setState(() {
            _estimateMessage =
                'Xe điện hiện chưa có dữ liệu '
                'tiêu thụ kWh/100 km để tính '
                'năng lượng và chi phí.';
          });
        }

        return;
      }

      const fuelEstimator = TripFuelEstimator();

      final fuelEstimate = fuelEstimator.calculate(
        distanceMeters: route.distanceMeters,
        vehicle: vehicle,
      );

      if (fuelEstimate == null) {
        await tripRepository.updateTripEstimates(
          tripId: widget.tripId,
          estimatedFuelL: null,
          estimatedMinCost: null,
        );

        if (mounted) {
          setState(() {
            _estimateMessage =
                'Phương tiện chưa có mức tiêu hao '
                'nhiên liệu hợp lệ.';
          });
        }

        return;
      }

      final fuelType = vehicle.fuelType;

      if (fuelType == null || fuelType.trim().isEmpty) {
        await tripRepository.updateTripEstimates(
          tripId: widget.tripId,
          estimatedFuelL: fuelEstimate.liters,
          estimatedMinCost: null,
        );

        if (mounted) {
          setState(() {
            _estimatedFuelLiters = fuelEstimate.liters;

            _tankEquivalent = fuelEstimate.tankEquivalent;

            _estimateMessage =
                'Đã tính nhiên liệu nhưng phương '
                'tiện chưa khai báo loại nhiên liệu.';
          });
        }

        return;
      }

      final fuelPrice = await ref
          .read(fuelPriceRepositoryProvider)
          .getLatestPrice(fuelType);

      if (fuelPrice == null) {
        await tripRepository.updateTripEstimates(
          tripId: widget.tripId,
          estimatedFuelL: fuelEstimate.liters,
          estimatedMinCost: null,
        );

        if (mounted) {
          setState(() {
            _estimatedFuelLiters = fuelEstimate.liters;

            _tankEquivalent = fuelEstimate.tankEquivalent;

            _estimateMessage =
                'Đã tính nhiên liệu nhưng chưa có '
                'giá cấu hình cho loại nhiên liệu '
                '"$fuelType".';
          });
        }

        return;
      }

      const costEstimator = TripCostEstimator();

      final costEstimate = costEstimator.calculate(
        estimatedFuelLiters: fuelEstimate.liters,
        unitPriceVndPerLiter: fuelPrice.unitPriceVndPerLiter,
        budget: trip.budgetTotal,
      );

      if (costEstimate == null) {
        await tripRepository.updateTripEstimates(
          tripId: widget.tripId,
          estimatedFuelL: fuelEstimate.liters,
          estimatedMinCost: null,
        );

        return;
      }

      await tripRepository.updateTripEstimates(
        tripId: widget.tripId,
        estimatedFuelL: fuelEstimate.liters,
        estimatedMinCost: costEstimate.fuelCost,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _estimatedFuelLiters = fuelEstimate.liters;

        _tankEquivalent = fuelEstimate.tankEquivalent;

        _unitFuelPrice = costEstimate.unitPrice;

        _estimatedFuelCost = costEstimate.fuelCost;

        _remainingBudget = costEstimate.remainingBudget;

        _budgetUsagePercent = costEstimate.budgetUsagePercent;

        _exceedsBudget = costEstimate.exceedsBudget;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _estimateMessage =
              'Đã tính được tuyến đường nhưng '
              'chưa thể hoàn tất ước tính chi phí.';
        });
      }
    }
  }

  void _fitRoute() {
    final route = _route;

    if (route == null || route.points.isEmpty) {
      return;
    }

    final coordinates = route.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: coordinates,
        padding: const EdgeInsets.fromLTRB(36, 100, 36, 330),
        maxZoom: 16,
      ),
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '$meters m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(int seconds) {
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

  String _formatFuel(double liters) {
    return '${liters.toStringAsFixed(1)} lít';
  }

  String _formatTankEquivalent(double value) {
    return '${value.toStringAsFixed(2)} bình';
  }

  String _formatVnd(double value) {
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

  @override
  void dispose() {
    _mapController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripByIdProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuyến đường'),
        actions: [
          if (_route != null)
            IconButton(
              onPressed: _fitRoute,
              tooltip: 'Hiển thị toàn tuyến',
              icon: const Icon(Icons.center_focus_strong),
            ),
          IconButton(
            onPressed: _isLoading ? null : _loadRoute,
            tooltip: 'Tính lại tuyến',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, tripAsync)),
    );
  }

  Widget _buildBody(BuildContext context, AsyncValue<Trip> tripAsync) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tính tuyến đường...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route_outlined, size: 64),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadRoute,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final route = _route;
    final routePoints = _routePoints;

    if (route == null || routePoints == null) {
      return const Center(child: Text('Không có dữ liệu tuyến đường.'));
    }

    final polylinePoints = route.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    final startPoint = LatLng(
      routePoints.startLatitude,
      routePoints.startLongitude,
    );

    final destinationPoint = LatLng(
      routePoints.destinationLatitude,
      routePoints.destinationLongitude,
    );

    final tripTitle = tripAsync.maybeWhen(
      data: (trip) {
        final start = trip.startName ?? 'Điểm bắt đầu';

        final destination = trip.destinationName ?? 'Điểm đến';

        return '$start → $destination';
      },
      orElse: () {
        return 'Tuyến hành trình';
      },
    );

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: startPoint,
            initialZoom: 6,
            minZoom: 3,
            maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.anhleduc333.phuotthu',
            ),

            PolylineLayer(
              polylines: [
                Polyline(
                  points: polylinePoints,
                  strokeWidth: 5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),

            MarkerLayer(
              markers: [
                Marker(
                  point: startPoint,
                  width: 54,
                  height: 54,
                  child: _RouteMarker(
                    label: 'A',
                    icon: Icons.trip_origin,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Marker(
                  point: destinationPoint,
                  width: 54,
                  height: 54,
                  child: _RouteMarker(
                    label: 'B',
                    icon: Icons.location_on,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),

            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),

        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tripTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _SummaryItem(
                            icon: Icons.straighten,
                            label: 'Khoảng cách',
                            value: _formatDistance(route.distanceMeters),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SummaryItem(
                            icon: Icons.schedule,
                            label: 'Thời gian',
                            value: _formatDuration(route.durationSeconds),
                          ),
                        ),
                      ],
                    ),

                    if (_estimatedFuelLiters != null) ...[
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _SummaryItem(
                              icon: Icons.local_gas_station_outlined,
                              label: 'Nhiên liệu',
                              value: _formatFuel(_estimatedFuelLiters!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryItem(
                              icon: Icons.gas_meter_outlined,
                              label: 'Tương đương',
                              value: _tankEquivalent == null
                                  ? 'Chưa có dung tích bình'
                                  : _formatTankEquivalent(_tankEquivalent!),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_estimatedFuelCost != null) ...[
                      const Divider(height: 24),

                      _SummaryLine(
                        label: 'Đơn giá nhiên liệu',
                        value: '${_formatVnd(_unitFuelPrice!)}/lít',
                      ),

                      _SummaryLine(
                        label: 'Chi phí nhiên liệu',
                        value: _formatVnd(_estimatedFuelCost!),
                      ),

                      if (_remainingBudget != null)
                        _SummaryLine(
                          label: _exceedsBudget
                              ? 'Vượt ngân sách'
                              : 'Ngân sách còn lại',
                          value: _formatVnd(_remainingBudget!),
                          emphasis: _exceedsBudget,
                        ),

                      if (_budgetUsagePercent != null)
                        _SummaryLine(
                          label: 'Tỷ lệ ngân sách',
                          value: '${_budgetUsagePercent!.toStringAsFixed(1)}%',
                          emphasis: _exceedsBudget,
                        ),
                    ],

                    if (_estimateMessage != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_estimateMessage!)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),

                    Text(
                      'Khoảng cách và thời gian '
                      'được ước tính theo tuyến; '
                      'chưa bao gồm giao thông '
                      'thời gian thực.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteMarker extends StatelessWidget {
  const _RouteMarker({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, size: 48, color: color),
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final color = emphasis ? Theme.of(context).colorScheme.error : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
