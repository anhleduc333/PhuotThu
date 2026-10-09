class TripCostEstimate {
  const TripCostEstimate({
    required this.fuelCost,
    required this.unitPrice,
    this.budget,
  });

  final double fuelCost;

  final double unitPrice;

  final double? budget;

  double? get remainingBudget {
    if (budget == null) {
      return null;
    }

    return budget! - fuelCost;
  }

  bool get exceedsBudget {
    final remaining = remainingBudget;

    if (remaining == null) {
      return false;
    }

    return remaining < 0;
  }

  double? get budgetUsagePercent {
    if (budget == null || budget! <= 0) {
      return null;
    }

    return fuelCost / budget! * 100;
  }
}

class TripCostEstimator {
  const TripCostEstimator();

  TripCostEstimate? calculate({
    required double? estimatedFuelLiters,
    required double? unitPriceVndPerLiter,
    double? budget,
  }) {
    if (estimatedFuelLiters == null || estimatedFuelLiters <= 0) {
      return null;
    }

    if (unitPriceVndPerLiter == null || unitPriceVndPerLiter <= 0) {
      return null;
    }

    final fuelCost = estimatedFuelLiters * unitPriceVndPerLiter;

    return TripCostEstimate(
      fuelCost: fuelCost,
      unitPrice: unitPriceVndPerLiter,
      budget: budget,
    );
  }
}
