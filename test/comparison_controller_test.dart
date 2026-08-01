import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/analysis/domain/models/profitability_status.dart';
import 'package:rentabilidad_flete/features/analysis/domain/models/trip_analysis.dart';
import 'package:rentabilidad_flete/features/comparison/domain/models/comparison_trip.dart';
import 'package:rentabilidad_flete/features/comparison/presentation/controllers/comparison_controller.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/history/domain/models/trip_record.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';
import 'package:rentabilidad_flete/features/trip_data/domain/models/trip_inputs.dart';

void main() {
  test('recommends the trip with higher profit and labels each snapshot', () {
    final controller = ComparisonController();
    final tripA = _trip(label: '', profit: 200000, margin: 20);
    final tripB = _trip(label: '', profit: 350000, margin: 25);

    controller.add(tripA);
    controller.add(tripB);

    expect(controller.canCompare, isTrue);
    expect(controller.trips[0].label, 'Viaje A');
    expect(controller.trips[1].label, 'Viaje B');
    expect(controller.decision.recommended.label, 'Viaje B');
    expect(controller.decision.absoluteDifference, 150000);
    expect(controller.decision.reasons, contains('mayor ganancia neta'));
    controller.dispose();
  });
}

ComparisonTrip _trip({
  required String label,
  required double profit,
  required double margin,
}) {
  const route = RouteInfo(
    originName: 'Rosario',
    destinationName: 'Córdoba',
    origin: LatLngValue(latitude: -32.9442, longitude: -60.6505),
    destination: LatLngValue(latitude: -31.4201, longitude: -64.1888),
    distanceKm: 400,
    durationMinutes: 360,
  );
  const tripInputs = TripInputs(
    pricingMode: PricingMode.flatRate,
    flatRate: 1000000,
  );
  final analysis = TripAnalysis(
    grossIncome: 1000000,
    fuelCost: 120000,
    maintenanceCost: 40000,
    fixedCosts: 50000,
    totalCosts: 1000000 - profit,
    netProfit: profit,
    marginPercent: margin,
    incomePerKm: 2500,
    costPerKm: (1000000 - profit) / 400,
    profitPerKm: profit / 400,
    breakEvenPrice: 1000000 - profit,
    minimumPricePerTon: 0,
    status: ProfitabilityStatus.profitable,
  );
  return ComparisonTrip(
    label: label,
    record: TripRecord.fromAnalysis(
      id: 'trip-$profit',
      route: route,
      trip: tripInputs,
      costs: const CostInputs(fuelPricePerLiter: 1000, tolls: 30000),
      emptyReturn: false,
      analysis: analysis,
    ),
    analysis: analysis,
  );
}
