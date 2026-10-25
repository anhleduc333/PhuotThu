import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../map/data/along_route_providers.dart';
import '../../../map/data/route_providers.dart';
import '../../../map/domain/along_route_place.dart';
import '../../../map/domain/route_result.dart';
import '../../../vehicle/data/vehicle_repository.dart';
import '../../../vehicle/domain/vehicle.dart';
import '../../data/connectivity_risk_providers.dart';
import '../../data/connectivity_risk_service.dart';
import '../../data/fuel_price_repository.dart';
import '../../data/offline_trip_cache_providers.dart';
import '../../data/smart_fuel_station_searcher.dart';
import '../../data/smart_rest_place_searcher.dart';
import '../../data/trip_budget_providers.dart';
import '../../data/trip_budget_repository.dart';
import '../../data/trip_providers.dart';
import '../../data/trip_repository.dart';
import '../../data/trip_route_repository.dart';
import '../../data/trip_readiness_checklist_providers.dart';
import '../../domain/connectivity_risk.dart';
import '../../domain/emergency_readiness.dart';
import '../../domain/fuel_range_calculator.dart';
import '../../domain/offline_readiness.dart';
import '../../domain/offline_readiness_evaluator.dart';
import '../../domain/offline_readiness_scorer.dart';
import '../../domain/offline_trip_package_snapshot.dart';
import '../../domain/personal_readiness.dart';
import '../../domain/route_weather_readiness.dart';
import '../../domain/rest_policy_calculator.dart';
import '../../domain/smart_fuel_stop_recommender.dart';
import '../../domain/smart_rest_stop_recommender.dart';
import '../../domain/trip.dart';
import '../../domain/trip_budget_calculator.dart';
import '../../domain/trip_cost_estimator.dart';
import '../../domain/trip_fuel_estimator.dart';
import '../../domain/trip_route_points.dart';
import '../../domain/trip_readiness.dart';
import '../../domain/trip_readiness_checklist_snapshot.dart';
import '../../domain/trip_readiness_composer.dart';
import '../../domain/vehicle_readiness.dart';
import '../connectivity_risk_map_segments.dart';
import '../widgets/trip_readiness_panel.dart';

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

  SmartRestPlan? _smartFoodPlan;
  String? _smartFoodSearchWarning;

  SmartRestPlan? _smartRestPlan;
  String? _smartRestSearchWarning;

  ConnectivityRiskAnalysisSummary? _connectivityRiskSummary;
  bool _isAnalyzingConnectivityRisk = false;
  String? _connectivityRiskError;

  bool _isSavingOfflinePackage = false;
  OfflineTripPackageSnapshot? _offlinePackageSnapshot;
  bool _hasOfflinePackage = false;
  bool _offlinePackageNeedsRefresh = false;
  DateTime? _offlinePackageSavedAt;
  int _offlinePackagePoiCount = 0;
  bool _offlinePackageHasConnectivity = false;
  String? _offlinePackageError;

  Vehicle? _readinessVehicle;
  TripReadinessChecklistSnapshot? _tripReadinessChecklist;
  bool _isLoadingTripReadiness = true;
  bool _isSavingTripReadiness = false;
  String? _tripReadinessError;

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

    Future.microtask(() async {
      await _loadTripReadinessChecklist();

      if (mounted) {
        await _loadRoute();
      }
    });

    Future.microtask(_loadOfflinePackageState);
  }

  Future<void> _loadTripReadinessChecklist() async {
    try {
      final snapshot = await ref
          .read(tripReadinessChecklistServiceProvider)
          .loadOrCreate(widget.tripId);

      if (!mounted) {
        return;
      }

      setState(() {
        _tripReadinessChecklist = snapshot;
        _isLoadingTripReadiness = false;
        _tripReadinessError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingTripReadiness = false;
        _tripReadinessError =
            'Không thể đọc checklist chuẩn bị chuyến đi.\n$error';
      });
    }
  }

  Future<void> _loadOfflinePackageState() async {
    try {
      final service = ref.read(offlineTripPackageServiceProvider);
      final snapshot = await service.loadPackage(widget.tripId);

      if (!mounted) {
        return;
      }

      setState(() {
        _offlinePackageSnapshot = snapshot;
        _hasOfflinePackage = snapshot != null;
        _offlinePackageNeedsRefresh = false;
        _offlinePackageSavedAt = snapshot?.savedAt;
        _offlinePackagePoiCount = snapshot?.pois.length ?? 0;
        _offlinePackageHasConnectivity = snapshot?.connectivity != null;
        _offlinePackageError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _offlinePackageError = 'Không thể đọc dữ liệu offline đã lưu.\n$error';
      });
    }
  }

  Future<void> _loadRoute() async {
    final isManualRefresh = _route != null;
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

        _smartFoodPlan = null;
        _smartFoodSearchWarning = null;

        _smartRestPlan = null;
        _smartRestSearchWarning = null;

        _connectivityRiskSummary = null;
        _isAnalyzingConnectivityRisk = false;
        _connectivityRiskError = null;

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

      final baseSmartFoodPlan = _buildSmartRestPlan(
        route: route,
        places: const [],
        eligibleTypes: const {AlongRoutePlaceType.food},
        restPolicy: const RestPolicy(),
      );

      final baseSmartRestPlan = _buildSmartRestPlan(
        route: route,
        places: const [],
        eligibleTypes: const {AlongRoutePlaceType.restArea},
        restPolicy: _accommodationRestPolicy,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = routePoints;
        _route = route;
        _smartFoodPlan = baseSmartFoodPlan;
        _smartRestPlan = baseSmartRestPlan;
        _isLoading = false;

        if (isManualRefresh && _hasOfflinePackage) {
          _offlinePackageNeedsRefresh = true;
        }
      });

      await _syncReadinessRouteFingerprint(route);

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
            _readinessVehicle = null;
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

      if (mounted) {
        setState(() {
          _readinessVehicle = vehicle;
        });
      }

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
      _smartFoodSearchWarning = null;
      _smartRestSearchWarning = null;
    });

    try {
      final service = ref.read(alongRouteServiceProvider);

      final result = await service.search(
        routePoints: route.points,
        types: {..._selectedAlongRouteTypes},
        searchRadiusMeters: 2000,
        maxResults: 50,
      );

      var smartFuelCandidates = result.places
          .where((place) => place.type == AlongRoutePlaceType.fuel)
          .toList(growable: false);

      var smartFoodCandidates = result.places
          .where((place) => place.type == AlongRoutePlaceType.food)
          .toList(growable: false);

      var smartRestCandidates = result.places
          .where((place) => place.type == AlongRoutePlaceType.restArea)
          .toList(growable: false);

      String? smartFuelSearchWarning;
      String? smartFoodSearchWarning;
      String? smartRestSearchWarning;

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

      const restPolicyCalculator = RestPolicyCalculator();
      const restSearcher = SmartRestPlaceSearcher();

      if (_selectedAlongRouteTypes.contains(AlongRoutePlaceType.food)) {
        final foodPolicyPlan = restPolicyCalculator.calculate(
          distanceMeters: route.distanceMeters,
          durationSeconds: route.durationSeconds,
          policy: const RestPolicy(),
        );

        if (foodPolicyPlan != null && foodPolicyPlan.restRecommended) {
          final foodCoverageResult = await restSearcher.search(
            service: service,
            routePoints: route.points,
            targets: foodPolicyPlan.targets,
            types: const {AlongRoutePlaceType.food},
            searchRadiusMeters: 2000,
            targetWindowMeters: 25000,
            maxResultsPerTarget: 30,
          );

          smartFoodCandidates = _mergeRestCandidates(
            smartFoodCandidates,
            foodCoverageResult.places,
          );

          if (foodCoverageResult.allTargetSearchesFailed) {
            smartFoodSearchWarning =
                'Không thể mở rộng dữ liệu ăn uống quanh các mốc nghỉ chân; '
                'gợi ý đang dùng các kết quả hiện có.';
          } else if (foodCoverageResult.hasPartialFailures) {
            smartFoodSearchWarning =
                'Đã lấy dữ liệu ăn uống ở '
                '${foodCoverageResult.successfulTargets}/'
                '${foodCoverageResult.targetCount} mốc; '
                '${foodCoverageResult.failedTargets} mốc chưa tải được. '
                'Gợi ý có thể chưa đầy đủ.';
          }
        }
      }

      if (_selectedAlongRouteTypes.contains(AlongRoutePlaceType.restArea)) {
        final accommodationPolicyPlan = restPolicyCalculator.calculate(
          distanceMeters: route.distanceMeters,
          durationSeconds: route.durationSeconds,
          policy: _accommodationRestPolicy,
        );

        if (accommodationPolicyPlan != null &&
            accommodationPolicyPlan.restRecommended) {
          final restCoverageResult = await restSearcher.search(
            service: service,
            routePoints: route.points,
            targets: accommodationPolicyPlan.targets,
            types: const {AlongRoutePlaceType.restArea},
            searchRadiusMeters: 3000,
            targetWindowMeters: 40000,
            maxResultsPerTarget: 30,
          );

          smartRestCandidates = _mergeRestCandidates(
            smartRestCandidates,
            restCoverageResult.places,
          );

          if (restCoverageResult.allTargetSearchesFailed) {
            smartRestSearchWarning =
                'Không thể mở rộng dữ liệu lưu trú quanh các mốc nghỉ đêm; '
                'gợi ý đang dùng các kết quả hiện có.';
          } else if (restCoverageResult.hasPartialFailures) {
            smartRestSearchWarning =
                'Đã lấy dữ liệu lưu trú ở '
                '${restCoverageResult.successfulTargets}/'
                '${restCoverageResult.targetCount} mốc; '
                '${restCoverageResult.failedTargets} mốc chưa tải được. '
                'Gợi ý có thể chưa đầy đủ.';
          }
        }
      }

      final smartFuelPlan = _buildSmartFuelPlan(
        route: route,
        fuelRange: fuelRange,
        places: smartFuelCandidates,
      );

      final smartFoodPlan =
          _selectedAlongRouteTypes.contains(AlongRoutePlaceType.food)
          ? _buildSmartRestPlan(
              route: route,
              places: smartFoodCandidates,
              eligibleTypes: const {AlongRoutePlaceType.food},
              restPolicy: const RestPolicy(),
            )
          : _buildSmartRestPlan(
              route: route,
              places: const [],
              eligibleTypes: const {AlongRoutePlaceType.food},
              restPolicy: const RestPolicy(),
            );

      final smartRestPlan =
          _selectedAlongRouteTypes.contains(AlongRoutePlaceType.restArea)
          ? _buildSmartRestPlan(
              route: route,
              places: smartRestCandidates,
              eligibleTypes: const {AlongRoutePlaceType.restArea},
              restPolicy: _accommodationRestPolicy,
            )
          : _buildSmartRestPlan(
              route: route,
              places: const [],
              eligibleTypes: const {AlongRoutePlaceType.restArea},
              restPolicy: _accommodationRestPolicy,
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _alongRoutePlaces = result.places;
        _smartFuelPlan = smartFuelPlan;
        _smartFuelSearchWarning = smartFuelSearchWarning;
        _smartFoodPlan = smartFoodPlan;
        _smartFoodSearchWarning = smartFoodSearchWarning;
        _smartRestPlan = smartRestPlan;
        _smartRestSearchWarning = smartRestSearchWarning;

        _isSearchingAlongRoute = false;
        _hasSearchedAlongRoute = true;

        if (_hasOfflinePackage) {
          _offlinePackageNeedsRefresh = true;
        }
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
        _smartFoodSearchWarning = null;
        _smartRestSearchWarning = null;
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

    final smartFoodPlan = route == null
        ? null
        : _buildSmartRestPlan(
            route: route,
            places: const [],
            eligibleTypes: const {AlongRoutePlaceType.food},
            restPolicy: const RestPolicy(),
          );

    final smartRestPlan = route == null
        ? null
        : _buildSmartRestPlan(
            route: route,
            places: const [],
            eligibleTypes: const {AlongRoutePlaceType.restArea},
            restPolicy: _accommodationRestPolicy,
          );

    setState(() {
      _alongRoutePlaces = const [];
      _hasSearchedAlongRoute = false;
      _alongRouteError = null;
      _smartFuelPlan = smartFuelPlan;
      _smartFuelSearchWarning = null;
      _smartFoodPlan = smartFoodPlan;
      _smartFoodSearchWarning = null;
      _smartRestPlan = smartRestPlan;
      _smartRestSearchWarning = null;
    });
  }

  void _toggleAlongRouteType(AlongRoutePlaceType type, bool selected) {
    final route = _route;

    setState(() {
      if (selected) {
        _selectedAlongRouteTypes.add(type);
      } else {
        _selectedAlongRouteTypes.remove(type);
      }

      // Bộ lọc đã thay đổi nên kết quả cũ không còn phản ánh lựa chọn hiện tại.
      _alongRoutePlaces = const [];
      _hasSearchedAlongRoute = false;
      _alongRouteError = null;
      _smartFuelSearchWarning = null;
      _smartFoodSearchWarning = null;
      _smartRestSearchWarning = null;

      if (route != null) {
        _smartFuelPlan = _buildSmartFuelPlan(
          route: route,
          fuelRange: _fuelRange,
          places: const [],
        );

        _smartFoodPlan = _buildSmartRestPlan(
          route: route,
          places: const [],
          eligibleTypes: const {AlongRoutePlaceType.food},
          restPolicy: const RestPolicy(),
        );

        _smartRestPlan = _buildSmartRestPlan(
          route: route,
          places: const [],
          eligibleTypes: const {AlongRoutePlaceType.restArea},
          restPolicy: _accommodationRestPolicy,
        );
      }
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

  List<AlongRoutePlace> _mergeRestCandidates(
    List<AlongRoutePlace> first,
    List<AlongRoutePlace> second,
  ) {
    final deduplicated = <String, AlongRoutePlace>{};

    for (final place in [...first, ...second]) {
      if (place.type != AlongRoutePlaceType.restArea &&
          place.type != AlongRoutePlaceType.food) {
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

  static const RestPolicy _accommodationRestPolicy = RestPolicy(
    driveIntervalMinutes: 480,
    distanceIntervalKm: 400,
    suggestedRestMinutes: 480,
    minimumRemainingDistanceKm: 100,
    minimumRemainingTimeMinutes: 120,
    maxStops: 8,
  );

  SmartRestPlan? _buildSmartRestPlan({
    required RouteResult route,
    required List<AlongRoutePlace> places,
    required Set<AlongRoutePlaceType> eligibleTypes,
    required RestPolicy restPolicy,
  }) {
    if (route.points.length < 2 || eligibleTypes.isEmpty) {
      return null;
    }

    const recommender = SmartRestStopRecommender();

    return recommender.recommend(
      routePoints: route.points,
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      places: places,
      restPolicy: restPolicy,
      eligibleTypes: eligibleTypes,
    );
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

  void _focusSmartFoodStop(SmartRestStopRecommendation recommendation) {
    _mapController.move(
      LatLng(recommendation.place.latitude, recommendation.place.longitude),
      15.5,
    );
  }

  void _showSmartFoodStop(
    BuildContext context,
    SmartRestStopRecommendation recommendation,
  ) {
    final place = recommendation.place;
    final target = recommendation.target;
    final isDrink = _isDrinkPlace(place);
    final color = isDrink ? Colors.teal.shade700 : Colors.deepOrange;
    final icon = isDrink ? Icons.local_cafe : Icons.restaurant;
    final kindLabel = isDrink ? 'Uống / cafe' : 'Ăn';

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
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      child: Icon(icon),
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
                            'Gợi ý ăn uống · $kindLabel · Mốc ${target.stopNumber}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _PlaceDetailRow(
                  icon: Icons.flag_outlined,
                  label: 'Mốc nghỉ chân lý tưởng',
                  value:
                      'Km ${target.targetDistanceKm.toStringAsFixed(1)} · '
                      '${_formatDuration(target.targetElapsedSeconds.round())}',
                ),
                _PlaceDetailRow(
                  icon: Icons.place_outlined,
                  label: 'POI thực tế',
                  value:
                      'Km ${recommendation.routePositionKm.toStringAsFixed(1)} của hành trình',
                ),
                _PlaceDetailRow(
                  icon: Icons.compare_arrows,
                  label: 'Lệch mốc',
                  value: _formatDistanceFromRoute(
                    recommendation.candidate.distanceFromTargetMeters,
                  ),
                ),
                _PlaceDetailRow(
                  icon: Icons.route_outlined,
                  label: 'Cách tuyến',
                  value: _formatDistanceFromRoute(
                    recommendation.routeDeviationMeters,
                  ),
                ),
                _PlaceDetailRow(
                  icon: Icons.star_outline,
                  label: 'Điểm phù hợp',
                  value: '${recommendation.score.toStringAsFixed(0)}/100',
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
                const SizedBox(height: 8),
                Text(
                  'Ăn và uống được tách bằng category của Geoapify; cafe/quán đồ uống hiển thị xanh ngọc, địa điểm ăn hiển thị cam.',
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

  void _focusSmartRestStop(SmartRestStopRecommendation recommendation) {
    _mapController.move(
      LatLng(recommendation.place.latitude, recommendation.place.longitude),
      15.5,
    );
  }

  void _showSmartRestStop(
    BuildContext context,
    SmartRestStopRecommendation recommendation,
  ) {
    final place = recommendation.place;
    final target = recommendation.target;

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
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.hotel),
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
                          Text('Gợi ý nghỉ/lưu trú · Mốc ${target.stopNumber}'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _PlaceDetailRow(
                  icon: Icons.flag_outlined,
                  label: 'Mốc nghỉ đêm lý tưởng',
                  value:
                      'Km ${target.targetDistanceKm.toStringAsFixed(1)} · '
                      '${_formatDuration(target.targetElapsedSeconds.round())}',
                ),
                _PlaceDetailRow(
                  icon: Icons.place_outlined,
                  label: 'POI thực tế',
                  value:
                      'Km ${recommendation.routePositionKm.toStringAsFixed(1)} của hành trình',
                ),
                _PlaceDetailRow(
                  icon: Icons.compare_arrows,
                  label: 'Lệch mốc nghỉ',
                  value: _formatDistanceFromRoute(
                    recommendation.candidate.distanceFromTargetMeters,
                  ),
                ),
                _PlaceDetailRow(
                  icon: Icons.route_outlined,
                  label: 'Cách tuyến',
                  value: _formatDistanceFromRoute(
                    recommendation.routeDeviationMeters,
                  ),
                ),
                _PlaceDetailRow(
                  icon: Icons.star_outline,
                  label: 'Điểm phù hợp',
                  value: '${recommendation.score.toStringAsFixed(0)}/100',
                ),
                _PlaceDetailRow(
                  icon: Icons.timer_outlined,
                  label: 'Thời gian ngủ nghỉ gợi ý',
                  value: '${target.suggestedRestMinutes} phút',
                ),
                _PlaceDetailRow(
                  icon: Icons.info_outline,
                  label: 'Kích hoạt bởi',
                  value: target.trigger.label,
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
                const SizedBox(height: 8),
                Text(
                  'Mốc lưu trú là policy lập kế hoạch của PhuotThu cho hành trình dài; không phải quy định bắt buộc.',
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
                    CircleAvatar(
                      backgroundColor: _alongRoutePlaceColor(place),
                      foregroundColor: Colors.white,
                      child: Icon(_alongRoutePlaceIcon(place)),
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
                          Text(_alongRoutePlaceLabel(place)),
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

  Widget _buildSmartFoodSection(BuildContext context) {
    final plan = _smartFoodPlan;

    if (plan == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final policy = plan.restPlan.policy;
    final selected = _selectedAlongRouteTypes.contains(
      AlongRoutePlaceType.food,
    );

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
              Icon(Icons.restaurant_menu, size: 22, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gợi ý ăn uống thông minh',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryLine(
            label: 'Chu kỳ nghỉ chân',
            value: '${policy.driveIntervalMinutes} phút',
          ),
          _SummaryLine(
            label: 'Hoặc theo quãng đường',
            value: '${policy.distanceIntervalKm.toStringAsFixed(0)} km',
          ),
          const SizedBox(height: 4),
          Text(
            'Địa điểm ăn hiển thị màu cam; cafe/quán đồ uống hiển thị màu xanh ngọc.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (!plan.restRequired)
            _SmartRestStatus(
              icon: Icons.check_circle_outline,
              color: Colors.deepOrange,
              text: 'Tuyến hiện tại chưa tới mốc cần gợi ý ăn uống/nghỉ chân.',
            )
          else if (!selected)
            _SmartRestStatus(
              icon: Icons.info_outline,
              color: colorScheme.onSurfaceVariant,
              text: 'Bật bộ lọc Ăn uống rồi tìm lại dịch vụ để nhận gợi ý ăn và uống.',
            )
          else ...[
            if (plan.allTargetsCovered)
              _SmartRestStatus(
                icon: Icons.route_outlined,
                color: Colors.deepOrange,
                text:
                    'Đã đề xuất ${plan.recommendationCount}/${plan.targetCount} điểm ăn uống cho các mốc nghỉ chân.',
              )
            else
              _SmartRestStatus(
                icon: Icons.warning_amber_outlined,
                color: colorScheme.error,
                text: _hasSearchedAlongRoute
                    ? 'Đã chọn ${plan.recommendationCount}/${plan.targetCount} điểm ăn uống; còn ${plan.uncoveredTargetCount} mốc chưa tìm được POI phù hợp.'
                    : 'Tuyến này có ${plan.targetCount} mốc nghỉ chân. Hãy tìm dịch vụ dọc tuyến để PhuotThu chọn địa điểm ăn/uống phù hợp.',
              ),
            if (plan.recommendations.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...plan.recommendations.map(
                (recommendation) => _SmartFoodStopTile(
                  recommendation: recommendation,
                  isDrink: _isDrinkPlace(recommendation.place),
                  onTap: () {
                    _focusSmartFoodStop(recommendation);
                    _showSmartFoodStop(context, recommendation);
                  },
                ),
              ),
            ],
          ],
          if (_smartFoodSearchWarning != null) ...[
            const SizedBox(height: 8),
            Text(
              _smartFoodSearchWarning!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmartRestSection(BuildContext context) {
    final plan = _smartRestPlan;

    if (plan == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final policy = plan.restPlan.policy;
    final selected = _selectedAlongRouteTypes.contains(
      AlongRoutePlaceType.restArea,
    );

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
              const Icon(Icons.hotel, size: 22, color: Colors.indigo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gợi ý nghỉ/lưu trú thông minh',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryLine(
            label: 'Mốc xem xét lưu trú',
            value: '${policy.driveIntervalMinutes ~/ 60} giờ',
          ),
          _SummaryLine(
            label: 'Hoặc theo quãng đường',
            value: '${policy.distanceIntervalKm.toStringAsFixed(0)} km',
          ),
          _SummaryLine(
            label: 'Ngủ nghỉ gợi ý',
            value: '${policy.suggestedRestMinutes ~/ 60} giờ',
          ),
          const SizedBox(height: 4),
          Text(
            'Điểm nghỉ ở đây là cơ sở lưu trú như khách sạn, nhà nghỉ/guest house, motel và hostel.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (!plan.restRequired)
            _SmartRestStatus(
              icon: Icons.check_circle_outline,
              color: Colors.indigo,
              text: 'Tuyến hiện tại chưa tới mốc cần gợi ý lưu trú qua đêm.',
            )
          else if (!selected)
            _SmartRestStatus(
              icon: Icons.info_outline,
              color: colorScheme.onSurfaceVariant,
              text: 'Bật bộ lọc Điểm nghỉ rồi tìm lại dịch vụ để nhận gợi ý khách sạn/nhà nghỉ.',
            )
          else ...[
            if (plan.allTargetsCovered)
              _SmartRestStatus(
                icon: Icons.hotel_outlined,
                color: Colors.indigo,
                text:
                    'Đã đề xuất ${plan.recommendationCount}/${plan.targetCount} điểm lưu trú cho hành trình dài.',
              )
            else
              _SmartRestStatus(
                icon: Icons.warning_amber_outlined,
                color: colorScheme.error,
                text: _hasSearchedAlongRoute
                    ? 'Đã chọn ${plan.recommendationCount}/${plan.targetCount} điểm lưu trú; còn ${plan.uncoveredTargetCount} mốc chưa tìm được cơ sở phù hợp.'
                    : 'Tuyến này có ${plan.targetCount} mốc nên xem xét lưu trú. Hãy tìm dịch vụ dọc tuyến để PhuotThu chọn khách sạn/nhà nghỉ phù hợp.',
              ),
            if (plan.recommendations.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...plan.recommendations.map(
                (recommendation) => _SmartRestStopTile(
                  recommendation: recommendation,
                  onTap: () {
                    _focusSmartRestStop(recommendation);
                    _showSmartRestStop(context, recommendation);
                  },
                ),
              ),
            ],
          ],
          if (_smartRestSearchWarning != null) ...[
            const SizedBox(height: 8),
            Text(
              _smartRestSearchWarning!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  String _alongRouteFilterLabel(AlongRoutePlaceType type) {
    switch (type) {
      case AlongRoutePlaceType.fuel:
        return 'Cây xăng';
      case AlongRoutePlaceType.restArea:
        return 'Nghỉ / lưu trú';
      case AlongRoutePlaceType.food:
        return 'Ăn uống';
      case AlongRoutePlaceType.repair:
        return 'Sửa chữa';
      case AlongRoutePlaceType.medical:
        return 'Y tế';
    }
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
        return Colors.green.shade700;
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

  bool _isDrinkPlace(AlongRoutePlace place) {
    if (place.type != AlongRoutePlaceType.food) {
      return false;
    }

    final categories = (place.tags['categories'] ?? '').toLowerCase();

    return categories.contains('catering.cafe') ||
        categories.contains('catering.bar') ||
        categories.contains('catering.pub') ||
        categories.contains('catering.biergarten');
  }

  IconData _alongRoutePlaceIcon(AlongRoutePlace place) {
    if (place.type == AlongRoutePlaceType.food && _isDrinkPlace(place)) {
      return Icons.local_cafe;
    }

    return _alongRouteIcon(place.type);
  }

  Color _alongRoutePlaceColor(AlongRoutePlace place) {
    if (place.type == AlongRoutePlaceType.food && _isDrinkPlace(place)) {
      return Colors.teal.shade700;
    }

    return _alongRouteColor(place.type);
  }

  String _alongRoutePlaceLabel(AlongRoutePlace place) {
    if (place.type == AlongRoutePlaceType.food) {
      return _isDrinkPlace(place) ? 'Uống / cafe' : 'Ăn';
    }

    if (place.type == AlongRoutePlaceType.restArea) {
      return 'Nghỉ / lưu trú';
    }

    return place.type.label;
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

  Future<void> _analyzeConnectivityRisk() async {
    final route = _route;

    if (route == null || route.points.length < 2) {
      return;
    }

    setState(() {
      _isAnalyzingConnectivityRisk = true;
      _connectivityRiskError = null;
    });

    try {
      final service = ref.read(connectivityRiskServiceProvider);

      final summary = await service.analyzeRoute(
        routePoints: route.points,
        routeDistanceMeters: route.distanceMeters.toDouble(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _connectivityRiskSummary = summary;
        _isAnalyzingConnectivityRisk = false;

        if (_hasOfflinePackage) {
          _offlinePackageNeedsRefresh = true;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _connectivityRiskSummary = null;
        _isAnalyzingConnectivityRisk = false;
        _connectivityRiskError = 'Không thể phân tích nguy cơ kết nối.\n$error';
      });
    }
  }

  void _clearConnectivityRisk() {
    setState(() {
      _connectivityRiskSummary = null;
      _connectivityRiskError = null;

      if (_hasOfflinePackage) {
        _offlinePackageNeedsRefresh = true;
      }
    });
  }

  Color _connectivityRiskColor(ConnectivityRiskLevel level) {
    switch (level) {
      case ConnectivityRiskLevel.unknown:
        return Colors.blueGrey;
      case ConnectivityRiskLevel.low:
        return Colors.green.shade700;
      case ConnectivityRiskLevel.moderate:
        return Colors.amber.shade700;
      case ConnectivityRiskLevel.high:
        return Colors.deepOrange;
      case ConnectivityRiskLevel.critical:
        return Colors.red.shade700;
    }
  }

  Widget _buildConnectivityRiskSection(BuildContext context) {
    final summary = _connectivityRiskSummary;
    final assessment = summary?.assessment;
    final colorScheme = Theme.of(context).colorScheme;

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
                Icons.signal_cellular_alt,
                size: 22,
                color: assessment == null
                    ? colorScheme.primary
                    : _connectivityRiskColor(assessment.overallLevel),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nguy cơ kết nối dọc tuyến',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (summary != null)
                TextButton(
                  onPressed: _isAnalyzingConnectivityRisk
                      ? null
                      : _clearConnectivityRisk,
                  child: const Text('Xóa'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Phân tích này hỗ trợ chuẩn bị cho các đoạn đường có nguy cơ '
            'kết nối kém. Kết quả hiện tại chủ yếu là ước lượng proxy, '
            'không phải xác nhận vùng mất sóng.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isAnalyzingConnectivityRisk
                  ? null
                  : _analyzeConnectivityRisk,
              icon: _isAnalyzingConnectivityRisk
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.radar),
              label: Text(
                _isAnalyzingConnectivityRisk
                    ? 'Đang phân tích nguy cơ...'
                    : summary == null
                    ? 'Phân tích nguy cơ kết nối'
                    : 'Phân tích lại',
              ),
            ),
          ),
          if (_connectivityRiskError != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  size: 20,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectivityRiskError!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
          if (summary != null) ...[
            const SizedBox(height: 10),
            _SummaryLine(
              label: 'Chất lượng dữ liệu',
              value: summary.dataQualityLabel,
            ),
            _SummaryLine(
              label: 'Điểm mẫu đánh giá',
              value:
                  '${summary.routeAnalysis.scoredPointCount}/'
                  '${summary.routeAnalysis.sampleCount}',
            ),
            if (assessment != null) ...[
              _SummaryLine(
                label: 'Mức rủi ro tổng thể',
                value: assessment.overallLevel.label,
                emphasis: assessment.overallLevel.requiresWarning,
              ),
              _SummaryLine(
                label: 'Điểm rủi ro',
                value:
                    '${(assessment.overallRiskScore * 100).toStringAsFixed(0)}/100',
                emphasis: assessment.overallLevel.requiresWarning,
              ),
              _SummaryLine(
                label: 'Đoạn cần cảnh báo',
                value:
                    '${assessment.warningDistanceKm.toStringAsFixed(1)} km '
                    '(${assessment.warningRoutePercent.toStringAsFixed(1)}%)',
                emphasis: assessment.hasWarningSegments,
              ),
              if (assessment.highestRiskSegment != null)
                _SummaryLine(
                  label: 'Mức cao nhất',
                  value: assessment.highestRiskSegment!.level.label,
                  emphasis:
                      assessment.highestRiskSegment!.level.requiresWarning,
                ),
            ],
            if (summary.routeAnalysis.hasProviderFailures) ...[
              const SizedBox(height: 6),
              Text(
                'Một số nguồn dữ liệu không phản hồi: '
                '${summary.routeAnalysis.failedProviderIds.join(', ')}.',
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              summary.interpretationNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (assessment != null) ...[
              const SizedBox(height: 10),
              Text(
                'Chú giải tuyến',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _ConnectivityRiskLegendItem(
                    color: _connectivityRiskColor(ConnectivityRiskLevel.low),
                    label: 'Thấp',
                  ),
                  _ConnectivityRiskLegendItem(
                    color: _connectivityRiskColor(
                      ConnectivityRiskLevel.moderate,
                    ),
                    label: 'Trung bình',
                  ),
                  _ConnectivityRiskLegendItem(
                    color: _connectivityRiskColor(ConnectivityRiskLevel.high),
                    label: 'Cao',
                  ),
                  _ConnectivityRiskLegendItem(
                    color: _connectivityRiskColor(
                      ConnectivityRiskLevel.critical,
                    ),
                    label: 'Rất cao',
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<AlongRoutePlace> _offlinePoiCandidates() {
    final values = <AlongRoutePlace>[
      ..._alongRoutePlaces,
      ...?_smartFuelPlan?.recommendations.map(
        (recommendation) => recommendation.place,
      ),
      ...?_smartFoodPlan?.recommendations.map(
        (recommendation) => recommendation.place,
      ),
      ...?_smartRestPlan?.recommendations.map(
        (recommendation) => recommendation.place,
      ),
    ];

    final deduplicated = <String, AlongRoutePlace>{};

    for (final place in values) {
      final key = '${place.source}:${place.sourceId}';
      final existing = deduplicated[key];

      if (existing == null) {
        deduplicated[key] = place;
        continue;
      }

      final existingDistance =
          existing.distanceFromRouteMeters ?? double.infinity;
      final candidateDistance =
          place.distanceFromRouteMeters ?? double.infinity;

      if (candidateDistance < existingDistance) {
        deduplicated[key] = place;
      }
    }

    return List<AlongRoutePlace>.unmodifiable(deduplicated.values);
  }

  Future<void> _saveOfflinePackage(Trip trip) async {
    final route = _route;
    final routePoints = _routePoints;

    if (route == null || routePoints == null) {
      return;
    }

    setState(() {
      _isSavingOfflinePackage = true;
      _offlinePackageError = null;
    });

    try {
      final startName =
          (trip.startAddress?.trim().isNotEmpty == true
              ? trip.startAddress
              : trip.startName) ??
          'Điểm bắt đầu';

      final destinationName =
          (trip.destinationAddress?.trim().isNotEmpty == true
              ? trip.destinationAddress
              : trip.destinationName) ??
          'Điểm đến';

      final poiCandidates = _offlinePoiCandidates();
      final connectivitySummary = _connectivityRiskSummary;

      final snapshot = await ref
          .read(offlineTripPackageServiceProvider)
          .savePackage(
            tripId: widget.tripId,
            startName: startName,
            destinationName: destinationName,
            startLatitude: routePoints.startLatitude,
            startLongitude: routePoints.startLongitude,
            destinationLatitude: routePoints.destinationLatitude,
            destinationLongitude: routePoints.destinationLongitude,
            routeDistanceMeters: route.distanceMeters,
            routeDurationSeconds: route.durationSeconds,
            routePoints: route.points,
            vehicleId: trip.vehicleId,
            plannedStartAt: trip.plannedStartAt,
            budgetTotal: trip.budgetTotal,
            pois: poiCandidates,
            connectivityAssessment: connectivitySummary?.assessment,
            connectivityProxyOnly: connectivitySummary?.proxyOnly ?? true,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingOfflinePackage = false;
        _offlinePackageSnapshot = snapshot;
        _hasOfflinePackage = true;
        _offlinePackageNeedsRefresh = false;
        _offlinePackageSavedAt = snapshot.savedAt;
        _offlinePackagePoiCount = snapshot.pois.length;
        _offlinePackageHasConnectivity = snapshot.connectivity != null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu dữ liệu chuyến đi để sử dụng offline.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingOfflinePackage = false;
        _offlinePackageError = 'Không thể lưu chuyến đi offline.\\n$error';
      });
    }
  }

  Future<void> _removeOfflinePackage() async {
    setState(() {
      _isSavingOfflinePackage = true;
      _offlinePackageError = null;
    });

    try {
      await ref
          .read(offlineTripPackageServiceProvider)
          .removePackage(widget.tripId);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingOfflinePackage = false;
        _offlinePackageSnapshot = null;
        _hasOfflinePackage = false;
        _offlinePackageNeedsRefresh = false;
        _offlinePackageSavedAt = null;
        _offlinePackagePoiCount = 0;
        _offlinePackageHasConnectivity = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa dữ liệu offline của chuyến đi.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingOfflinePackage = false;
        _offlinePackageError = 'Không thể xóa dữ liệu offline.\\n$error';
      });
    }
  }

  OfflineReadinessScoringResult _offlineReadinessResult() {
    return const OfflineReadinessEvaluator().evaluate(
      snapshot: _offlinePackageSnapshot,
      packageNeedsRefresh: _offlinePackageNeedsRefresh,
    );
  }

  Color _offlineReadinessColor(OfflineReadinessLevel level) {
    switch (level) {
      case OfflineReadinessLevel.unknown:
        return Colors.blueGrey;
      case OfflineReadinessLevel.notReady:
        return Colors.red.shade700;
      case OfflineReadinessLevel.needsAttention:
        return Colors.orange.shade800;
      case OfflineReadinessLevel.ready:
        return Colors.green.shade700;
    }
  }

  IconData _offlineReadinessStatusIcon(OfflineReadinessItemStatus status) {
    switch (status) {
      case OfflineReadinessItemStatus.missing:
        return Icons.cancel_outlined;
      case OfflineReadinessItemStatus.stale:
        return Icons.update_outlined;
      case OfflineReadinessItemStatus.ready:
        return Icons.check_circle_outline;
      case OfflineReadinessItemStatus.notApplicable:
        return Icons.remove_circle_outline;
    }
  }

  Color _offlineReadinessStatusColor(
    BuildContext context,
    OfflineReadinessItemStatus status,
  ) {
    switch (status) {
      case OfflineReadinessItemStatus.missing:
        return Theme.of(context).colorScheme.error;
      case OfflineReadinessItemStatus.stale:
        return Colors.orange.shade800;
      case OfflineReadinessItemStatus.ready:
        return Colors.green.shade700;
      case OfflineReadinessItemStatus.notApplicable:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _offlineReadinessStatusLabel(OfflineReadinessItem item) {
    if (item.status == OfflineReadinessItemStatus.notApplicable) {
      return 'Chưa hỗ trợ';
    }

    return item.status.label;
  }

  Widget _buildOfflineReadinessSection(BuildContext context) {
    final result = _offlineReadinessResult();
    final assessment = result.assessment;
    final colorScheme = Theme.of(context).colorScheme;
    final levelColor = _offlineReadinessColor(assessment.level);

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
                assessment.isReady
                    ? Icons.offline_pin_outlined
                    : Icons.offline_bolt_outlined,
                size: 22,
                color: levelColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sẵn sàng sử dụng offline',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${assessment.scorePercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: levelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: assessment.score,
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                assessment.isReady ? Icons.check_circle : Icons.info_outline,
                size: 18,
                color: levelColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  assessment.level.label,
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!_hasOfflinePackage) ...[
            const SizedBox(height: 6),
            Text(
              'Hãy lưu chuyến đi offline trước để PhuotThu có dữ liệu '
              'cục bộ cho tuyến này.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (_offlinePackageNeedsRefresh) ...[
            const SizedBox(height: 6),
            Text(
              'Gói offline đã cũ so với dữ liệu đang hiển thị. '
              'Hãy cập nhật lại trước khi khởi hành.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
            ),
          ],
          if (assessment.hasConnectivityRiskContext) ...[
            const SizedBox(height: 6),
            Text(
              'Đoạn HIGH/CRITICAL: '
              '${assessment.connectivityWarningRoutePercent!.toStringAsFixed(1)}% tuyến.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (result.hasConnectivityEscalation) ...[
            const SizedBox(height: 6),
            Text(
              'Nguy cơ kết nối làm tăng mức ưu tiên của một số hạng mục '
              'chuẩn bị offline.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          ...assessment.items.map(
            (item) => _OfflineReadinessItemTile(
              item: item,
              icon: _offlineReadinessStatusIcon(item.status),
              statusColor: _offlineReadinessStatusColor(context, item.status),
              statusLabel: _offlineReadinessStatusLabel(item),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Điểm readiness chỉ phản ánh dữ liệu mà phiên bản hiện tại '
            'có thể lưu. Tile bản đồ nền và gói thông tin khẩn cấp chưa '
            'được tính là đã hỗ trợ.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildOfflinePackageSection(BuildContext context, Trip? trip) {
    final colorScheme = Theme.of(context).colorScheme;

    final statusText = !_hasOfflinePackage
        ? 'Chưa lưu'
        : _offlinePackageNeedsRefresh
        ? 'Cần cập nhật'
        : 'Đã lưu';

    final statusColor = !_hasOfflinePackage
        ? colorScheme.onSurfaceVariant
        : _offlinePackageNeedsRefresh
        ? Colors.orange.shade800
        : Colors.green.shade700;

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
                _hasOfflinePackage
                    ? Icons.check_circle_outline
                    : Icons.save_alt,
                size: 22,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dữ liệu chuyến đi offline',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Lưu thông tin chuyến đi, hình học tuyến, POI đã tải và '
            'kết quả nguy cơ kết nối hiện có trên thiết bị.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Giai đoạn này chưa lưu tile nền OpenStreetMap; bản đồ offline '
            'hoàn chỉnh sẽ được bổ sung ở bước cache bản đồ.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_hasOfflinePackage) ...[
            const SizedBox(height: 10),
            if (_offlinePackageSavedAt != null)
              _SummaryLine(
                label: 'Lưu gần nhất',
                value: _formatOfflineSavedAt(_offlinePackageSavedAt!),
              ),
            _SummaryLine(
              label: 'POI đã lưu',
              value: '$_offlinePackagePoiCount điểm',
            ),
            _SummaryLine(
              label: 'Nguy cơ kết nối',
              value: _offlinePackageHasConnectivity
                  ? 'Đã lưu kết quả'
                  : 'Chưa có trong gói',
            ),
            if (_offlinePackageNeedsRefresh) ...[
              const SizedBox(height: 6),
              Text(
                'Dữ liệu route/POI/nguy cơ kết nối trên màn hình đã thay '
                'đổi sau lần lưu gần nhất. Nên cập nhật lại gói offline.',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
              ),
            ],
          ],
          if (_offlinePackageError != null) ...[
            const SizedBox(height: 8),
            Text(
              _offlinePackageError!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSavingOfflinePackage || trip == null
                  ? null
                  : () => _saveOfflinePackage(trip),
              icon: _isSavingOfflinePackage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt),
              label: Text(
                _isSavingOfflinePackage
                    ? 'Đang lưu...'
                    : _hasOfflinePackage
                    ? 'Cập nhật dữ liệu offline'
                    : 'Lưu chuyến đi offline',
              ),
            ),
          ),
          if (trip == null) ...[
            const SizedBox(height: 6),
            Text(
              'Đang tải thông tin chuyến đi...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_hasOfflinePackage) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isSavingOfflinePackage
                    ? null
                    : _removeOfflinePackage,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Xóa dữ liệu offline'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _syncReadinessRouteFingerprint(RouteResult route) async {
    final snapshot = _tripReadinessChecklist;

    if (snapshot == null) {
      return;
    }

    final previousFingerprint = snapshot.routeFingerprint;

    if (previousFingerprint == null || previousFingerprint.trim().isEmpty) {
      return;
    }

    final currentFingerprint = _buildRouteFingerprint(route);

    if (previousFingerprint == currentFingerprint) {
      return;
    }

    try {
      final updated = await ref
          .read(tripReadinessChecklistServiceProvider)
          .saveRouteWeather(
            tripId: widget.tripId,
            confirmations: RouteWeatherReadinessConfirmations(
              routeReviewed: null,
              weatherReviewed: snapshot.routeWeather.weatherReviewed,
              checkedAt: snapshot.routeWeather.checkedAt,
            ),
            routeFingerprint: currentFingerprint,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _tripReadinessChecklist = updated;
        _tripReadinessError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _tripReadinessError =
            'Tuyến đã thay đổi nhưng không thể cập nhật checklist.\\n$error';
      });
    }
  }

  String _buildRouteFingerprint(RouteResult route) {
    final points = route.points;

    if (points.isEmpty) {
      return '${route.distanceMeters}:${route.durationSeconds}:0';
    }

    final indexes = <int>{
      0,
      points.length ~/ 4,
      points.length ~/ 2,
      (points.length * 3) ~/ 4,
      points.length - 1,
    }.toList(growable: false)..sort();

    final coordinatePart = indexes
        .map((index) {
          final point = points[index];

          return '${point.latitude.toStringAsFixed(5)},'
              '${point.longitude.toStringAsFixed(5)}';
        })
        .join('|');

    return '${route.distanceMeters}:${route.durationSeconds}:'
        '${points.length}:$coordinatePart';
  }

  ConnectivityRiskAssessment? _effectiveReadinessConnectivityAssessment() {
    final current = _connectivityRiskSummary?.assessment;

    if (current != null && current.hasRiskData) {
      return current;
    }

    if (_offlinePackageNeedsRefresh) {
      return null;
    }

    final package = _offlinePackageSnapshot;
    final cached = package?.connectivity;

    if (package == null || cached == null || cached.segments.isEmpty) {
      return null;
    }

    final totalRouteMeters =
        (_route?.distanceMeters ?? package.route.distanceMeters).toDouble();

    if (totalRouteMeters <= 0) {
      return null;
    }

    final segments = cached.segments
        .map((segment) {
          final start = segment.startDistanceMeters
              .clamp(0.0, totalRouteMeters)
              .toDouble();

          final end = segment.endDistanceMeters
              .clamp(start, totalRouteMeters)
              .toDouble();

          return ConnectivityRiskSegment(
            startDistanceMeters: start,
            endDistanceMeters: end,
            startProgressRatio: (start / totalRouteMeters)
                .clamp(0.0, 1.0)
                .toDouble(),
            endProgressRatio: (end / totalRouteMeters)
                .clamp(0.0, 1.0)
                .toDouble(),
            averageRiskScore: segment.averageRiskScore
                .clamp(0.0, 1.0)
                .toDouble(),
            maxRiskScore: segment.maxRiskScore.clamp(0.0, 1.0).toDouble(),
            level: _connectivityRiskLevelFromKey(segment.levelKey),
          );
        })
        .toList(growable: false);

    return ConnectivityRiskAssessment(
      totalRouteMeters: totalRouteMeters,
      overallRiskScore: cached.overallRiskScore.clamp(0.0, 1.0).toDouble(),
      overallLevel: _connectivityRiskLevelFromKey(cached.overallLevelKey),
      segments: List<ConnectivityRiskSegment>.unmodifiable(segments),
      provider: 'offline_cache',
      generatedAt: cached.generatedAt,
    );
  }

  ConnectivityRiskLevel _connectivityRiskLevelFromKey(String key) {
    for (final level in ConnectivityRiskLevel.values) {
      if (level.key == key) {
        return level;
      }
    }

    return ConnectivityRiskLevel.unknown;
  }

  Map<TripReadinessItemType, bool?> _tripReadinessConfirmationValues(
    TripReadinessChecklistSnapshot snapshot,
  ) {
    return {
      TripReadinessItemType.vehicleFuelOrEnergy:
          snapshot.vehicle.fuelOrEnergyReady,
      TripReadinessItemType.vehicleMechanicalCondition:
          snapshot.vehicle.mechanicalConditionOk,
      TripReadinessItemType.vehicleTires: snapshot.vehicle.tiresOk,
      TripReadinessItemType.vehicleDocuments:
          snapshot.vehicle.documentsAvailable,
      TripReadinessItemType.personalProtectiveGear:
          snapshot.personal.protectiveGearReady,
      TripReadinessItemType.personalEssentials:
          snapshot.personal.personalEssentialsReady,
      TripReadinessItemType.routeReviewed: snapshot.routeWeather.routeReviewed,
      TripReadinessItemType.weatherReviewed:
          snapshot.routeWeather.weatherReviewed,
      TripReadinessItemType.emergencyContacts:
          snapshot.emergency.emergencyContactsReady,
      TripReadinessItemType.sosPrepared: snapshot.emergency.sosPlanReviewed,
      TripReadinessItemType.firstAidKit: snapshot.emergency.firstAidKitReady,
    };
  }

  Future<void> _updateTripReadinessConfirmation(
    TripReadinessItemType type,
    bool? value,
  ) async {
    final current = _tripReadinessChecklist;

    if (current == null || _isSavingTripReadiness) {
      return;
    }

    setState(() {
      _isSavingTripReadiness = true;
      _tripReadinessError = null;
    });

    try {
      final service = ref.read(tripReadinessChecklistServiceProvider);
      final checkedAt = DateTime.now().toUtc();

      late TripReadinessChecklistSnapshot updated;

      switch (type) {
        case TripReadinessItemType.vehicleFuelOrEnergy:
        case TripReadinessItemType.vehicleMechanicalCondition:
        case TripReadinessItemType.vehicleTires:
        case TripReadinessItemType.vehicleDocuments:
          final vehicle = current.vehicle;

          updated = await service.saveVehicle(
            tripId: widget.tripId,
            confirmations: VehicleReadinessConfirmations(
              fuelOrEnergyReady:
                  type == TripReadinessItemType.vehicleFuelOrEnergy
                  ? value
                  : vehicle.fuelOrEnergyReady,
              mechanicalConditionOk:
                  type == TripReadinessItemType.vehicleMechanicalCondition
                  ? value
                  : vehicle.mechanicalConditionOk,
              tiresOk: type == TripReadinessItemType.vehicleTires
                  ? value
                  : vehicle.tiresOk,
              documentsAvailable: type == TripReadinessItemType.vehicleDocuments
                  ? value
                  : vehicle.documentsAvailable,
              checkedAt: checkedAt,
            ),
          );
          break;

        case TripReadinessItemType.personalProtectiveGear:
        case TripReadinessItemType.personalEssentials:
          final personal = current.personal;

          updated = await service.savePersonal(
            tripId: widget.tripId,
            confirmations: PersonalReadinessConfirmations(
              protectiveGearReady:
                  type == TripReadinessItemType.personalProtectiveGear
                  ? value
                  : personal.protectiveGearReady,
              personalEssentialsReady:
                  type == TripReadinessItemType.personalEssentials
                  ? value
                  : personal.personalEssentialsReady,
              checkedAt: checkedAt,
            ),
          );
          break;

        case TripReadinessItemType.routeReviewed:
        case TripReadinessItemType.weatherReviewed:
          final routeWeather = current.routeWeather;
          final route = _route;

          updated = await service.saveRouteWeather(
            tripId: widget.tripId,
            confirmations: RouteWeatherReadinessConfirmations(
              routeReviewed: type == TripReadinessItemType.routeReviewed
                  ? value
                  : routeWeather.routeReviewed,
              weatherReviewed: type == TripReadinessItemType.weatherReviewed
                  ? value
                  : routeWeather.weatherReviewed,
              checkedAt: checkedAt,
            ),
            routeFingerprint: route == null
                ? null
                : _buildRouteFingerprint(route),
          );
          break;

        case TripReadinessItemType.emergencyContacts:
        case TripReadinessItemType.sosPrepared:
        case TripReadinessItemType.firstAidKit:
          final emergency = current.emergency;

          updated = await service.saveEmergency(
            tripId: widget.tripId,
            confirmations: EmergencyReadinessConfirmations(
              emergencyContactsReady:
                  type == TripReadinessItemType.emergencyContacts
                  ? value
                  : emergency.emergencyContactsReady,
              sosPlanReviewed: type == TripReadinessItemType.sosPrepared
                  ? value
                  : emergency.sosPlanReviewed,
              firstAidKitReady: type == TripReadinessItemType.firstAidKit
                  ? value
                  : emergency.firstAidKitReady,
              checkedAt: checkedAt,
            ),
          );
          break;

        case TripReadinessItemType.offlinePackage:
        case TripReadinessItemType.connectivityReviewed:
          if (mounted) {
            setState(() {
              _isSavingTripReadiness = false;
            });
          }
          return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _tripReadinessChecklist = updated;
        _isSavingTripReadiness = false;
        _tripReadinessError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingTripReadiness = false;
        _tripReadinessError =
            'Không thể lưu checklist chuẩn bị chuyến đi.\\n$error';
      });
    }
  }

  Widget _buildTripReadinessSection(BuildContext context, Trip? trip) {
    if (_isLoadingTripReadiness) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(child: Text('Đang tải checklist chuẩn bị chuyến đi...')),
          ],
        ),
      );
    }

    final checklist = _tripReadinessChecklist;

    if (checklist == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          _tripReadinessError ?? 'Không thể tải checklist chuẩn bị chuyến đi.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    final composition = const TripReadinessComposer().compose(
      offlineAssessment: _offlineReadinessResult().assessment,
      checklist: checklist,
      vehicle: trip?.vehicleId == null ? null : _readinessVehicle,
      hasRoute: _route != null && _route!.points.length >= 2,
      connectivityAssessment: _effectiveReadinessConnectivityAssessment(),
      assessedAt: DateTime.now(),
    );

    return TripReadinessPanel(
      composition: composition,
      confirmationValues: _tripReadinessConfirmationValues(checklist),
      onChanged: _updateTripReadinessConfirmation,
      vehicleAvailable: trip?.vehicleId != null && _readinessVehicle != null,
      routeAvailable: _route != null && _route!.points.length >= 2,
      isSaving: _isSavingTripReadiness,
      errorMessage: _tripReadinessError,
    );
  }

  String _formatOfflineSavedAt(DateTime value) {
    final local = value.toLocal();

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
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

    final currentTrip = tripAsync.maybeWhen<Trip?>(
      data: (trip) => trip,
      orElse: () => null,
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

    final smartFoodRecommendations =
        _smartFoodPlan?.recommendations ??
        const <SmartRestStopRecommendation>[];

    final recommendedFoodSourceIds = smartFoodRecommendations
        .map((recommendation) => recommendation.place.sourceId)
        .toSet();

    final smartRestRecommendations =
        _smartRestPlan?.recommendations ??
        const <SmartRestStopRecommendation>[];

    final recommendedRestSourceIds = smartRestRecommendations
        .map((recommendation) => recommendation.place.sourceId)
        .toSet();

    final alongRouteMarkers = _alongRoutePlaces
        .where(
          (place) =>
              !recommendedFuelSourceIds.contains(place.sourceId) &&
              !recommendedFoodSourceIds.contains(place.sourceId) &&
              !recommendedRestSourceIds.contains(place.sourceId),
        )
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
                icon: _alongRoutePlaceIcon(place),
                color: _alongRoutePlaceColor(place),
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

    final smartFoodMarkers = smartFoodRecommendations.map((recommendation) {
      final place = recommendation.place;
      final isDrink = _isDrinkPlace(place);

      return Marker(
        point: LatLng(place.latitude, place.longitude),
        width: 54,
        height: 54,
        child: GestureDetector(
          onTap: () {
            _focusSmartFoodStop(recommendation);
            _showSmartFoodStop(context, recommendation);
          },
          child: _NumberedRecommendationMarker(
            stopNumber: recommendation.target.stopNumber,
            color: isDrink ? Colors.teal.shade700 : Colors.deepOrange,
            icon: isDrink ? Icons.local_cafe : Icons.restaurant,
          ),
        ),
      );
    });

    final smartRestMarkers = smartRestRecommendations.map((recommendation) {
      final place = recommendation.place;

      return Marker(
        point: LatLng(place.latitude, place.longitude),
        width: 54,
        height: 54,
        child: GestureDetector(
          onTap: () {
            _focusSmartRestStop(recommendation);
            _showSmartRestStop(context, recommendation);
          },
          child: _NumberedRecommendationMarker(
            stopNumber: recommendation.target.stopNumber,
            color: Colors.indigo,
            icon: Icons.hotel,
          ),
        ),
      );
    });

    final hasFuelMarkers =
        _alongRoutePlaces.any(
          (place) => place.type == AlongRoutePlaceType.fuel,
        ) ||
        smartFuelRecommendations.isNotEmpty;

    final hasRestMarkers =
        _alongRoutePlaces.any(
          (place) => place.type == AlongRoutePlaceType.restArea,
        ) ||
        smartRestRecommendations.isNotEmpty;

    final hasEatMarkers =
        _alongRoutePlaces.any(
          (place) =>
              place.type == AlongRoutePlaceType.food && !_isDrinkPlace(place),
        ) ||
        smartFoodRecommendations.any(
          (recommendation) => !_isDrinkPlace(recommendation.place),
        );

    final hasDrinkMarkers =
        _alongRoutePlaces.any(
          (place) =>
              place.type == AlongRoutePlaceType.food && _isDrinkPlace(place),
        ) ||
        smartFoodRecommendations.any(
          (recommendation) => _isDrinkPlace(recommendation.place),
        );

    final hasRepairMarkers = _alongRoutePlaces.any(
      (place) => place.type == AlongRoutePlaceType.repair,
    );

    final hasMedicalMarkers = _alongRoutePlaces.any(
      (place) => place.type == AlongRoutePlaceType.medical,
    );

    final connectivityAssessment = _connectivityRiskSummary?.assessment;

    final connectivityRiskMapSegments = connectivityAssessment == null
        ? const <ConnectivityRiskMapSegment>[]
        : const ConnectivityRiskMapSegmentBuilder().build(
            routePoints: route.points,
            assessment: connectivityAssessment,
          );

    final connectivityRiskPolylines = connectivityRiskMapSegments
        .map(
          (segment) => Polyline(
            points: segment.points
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList(growable: false),
            strokeWidth: 7,
            color: _connectivityRiskColor(segment.level),
          ),
        )
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
                ...connectivityRiskPolylines,
              ],
            ),

            MarkerLayer(
              markers: [
                ...alongRouteMarkers,
                ...smartFuelMarkers,
                ...smartFoodMarkers,
                ...smartRestMarkers,

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

                    _buildConnectivityRiskSection(context),

                    const Divider(height: 24),

                    _buildOfflinePackageSection(context, currentTrip),

                    const Divider(height: 24),

                    _buildOfflineReadinessSection(context),

                    const Divider(height: 24),

                    _buildTripReadinessSection(context, currentTrip),

                    const Divider(height: 24),

                    _buildSmartFuelSection(context),

                    const Divider(height: 24),

                    _buildSmartFoodSection(context),

                    const Divider(height: 24),

                    _buildSmartRestSection(context),

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
                          label: Text(_alongRouteFilterLabel(type)),
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

                      if (hasFuelMarkers ||
                          hasRestMarkers ||
                          hasEatMarkers ||
                          hasDrinkMarkers ||
                          hasRepairMarkers ||
                          hasMedicalMarkers) ...[
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
                            if (hasFuelMarkers)
                              _AlongRouteLegendItem(
                                icon: Icons.local_gas_station,
                                color: Colors.green.shade700,
                                label: 'Cây xăng',
                              ),
                            if (hasEatMarkers)
                              const _AlongRouteLegendItem(
                                icon: Icons.restaurant,
                                color: Colors.deepOrange,
                                label: 'Ăn',
                              ),
                            if (hasDrinkMarkers)
                              _AlongRouteLegendItem(
                                icon: Icons.local_cafe,
                                color: Colors.teal.shade700,
                                label: 'Uống',
                              ),
                            if (hasRestMarkers)
                              const _AlongRouteLegendItem(
                                icon: Icons.hotel,
                                color: Colors.indigo,
                                label: 'Nghỉ / lưu trú',
                              ),
                            if (hasRepairMarkers)
                              const _AlongRouteLegendItem(
                                icon: Icons.build_outlined,
                                color: Colors.blueGrey,
                                label: 'Sửa chữa',
                              ),
                            if (hasMedicalMarkers)
                              const _AlongRouteLegendItem(
                                icon: Icons.local_hospital_outlined,
                                color: Colors.red,
                                label: 'Y tế',
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

class _OfflineReadinessItemTile extends StatelessWidget {
  const _OfflineReadinessItemTile({
    required this.item,
    required this.icon,
    required this.statusColor,
    required this.statusLabel,
  });

  final OfflineReadinessItem item;
  final IconData icon;
  final Color statusColor;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.displayTitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (item.isRequired) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Bắt buộc',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.description != null &&
                    item.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusLabel,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectivityRiskLegendItem extends StatelessWidget {
  const _ConnectivityRiskLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
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

class _NumberedRecommendationMarker extends StatelessWidget {
  const _NumberedRecommendationMarker({
    required this.stopNumber,
    required this.color,
    required this.icon,
  });

  final int stopNumber;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          elevation: 8,
          color: color,
          shape: const CircleBorder(
            side: BorderSide(color: Colors.white, width: 3),
          ),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, size: 24, color: Colors.white),
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
              border: Border.all(color: color, width: 2),
            ),
            child: Text(
              '$stopNumber',
              style: TextStyle(
                color: color,
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

class _SmartRestStatus extends StatelessWidget {
  const _SmartRestStatus({
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

class _SmartFoodStopTile extends StatelessWidget {
  const _SmartFoodStopTile({
    required this.recommendation,
    required this.isDrink,
    required this.onTap,
  });

  final SmartRestStopRecommendation recommendation;
  final bool isDrink;
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
    final color = isDrink ? Colors.teal.shade700 : Colors.deepOrange;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          child: Icon(isDrink ? Icons.local_cafe : Icons.restaurant),
        ),
        title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${isDrink ? 'Uống' : 'Ăn'} · '
          'Km ${recommendation.routePositionKm.toStringAsFixed(1)} · '
          'lệch mốc ${_formatMeters(recommendation.candidate.distanceFromTargetMeters)} · '
          'cách tuyến ${_formatMeters(recommendation.routeDeviationMeters)} · '
          '${recommendation.score.toStringAsFixed(0)}/100',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.my_location_outlined),
        onTap: onTap,
      ),
    );
  }
}

class _SmartRestStopTile extends StatelessWidget {
  const _SmartRestStopTile({required this.recommendation, required this.onTap});

  final SmartRestStopRecommendation recommendation;
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
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          child: Text(
            '${recommendation.target.stopNumber}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Km ${recommendation.routePositionKm.toStringAsFixed(1)} · '
          'lệch mốc ${_formatMeters(recommendation.candidate.distanceFromTargetMeters)} · '
          'cách tuyến ${_formatMeters(recommendation.routeDeviationMeters)} · '
          '${recommendation.score.toStringAsFixed(0)}/100',
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
