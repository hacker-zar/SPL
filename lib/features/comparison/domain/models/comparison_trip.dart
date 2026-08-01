import '../../../history/domain/models/trip_record.dart';
import '../../../route_planning/domain/models/route_info.dart';
import '../../../analysis/domain/models/trip_analysis.dart';

class ComparisonTrip {
  const ComparisonTrip({
    required this.label,
    required this.record,
    required this.analysis,
  });

  final String label;
  final TripRecord record;
  final TripAnalysis analysis;

  double get distanceKm => effectiveRoute.distanceKm;

  double get durationHours => effectiveRoute.durationMinutes / 60;

  double get incomePerKm => analysis.incomePerKm;

  double get costPerKm => analysis.costPerKm;

  double get profitPerKm => analysis.profitPerKm;

  double get profitPerHour => _safeDivide(record.netProfit, durationHours);

  double get roiPercent =>
      _safeDivide(record.netProfit, record.totalCosts) * 100;

  double get fuelLiters =>
      _safeDivide(analysis.fuelCost, record.costs.fuelPricePerLiter);

  double get profitabilityPerLiter => _safeDivide(record.netProfit, fuelLiters);

  RouteInfo get effectiveRoute =>
      record.emptyReturn ? record.route.withEmptyReturn() : record.route;

  double _safeDivide(double value, double divisor) {
    if (divisor == 0) {
      return 0;
    }
    return value / divisor;
  }
}
