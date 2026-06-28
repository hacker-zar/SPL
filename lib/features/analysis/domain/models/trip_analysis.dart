import 'profitability_status.dart';

class TripAnalysis {
  const TripAnalysis({
    required this.grossIncome,
    required this.fuelCost,
    required this.maintenanceCost,
    required this.fixedCosts,
    required this.totalCosts,
    required this.netProfit,
    required this.marginPercent,
    required this.incomePerKm,
    required this.costPerKm,
    required this.profitPerKm,
    required this.breakEvenPrice,
    required this.minimumPricePerTon,
    required this.status,
  });

  final double grossIncome;
  final double fuelCost;
  final double maintenanceCost;
  final double fixedCosts;
  final double totalCosts;
  final double netProfit;
  final double marginPercent;
  final double incomePerKm;
  final double costPerKm;
  final double profitPerKm;
  final double breakEvenPrice;
  final double minimumPricePerTon;
  final ProfitabilityStatus status;
}
