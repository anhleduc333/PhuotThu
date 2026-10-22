class TripBudgetItem {
  const TripBudgetItem({
    required this.id,
    required this.tripId,
    required this.category,
    required this.amountVnd,
    required this.source,
    required this.isEnabled,
    this.note,
  });

  final String id;
  final String tripId;

  final String category;

  final double amountVnd;

  final String source;

  final String? note;

  final bool isEnabled;

  factory TripBudgetItem.fromMap(Map<String, dynamic> map) {
    return TripBudgetItem(
      id: map['id'].toString(),
      tripId: map['trip_id'].toString(),
      category: map['category'].toString(),
      amountVnd: _toDouble(map['amount_vnd']),
      source: map['source']?.toString() ?? 'manual',
      note: map['note']?.toString(),
      isEnabled: map['is_enabled'] as bool? ?? true,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
