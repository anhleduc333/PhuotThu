import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'trip_readiness_checklist_repository.dart';
import 'trip_readiness_checklist_service.dart';

final tripReadinessChecklistRepositoryProvider =
    Provider<TripReadinessChecklistRepository>((ref) {
      return AsyncSharedPreferencesTripReadinessChecklistRepository();
    });

final tripReadinessChecklistServiceProvider =
    Provider<TripReadinessChecklistService>((ref) {
      return TripReadinessChecklistService(
        repository: ref.watch(tripReadinessChecklistRepositoryProvider),
      );
    });
