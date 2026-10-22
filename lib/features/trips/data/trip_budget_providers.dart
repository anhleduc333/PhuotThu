import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trip_budget_item.dart';
import 'trip_budget_repository.dart';

final tripBudgetItemsProvider =
    FutureProvider.family<List<TripBudgetItem>, String>((ref, tripId) async {
      final repository = ref.watch(tripBudgetRepositoryProvider);

      return repository.getItems(tripId);
    });
