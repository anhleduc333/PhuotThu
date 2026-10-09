import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/fuel_price.dart';

final fuelPriceRepositoryProvider = Provider<FuelPriceRepository>((ref) {
  return FuelPriceRepository(ref.watch(supabaseClientProvider));
});

class FuelPriceRepository {
  FuelPriceRepository(this._client);

  final SupabaseClient _client;

  Future<FuelPrice?> getLatestPrice(String fuelType) async {
    if (fuelType == 'electric') {
      return null;
    }

    final data = await _client
        .from('fuel_prices')
        .select()
        .eq('fuel_type', fuelType)
        .lte('effective_at', DateTime.now().toUtc().toIso8601String())
        .order('effective_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return FuelPrice.fromMap(Map<String, dynamic>.from(data));
  }
}
