import '../../../costs/domain/models/cost_inputs.dart';
import '../../../route_planning/domain/models/route_info.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
import '../../../vehicle_profile/domain/models/vehicle_profile.dart';
import '../models/profitability_status.dart';
import '../models/trip_analysis.dart';

class ProfitabilityThresholds {
  const ProfitabilityThresholds({
    this.lowMarginPercent = 10,
  });

  final double lowMarginPercent;
}

class ProfitabilityCalculator {
  const ProfitabilityCalculator({
    required this.marginThresholds,
  });

  final ProfitabilityThresholds marginThresholds;

  TripAnalysis calculate({
    required RouteInfo route,
    required TripInputs trip,
    required CostInputs costs,
    required VehicleProfile vehicleProfile,
    required bool emptyReturn,
  }) {
    final effectiveRoute = emptyReturn ? route.withEmptyReturn() : route;
    final grossIncome = trip.grossIncome;
    final fuelLiters = effectiveRoute.distanceKm *
        vehicleProfile.consumptionLitersPer100Km /
        100;
    final fuelCost = fuelLiters * costs.fuelPricePerLiter;
    final maintenanceCost =
        effectiveRoute.distanceKm * vehicleProfile.maintenanceCostPerKm;
    final fixedCosts = costs.tolls + costs.allowances;
    final totalCosts = fuelCost + maintenanceCost + fixedCosts;
    final netProfit = grossIncome - totalCosts;
    final marginPercent =
        grossIncome == 0 ? 0.0 : (netProfit / grossIncome) * 100;
    final incomePerKm = _safeDivide(grossIncome, effectiveRoute.distanceKm);
    final costPerKm = _safeDivide(totalCosts, effectiveRoute.distanceKm);
    final profitPerKm = _safeDivide(netProfit, effectiveRoute.distanceKm);
    final minimumPricePerTon = _safeDivide(totalCosts, trip.tons);

    return TripAnalysis(
      grossIncome: grossIncome,
      fuelCost: fuelCost,
      maintenanceCost: maintenanceCost,
      fixedCosts: fixedCosts,
      totalCosts: totalCosts,
      netProfit: netProfit,
      marginPercent: marginPercent,
      incomePerKm: incomePerKm,
      costPerKm: costPerKm,
      profitPerKm: profitPerKm,
      breakEvenPrice: totalCosts,
      minimumPricePerTon: minimumPricePerTon,
      status: _statusFor(netProfit, marginPercent),
    );
  }

  ProfitabilityStatus _statusFor(double netProfit, double marginPercent) {
    if (netProfit < 0) {
      return ProfitabilityStatus.loss;
    }
    if (marginPercent < marginThresholds.lowMarginPercent) {
      return ProfitabilityStatus.low;
    }
    return ProfitabilityStatus.profitable;
  }

  double _safeDivide(double value, double divisor) {
    if (divisor == 0) {
      return 0;
    }
    return value / divisor;
  }
}
