import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../map/data/along_route_providers.dart';
import '../../../map/data/route_providers.dart';
import '../../../map/domain/along_route_place.dart';
import '../../../map/domain/route_result.dart';
import '../../../vehicle/data/vehicle_repository.dart';
import '../../data/fuel_price_repository.dart';
import '../../data/smart_fuel_station_searcher.dart';
import '../../data/trip_budget_providers.dart';
import '../../data/trip_budget_repository.dart';
import '../../data/trip_providers.dart';
import '../../data/trip_repository.dart';
import '../../data/trip_route_repository.dart';
import '../../domain/fuel_range_calculator.dart';
import '../../domain/smart_fuel_stop_recommender.dart';
import '../../domain/trip.dart';
import '../../domain/trip_budget_calculator.dart';
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

  FuelRangeEstimate? _fuelRange;
  SmartFuelPlan? _smartFuelPlan;
  String? _smartFuelMessage;
  String? _smartFuelSearchWarning;

  bool _isLoading = true;
  String? _errorMessage;

  final Set<AlongRoutePlaceType> _selectedAlongRouteTypes = {
    AlongRoutePlaceType.fuel,
    AlongRoutePlaceType.restArea,
  };

  List<AlongRoutePlace> _alongRoutePlaces = const [];

  bool _isSearchingAlongRoute = false;
  bool _hasSearchedAlongRoute = false;

  String? _alongRouteError;

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

        _fuelRange = null;
        _smartFuelPlan = null;
        _smartFuelMessage = null;
        _smartFuelSearchWarning = null;

        _alongRoutePlaces = const [];
        _alongRouteError = null;
        _hasSearchedAlongRoute = false;
        _isSearchingAlongRoute = false;
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

    final budgetRepository = ref.read(tripBudgetRepositoryProvider);

    try {
      final trip = await tripRepository.getTripById(widget.tripId);

      if (trip.vehicleId == null) {
        await tripRepository.updateEstimatedFuel(
          tripId: widget.tripId,
          estimatedFuelL: null,
        );

        await budgetRepository.removeFuelCost(widget.tripId);

        ref.invalidate(tripBudgetItemsProvider(widget.tripId));

        await _refreshBudgetSummary(trip);

        if (mounted) {
          setState(() {
            _estimateMessage = 'Chuyến đi chưa chọn phương tiện.';
            _fuelRange = null;
            _smartFuelPlan = null;
            _smartFuelMessage =
                'Smart Fuel Stop cần một phương tiện có dữ liệu nhiên liệu.';
          });
        }

        return;
      }

      final vehicle = await ref
          .read(vehicleRepositoryProvider)
          .getVehicleById(trip.vehicleId!);

      if (vehicle.fuelType == 'electric') {
        await tripRepository.updateEstimatedFuel(
          tripId: widget.tripId,
          estimatedFuelL: null,
        );

        await budgetRepository.removeFuelCost(widget.tripId);

        ref.invalidate(tripBudgetItemsProvider(widget.tripId));

        await _refreshBudgetSummary(trip);

        if (mounted) {
          setState(() {
            _estimateMessage =
                'Xe điện hiện chưa có dữ liệu '
                'tiêu thụ kWh/100 km để tính '
                'năng lượng và chi phí.';
            _fuelRange = null;
            _smartFuelPlan = null;
            _smartFuelMessage = 'Smart Fuel Stop hiện chỉ áp dụng cho phương tiện dùng nhiên liệu lỏng.';
          });
        }

        return;
      }

      const fuelRangeCalculator = FuelRangeCalculator();

      final fuelRange = fuelRangeCalculator.calculate(
        tankCapacityLiters: vehicle.fuelTankCapacityL,
        consumptionLitersPer100Km: vehicle.consumptionLPer100Km,
        startingFuelRatio: 1,
        reserveRatio: 0.25,
      );

      final baseSmartFuelPlan = _buildSmartFuelPlan(
        route: route,
        fuelRange: fuelRange,
        places: const [],
      );

      if (mounted) {
        setState(() {
          _fuelRange = fuelRange;
          _smartFuelPlan = baseSmartFuelPlan;
          _smartFuelSearchWarning = null;
          _smartFuelMessage = fuelRange == null
              ? 'Cần khai báo dung tích bình và mức tiêu hao hợp lệ để gợi ý điểm đổ xăng.'
              : null;
        });
      }

      const fuelEstimator = TripFuelEstimator();

      final fuelEstimate = fuelEstimator.calculate(
        distanceMeters: route.distanceMeters,
        vehicle: vehicle,
      );

      if (fuelEstimate == null) {
        await tripRepository.updateEstimatedFuel(
          tripId: widget.tripId,
          estimatedFuelL: null,
        );

        await budgetRepository.removeFuelCost(widget.tripId);

        ref.invalidate(tripBudgetItemsProvider(widget.tripId));

        await _refreshBudgetSummary(trip);

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
        await tripRepository.updateEstimatedFuel(
          tripId: widget.tripId,
          estimatedFuelL: fuelEstimate.liters,
        );

        await budgetRepository.removeFuelCost(widget.tripId);

        ref.invalidate(tripBudgetItemsProvider(widget.tripId));

        await _refreshBudgetSummary(trip);

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
        await tripRepository.updateEstimatedFuel(
          tripId: widget.tripId,
          estimatedFuelL: fuelEstimate.liters,
        );

        await budgetRepository.removeFuelCost(widget.tripId);

        ref.invalidate(tripBudgetItemsProvider(widget.tripId));

        await _refreshBudgetSummary(trip);

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
        budget: null,
      );

      if (costEstimate == null) {
        await tripRepository.updateEstimatedFuel(
          tripId: widget.tripId,
          estimatedFuelL: fuelEstimate.liters,
        );

        await budgetRepository.removeFuelCost(widget.tripId);

        ref.invalidate(tripBudgetItemsProvider(widget.tripId));

        await _refreshBudgetSummary(trip);

        if (mounted) {
          setState(() {
            _estimatedFuelLiters = fuelEstimate.liters;

            _tankEquivalent = fuelEstimate.tankEquivalent;

            _estimateMessage =
                'Đã tính nhiên liệu nhưng chưa thể '
                'tính chi phí nhiên liệu.';
          });
        }

        return;
      }

      await tripRepository.updateEstimatedFuel(
        tripId: widget.tripId,
        estimatedFuelL: fuelEstimate.liters,
      );

      await budgetRepository.upsertFuelCost(
        tripId: widget.tripId,
        amountVnd: costEstimate.fuelCost,
      );

      ref.invalidate(tripBudgetItemsProvider(widget.tripId));

      await _refreshBudgetSummary(trip);

      if (!mounted) {
        return;
      }

      setState(() {
        _estimatedFuelLiters = fuelEstimate.liters;

        _tankEquivalent = fuelEstimate.tankEquivalent;

        _unitFuelPrice = costEstimate.unitPrice;

        _estimatedFuelCost = costEstimate.fuelCost;
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

  Future<void> _refreshBudgetSummary(Trip trip) async {
    final budgetRepository = ref.read(tripBudgetRepositoryProvider);

    final items = await budgetRepository.getItems(widget.tripId);

    const calculator = TripBudgetCalculator();

    final summary = calculator.calculate(
      items: items,
      budgetTotal: trip.budgetTotal,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _remainingBudget = summary.remainingBudget;

      _budgetUsagePercent = summary.usagePercent;

      _exceedsBudget = summary.exceedsBudget;
    });
  }

  Future<void> _searchAlongRoute() async {
    final route = _route;

    if (route == null || route.points.isEmpty) {
      return;
    }

    if (_selectedAlongRouteTypes.isEmpty) {
      setState(() {
        _alongRouteError = 'Hãy chọn ít nhất một loại dịch vụ.';
      });

      return;
    }

    setState(() {
      _isSearchingAlongRoute = true;
      _alongRouteError = null;
      _hasSearchedAlongRoute = false;
      _smartFuelSearchWarning = null;
    });

    try {
      final service = ref.read(alongRouteServiceProvider);

      final result = await service.search(
        routePoints: route.points,
        types: Set<AlongRoutePlaceType>.from(_selectedAlongRouteTypes),
        searchRadiusMeters: 2000,
        maxResults: 50,
      );

      var smartFuelCandidates = result.places
          .where((place) => place.type == AlongRoutePlaceType.fuel)
          .toList(growable: false);

      String? smartFuelSearchWarning;

      final fuelRange = _fuelRange;

      if (fuelRange != null &&
          fuelRange.needsFuelStopForDistanceMeters(route.distanceMeters) &&
          _selectedAlongRouteTypes.contains(AlongRoutePlaceType.fuel)) {
        const stationSearcher = SmartFuelStationSearcher();

        final coverageResult = await stationSearcher.search(
          service: service,
          routePoints: route.points,
          safeRangeMeters: fuelRange.safeRangeMeters,
          searchRadiusMeters: 2000,
          maxResultsPerSegment: 20,
        );

        smartFuelCandidates = _mergeFuelCandidates(
          smartFuelCandidates,
          coverageResult.places,
        );

        if (coverageResult.allSegmentsFailed) {
          smartFuelSearchWarning =
              'Không thể mở rộng dữ liệu cây xăng theo từng đoạn; '
              'gợi ý đang dùng các kết quả hiện có.';
        } else if (coverageResult.hasPartialFailures) {
          smartFuelSearchWarning =
              'Đã lấy dữ liệu cây xăng ở '
              '${coverageResult.successfulSegments}/'
              '${coverageResult.segmentCount} đoạn tuyến; '
              '${coverageResult.failedSegments} đoạn chưa tải được. '
              'Gợi ý có thể chưa đầy đủ.';
        }
      }

      final smartFuelPlan = _buildSmartFuelPlan(
        route: route,
        fuelRange: fuelRange,
        places: smartFuelCandidates,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _alongRoutePlaces = result.places;
        _smartFuelPlan = smartFuelPlan;
        _smartFuelSearchWarning = smartFuelSearchWarning;

        _isSearchingAlongRoute = false;
        _hasSearchedAlongRoute = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _alongRoutePlaces = const [];
        _isSearchingAlongRoute = false;
        _hasSearchedAlongRoute = true;
        _smartFuelSearchWarning = null;
        _alongRouteError =
            'Không thể tìm dịch vụ dọc tuyến.\n'
            '$error';
      });
    }
  }

  void _clearAlongRoutePlaces() {
    final route = _route;

    final smartFuelPlan = route == null
        ? null
        : _buildSmartFuelPlan(
            route: route,
            fuelRange: _fuelRange,
            places: const [],
          );

    setState(() {
      _alongRoutePlaces = const [];
      _hasSearchedAlongRoute = false;
      _alongRouteError = null;
      _smartFuelPlan = smartFuelPlan;
      _smartFuelSearchWarning = null;
    });
  }

  void _toggleAlongRouteType(AlongRoutePlaceType type, bool selected) {
    setState(() {
      if (selected) {
        _selectedAlongRouteTypes.add(type);
      } else {
        _selectedAlongRouteTypes.remove(type);
      }

      _alongRouteError = null;
    });
  }

  List<AlongRoutePlace> _mergeFuelCandidates(
    List<AlongRoutePlace> first,
    List<AlongRoutePlace> second,
  ) {
    final deduplicated = <String, AlongRoutePlace>{};

    for (final place in [...first, ...second]) {
      if (place.type != AlongRoutePlaceType.fuel) {
        continue;
      }

      final key = '${place.source}:${place.sourceId}';
      final existing = deduplicated[key];

      if (existing == null) {
        deduplicated[key] = place;
        continue;
      }

      final existingDistance =
          existing.distanceFromRouteMeters ?? double.infinity;
      final newDistance = place.distanceFromRouteMeters ?? double.infinity;

      if (newDistance < existingDistance) {
        deduplicated[key] = place;
      }
    }

    return List<AlongRoutePlace>.unmodifiable(deduplicated.values);
  }

  SmartFuelPlan? _buildSmartFuelPlan({
    required RouteResult route,
    required FuelRangeEstimate? fuelRange,
    required List<AlongRoutePlace> places,
  }) {
    if (fuelRange == null || route.points.length < 2) {
      return null;
    }

    const recommender = SmartFuelStopRecommender();

    return recommender.recommend(
      routePoints: route.points,
      places: places,
      fuelRange: fuelRange,
      maxCorridorMeters: 2000,
    );
  }

  void _focusSmartFuelStop(SmartFuelStopRecommendation recommendation) {
    _mapController.move(
      LatLng(recommendation.place.latitude, recommendation.place.longitude),
      15.5,
    );
  }

  void _showSmartFuelStop(
    BuildContext context,
    SmartFuelStopRecommendation recommendation,
  ) {
    final place = recommendation.place;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.local_gas_station),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: Theme.of(bottomSheetContext)
                                .textTheme
                                .titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gợi ý đổ xăng · Điểm dừng ${recommendation.stopNumber}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _PlaceDetailRow(
                  icon: Icons.flag_outlined,
                  label: 'Vị trí',
                  value:
                      'Km ${recommendation.progress.distanceFromStartKm.toStringAsFixed(1)} của hành trình',
                ),
                _PlaceDetailRow(
                  icon: Icons.route_outlined,
                  label: 'Cách tuyến',
                  value: _formatDistanceFromRoute(
                    recommendation.progress.distanceFromRouteMeters,
                  ),
                ),
                _PlaceDetailRow(
                  icon: Icons.shield_outlined,
                  label: 'Biên an toàn',
                  value: _formatDistanceFromRoute(
                    recommendation.marginBeforeSafeLimitMeters,
                  ),
                ),
                _PlaceDetailRow(
                  icon: Icons.straighten,
                  label: 'Từ điểm trước',
                  value: _formatDistanceFromRoute(
                    recommendation.distanceSincePreviousStopMeters,
                  ),
                ),
                if (place.address != null)
                  _PlaceDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Địa chỉ',
                    value: place.address!,
                  ),
                if (place.openingHours != null)
                  _PlaceDetailRow(
                    icon: Icons.schedule_outlined,
                    label: 'Giờ mở cửa',
                    value: place.openingHours!,
                  ),
                if (place.phone != null)
                  _PlaceDetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Điện thoại',
                    value: place.phone!,
                  ),
                if (place.website != null)
                  _PlaceDetailRow(
                    icon: Icons.language_outlined,
                    label: 'Website',
                    value: place.website!,
                  ),
                _PlaceDetailRow(
                  icon: Icons.map_outlined,
                  label: 'Tọa độ',
                  value:
                      '${place.latitude.toStringAsFixed(6)}, '
                      '${place.longitude.toStringAsFixed(6)}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Khuyến nghị dựa trên giả định xuất phát đầy bình và giữ 25% nhiên liệu dự phòng.',
                  style: Theme.of(bottomSheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Dữ liệu địa điểm: ${_alongRouteSourceLabel(place.source)}.',
                  style: Theme.of(bottomSheetContext).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAlongRoutePlace(BuildContext context, AlongRoutePlace place) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(child: Icon(_alongRouteIcon(place.type))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: Theme.of(bottomSheetContext)
                                .textTheme
                                .titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(place.type.label),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                _PlaceDetailRow(
                  icon: Icons.route_outlined,
                  label: 'Cách tuyến',
                  value: _formatDistanceFromRoute(
                    place.distanceFromRouteMeters,
                  ),
                ),

                if (place.address != null)
                  _PlaceDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Địa chỉ',
                    value: place.address!,
                  ),

                if (place.openingHours != null)
                  _PlaceDetailRow(
                    icon: Icons.schedule_outlined,
                    label: 'Giờ mở cửa',
                    value: place.openingHours!,
                  ),

                if (place.phone != null)
                  _PlaceDetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Điện thoại',
                    value: place.phone!,
                  ),

                if (place.website != null)
                  _PlaceDetailRow(
                    icon: Icons.language_outlined,
                    label: 'Website',
                    value: place.website!,
                  ),

                _PlaceDetailRow(
                  icon: Icons.map_outlined,
                  label: 'Tọa độ',
                  value:
                      '${place.latitude.toStringAsFixed(6)}, '
                      '${place.longitude.toStringAsFixed(6)}',
                ),

                const SizedBox(height: 8),

                Text(
                  'Dữ liệu địa điểm: '
                  '${_alongRouteSourceLabel(place.source)}.',
                  style: Theme.of(bottomSheetContext).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmartFuelSection(BuildContext context) {
    final fuelRange = _fuelRange;
    final plan = _smartFuelPlan;
    final colorScheme = Theme.of(context).colorScheme;

    if (fuelRange == null) {
      if (_smartFuelMessage == null) {
        return const SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.local_gas_station_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _smartFuelMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_gas_station,
                size: 22,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gợi ý đổ xăng thông minh',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryLine(
            label: 'Tầm hoạt động an toàn',
            value: _formatDistanceFromRoute(fuelRange.safeRangeMeters),
          ),
          _SummaryLine(
            label: 'Nhiên liệu dự phòng',
            value: '${(fuelRange.reserveRatio * 100).round()}%',
          ),
          const SizedBox(height: 4),
          Text(
            'Giả định xuất phát đầy bình; ngưỡng dự phòng dùng để chủ động tìm điểm đổ xăng trước khi nhiên liệu xuống thấp.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (plan != null) ...[
            const SizedBox(height: 10),
            if (!plan.fuelStopRequired)
              _SmartFuelStatus(
                icon: Icons.check_circle_outline,
                color: Colors.green.shade700,
                text: 'Tuyến hiện tại nằm trong tầm hoạt động an toàn. Chưa cần dừng đổ xăng.',
              )
            else ...[
              if (plan.routeFullyCovered)
                _SmartFuelStatus(
                  icon: Icons.route_outlined,
                  color: Colors.green.shade700,
                  text:
                      'Đề xuất ${plan.recommendations.length} điểm dừng để duy trì ngưỡng nhiên liệu an toàn.',
                )
              else
                _SmartFuelStatus(
                  icon: Icons.warning_amber_outlined,
                  color: colorScheme.error,
                  text:
                      _selectedAlongRouteTypes.contains(
                        AlongRoutePlaceType.fuel,
                      )
                      ? (_hasSearchedAlongRoute
                            ? 'Các cây xăng tìm được chưa đủ để phủ toàn bộ tuyến trong ngưỡng an toàn.'
                            : 'Tuyến vượt tầm hoạt động an toàn. Hãy tìm dịch vụ dọc tuyến để PhuotThu chọn điểm đổ xăng.')
                      : 'Tuyến vượt tầm hoạt động an toàn. Hãy bật bộ lọc Cây xăng và tìm lại dịch vụ dọc tuyến.',
                ),
              if (plan.recommendations.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...plan.recommendations.map(
                  (recommendation) => _SmartFuelStopTile(
                    recommendation: recommendation,
                    onTap: () {
                      _focusSmartFuelStop(recommendation);
                      _showSmartFuelStop(context, recommendation);
                    },
                  ),
                ),
              ],
            ],
          ],
          if (_smartFuelSearchWarning != null) ...[
            const SizedBox(height: 8),
            Text(
              _smartFuelSearchWarning!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  IconData _alongRouteIcon(AlongRoutePlaceType type) {
    switch (type) {
      case AlongRoutePlaceType.fuel:
        return Icons.local_gas_station;
      case AlongRoutePlaceType.restArea:
        return Icons.hotel_outlined;
      case AlongRoutePlaceType.food:
        return Icons.restaurant_outlined;
      case AlongRoutePlaceType.repair:
        return Icons.build_outlined;
      case AlongRoutePlaceType.medical:
        return Icons.local_hospital_outlined;
    }
  }

  Color _alongRouteColor(AlongRoutePlaceType type) {
    switch (type) {
      case AlongRoutePlaceType.fuel:
        return Colors.amber.shade800;
      case AlongRoutePlaceType.restArea:
        return Colors.indigo;
      case AlongRoutePlaceType.food:
        return Colors.deepOrange;
      case AlongRoutePlaceType.repair:
        return Colors.blueGrey;
      case AlongRoutePlaceType.medical:
        return Colors.red;
    }
  }

  String _alongRouteSourceLabel(String source) {
    switch (source.toLowerCase()) {
      case 'geoapify':
        return 'Geoapify';
      case 'overpass':
        return 'OpenStreetMap / Overpass';
      default:
        return source.trim().isEmpty ? 'Không xác định' : source;
    }
  }

  String _formatDistanceFromRoute(double? meters) {
    if (meters == null) {
      return 'Không xác định';
    }

    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
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

    final smartFuelRecommendations =
        _smartFuelPlan?.recommendations ??
        const <SmartFuelStopRecommendation>[];

    final recommendedFuelSourceIds = smartFuelRecommendations
        .map((recommendation) => recommendation.place.sourceId)
        .toSet();

    final alongRouteMarkers = _alongRoutePlaces
        .where((place) => !recommendedFuelSourceIds.contains(place.sourceId))
        .map((place) {
          return Marker(
            point: LatLng(place.latitude, place.longitude),
            width: 42,
            height: 42,
            child: GestureDetector(
              onTap: () {
                _showAlongRoutePlace(context, place);
              },
              child: _AlongRouteMarker(
                icon: _alongRouteIcon(place.type),
                color: _alongRouteColor(place.type),
              ),
            ),
          );
        });

    final smartFuelMarkers = smartFuelRecommendations.map((recommendation) {
      final place = recommendation.place;

      return Marker(
        point: LatLng(place.latitude, place.longitude),
        width: 54,
        height: 54,
        child: GestureDetector(
          onTap: () {
            _focusSmartFuelStop(recommendation);
            _showSmartFuelStop(context, recommendation);
          },
          child: _SmartFuelMarker(stopNumber: recommendation.stopNumber),
        ),
      );
    });

    final displayedAlongRouteTypes = AlongRoutePlaceType.values
        .where((type) => _alongRoutePlaces.any((place) => place.type == type))
        .toList(growable: false);

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
                ...alongRouteMarkers,
                ...smartFuelMarkers,

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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.58,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
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

                    const Divider(height: 24),

                    _buildSmartFuelSection(context),

                    const Divider(height: 24),

                    Row(
                      children: [
                        const Icon(Icons.travel_explore_outlined, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dịch vụ dọc tuyến',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (_alongRoutePlaces.isNotEmpty)
                          Text(
                            '${_alongRoutePlaces.length} điểm',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: AlongRoutePlaceType.values.map((type) {
                        return FilterChip(
                          selected: _selectedAlongRouteTypes.contains(type),
                          avatar: Icon(_alongRouteIcon(type), size: 18),
                          label: Text(type.label),
                          onSelected: _isSearchingAlongRoute
                              ? null
                              : (selected) {
                                  _toggleAlongRouteType(type, selected);
                                },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _isSearchingAlongRoute ||
                                _selectedAlongRouteTypes.isEmpty
                            ? null
                            : _searchAlongRoute,
                        icon: _isSearchingAlongRoute
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(
                          _isSearchingAlongRoute
                              ? 'Đang tìm dịch vụ...'
                              : 'Tìm dịch vụ dọc tuyến',
                        ),
                      ),
                    ),

                    if (_hasSearchedAlongRoute && _alongRouteError == null) ...[
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _alongRoutePlaces.isEmpty
                                  ? 'Không tìm thấy dịch vụ phù hợp trong phạm vi 2 km quanh tuyến.'
                                  : 'Đã tìm thấy ${_alongRoutePlaces.length} địa điểm trong phạm vi 2 km quanh tuyến.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),

                          if (_alongRoutePlaces.isNotEmpty)
                            TextButton(
                              onPressed: _clearAlongRoutePlaces,
                              child: const Text('Xóa'),
                            ),
                        ],
                      ),

                      if (displayedAlongRouteTypes.isNotEmpty ||
                          smartFuelRecommendations.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Chú giải marker',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            ...displayedAlongRouteTypes.map((type) {
                              return _AlongRouteLegendItem(
                                icon: _alongRouteIcon(type),
                                color: _alongRouteColor(type),
                                label: type.label,
                              );
                            }),
                            if (smartFuelRecommendations.isNotEmpty)
                              _AlongRouteLegendItem(
                                icon: Icons.local_gas_station,
                                color: Colors.green.shade700,
                                label: 'Gợi ý đổ xăng',
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Dữ liệu POI: Geoapify.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],

                    if (_alongRouteError != null) ...[
                      const SizedBox(height: 10),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _alongRouteError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
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

class _AlongRouteMarker extends StatelessWidget {
  const _AlongRouteMarker({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: color,
      shape: const CircleBorder(),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 21, color: Colors.white),
      ),
    );
  }
}

class _SmartFuelMarker extends StatelessWidget {
  const _SmartFuelMarker({required this.stopNumber});

  final int stopNumber;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          elevation: 8,
          color: Colors.green.shade700,
          shape: const CircleBorder(
            side: BorderSide(color: Colors.white, width: 3),
          ),
          child: const SizedBox(
            width: 46,
            height: 46,
            child: Icon(Icons.local_gas_station, size: 24, color: Colors.white),
          ),
        ),
        Positioned(
          right: -2,
          top: -4,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green.shade700, width: 2),
            ),
            child: Text(
              '$stopNumber',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SmartFuelStatus extends StatelessWidget {
  const _SmartFuelStatus({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _SmartFuelStopTile extends StatelessWidget {
  const _SmartFuelStopTile({required this.recommendation, required this.onTap});

  final SmartFuelStopRecommendation recommendation;
  final VoidCallback onTap;

  String _formatMeters(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final place = recommendation.place;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          child: Text(
            '${recommendation.stopNumber}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Km ${recommendation.progress.distanceFromStartKm.toStringAsFixed(1)} · '
          'cách tuyến ${_formatMeters(recommendation.progress.distanceFromRouteMeters)} · '
          'còn ${_formatMeters(recommendation.marginBeforeSafeLimitMeters)} trước ngưỡng',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.my_location_outlined),
        onTap: onTap,
      ),
    );
  }
}

class _AlongRouteLegendItem extends StatelessWidget {
  const _AlongRouteLegendItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
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

class _PlaceDetailRow extends StatelessWidget {
  const _PlaceDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
