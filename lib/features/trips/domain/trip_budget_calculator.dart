import 'trip_budget_item.dart';

class TripBudgetSummary {
  const TripBudgetSummary({
    required this.estimatedTotal,
    required this.budgetTotal,
    required this.remainingBudget,
    required this.usagePercent,
    required this.exceedsBudget,
  });

  final double estimatedTotal;

  final double? budgetTotal;

  final double? remainingBudget;

  final double? usagePercent;

  final bool exceedsBudget;
}

class TripBudgetCalculator {
  const TripBudgetCalculator();

  TripBudgetSummary calculate({
    required List<TripBudgetItem> items,
    required double? budgetTotal,
  }) {
    final estimatedTotal = items
        .where((item) => item.isEnabled)
        .fold<double>(0, (total, item) => total + item.amountVnd);

    double? remainingBudget;
    double? usagePercent;

    if (budgetTotal != null) {
      remainingBudget = budgetTotal - estimatedTotal;

      if (budgetTotal > 0) {
        usagePercent = estimatedTotal / budgetTotal * 100;
      }
    }

    return TripBudgetSummary(
      estimatedTotal: estimatedTotal,
      budgetTotal: budgetTotal,
      remainingBudget: remainingBudget,
      usagePercent: usagePercent,
      exceedsBudget: remainingBudget != null && remainingBudget < 0,
    );
  }
}
