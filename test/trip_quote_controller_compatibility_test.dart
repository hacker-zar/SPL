import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/history/data/memory_trip_repository.dart';
import 'package:rentabilidad_flete/features/history/domain/models/trip_record.dart';
import 'package:rentabilidad_flete/features/route_planning/data/manual_route_service.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/domain/models/vehicle_profile.dart';

TripQuoteController _controller() => TripQuoteController(
      calculator: const ProfitabilityCalculator(
          marginThresholds: ProfitabilityThresholds()),
      routeService: ManualRouteService(),
      geocodingService: NominatimGeocodingService(),
      tollEstimator: const TollEstimator(ratePerKm: 0),
      vehicleProfileRepository: MemoryVehicleProfileRepository(),
      tripRepository: MemoryTripRepository(),
      initialCosts: const CostInputs(),
    );

void main() {
  test('manual toll amount survives empty return toggle', () {
    final controller = _controller()
      ..route = const RouteInfo(
        originName: 'A',
        destinationName: 'B',
        origin: LatLngValue(latitude: 1, longitude: 1),
        destination: LatLngValue(latitude: 2, longitude: 2),
        distanceKm: 100,
        durationMinutes: 60,
      );
    controller.setTolls(4567);
    controller.setEmptyReturn(true);
    expect(controller.costs.tolls, 4567);
    controller.dispose();
  });

  test('legacy trip record recalculates with prior analysis values', () {
    final controller = _controller();
    controller.vehicleProfile = const VehicleProfile(
      consumptionLitersPer100Km: 30,
      maintenanceCostPerKm: 100,
      capacityTons: 28,
    );
    final record = TripRecord.fromMap('legacy', {
      'createdAt': '2026-01-01T00:00:00.000',
      'route': const RouteInfo(
        originName: 'A',
        destinationName: 'B',
        origin: LatLngValue(latitude: 1, longitude: 1),
        destination: LatLngValue(latitude: 2, longitude: 2),
        distanceKm: 100,
        durationMinutes: 60,
      ).toMap(),
      'trip': {'pricingMode': 'flatRate', 'flatRate': 100000},
      'costs': {'fuelPricePerLiter': 1000, 'tolls': 5000, 'allowances': 2000},
      'emptyReturn': false,
    });
    final analysis = controller.analysisForRecord(record)!;
    expect(analysis.timeCost, 0);
    expect(analysis.totalCosts, 47000);
    expect(analysis.netProfit, 53000);
    controller.dispose();
  });
}
