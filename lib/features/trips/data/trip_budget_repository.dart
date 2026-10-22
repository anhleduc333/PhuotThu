import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/trip_budget_item.dart';

final tripBudgetRepositoryProvider = Provider<TripBudgetRepository>((ref) {
  return TripBudgetRepository(ref.watch(supabaseClientProvider));
});

class TripBudgetRepository {
  TripBudgetRepository(this._client);

  final SupabaseClient _client;

  Future<List<TripBudgetItem>> getItems(String tripId) async {
    final data = await _client
        .from('trip_budget_items')
        .select()
        .eq('trip_id', tripId)
        .order('category');

    return data
        .map((item) => TripBudgetItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> upsertItem({
    required String tripId,
    required String category,
    required double amountVnd,
    required String source,
    String? note,
    bool isEnabled = true,
  }) async {
    await _client.from('trip_budget_items').upsert({
      'trip_id': tripId,
      'category': category,
      'amount_vnd': amountVnd,
      'source': source,
      'note': note,
      'is_enabled': isEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'trip_id,category');
  }

  Future<void> upsertFuelCost({
    required String tripId,
    required double amountVnd,
  }) async {
    await upsertItem(
      tripId: tripId,
      category: 'fuel',
      amountVnd: amountVnd,
      source: 'system',
      note: 'Tự động tính từ tuyến đường và phương tiện',
      isEnabled: true,
    );
  }

  Future<void> removeFuelCost(String tripId) async {
    await deleteItem(tripId: tripId, category: 'fuel');
  }

  Future<void> deleteItem({
    required String tripId,
    required String category,
  }) async {
    await _client
        .from('trip_budget_items')
        .delete()
        .eq('trip_id', tripId)
        .eq('category', category);
  }
}
