class FuelPrice {
  const FuelPrice({
    required this.id,
    required this.fuelType,
    required this.unitPriceVndPerLiter,
    required this.effectiveAt,
    this.sourceNote,
  });

  final String id;

  final String fuelType;

  final double unitPriceVndPerLiter;

  final String? sourceNote;

  final DateTime effectiveAt;

  factory FuelPrice.fromMap(Map<String, dynamic> map) {
    return FuelPrice(
      id: map['id'].toString(),
      fuelType: map['fuel_type'].toString(),
      unitPriceVndPerLiter: _requiredDouble(map['unit_price_vnd_per_l']),
      sourceNote: map['source_note']?.toString(),
      effectiveAt: DateTime.parse(map['effective_at'].toString()),
    );
  }

  static double _requiredDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    final parsed = double.tryParse(value.toString());

    if (parsed == null) {
      throw const FormatException('Invalid fuel price');
    }

    return parsed;
  }
}
