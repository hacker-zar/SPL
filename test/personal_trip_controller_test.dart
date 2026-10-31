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
import 'package:rentabilidad_flete/features/trip_data/domain/models/trip_inputs.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/domain/models/vehicle_profile.dart';

void main() {
  test('personal trip calculates costs without a freight profile or income',
      () async {
    final controller = _controller()..startTrip(TripPurpose.personal);
    await controller.savePersonalVehicle(const VehicleProfile(
      consumptionLitersPer100Km: 10,
      maintenanceCostPerKm: 1,
      capacityTons: 0,
      dailyFixedCost: 9000,
    ));
    controller.route = _route;
    controller.setFuelPrice(100);
    controller.setTolls(20);
    controller.setAllowances(30);

    expect(controller.vehicleProfile, isNull);
    expect(controller.analysis, isNotNull);
    expect(controller.analysis!.grossIncome, 0);
    expect(controller.analysis!.timeCost, 0);
    expect(controller.analysis!.totalCosts, 1150);
    expect(controller.costPerPerson, 1150);
    controller.setTravelers(4);
    expect(controller.travelers, 4);
    expect(controller.costPerPerson, 287.5);
    controller.setTravelers(0);
    expect(controller.travelers, 1);
    expect(controller.costPerPerson, 1150);
    controller.dispose();
  });

  test('saved personal trip round trips its purpose and zero profit fields',
      () async {
    final tripRepository = MemoryTripRepository();
    final controller = _controller(tripRepository: tripRepository)
      ..startTrip(TripPurpose.personal);
    await controller.savePersonalVehicle(const VehicleProfile(
      consumptionLitersPer100Km: 10,
      maintenanceCostPerKm: 1,
      capacityTons: 0,
    ));
    controller.route = _route;
    controller.setFuelPrice(100);
    controller.setTolls(20);
    controller.setAllowances(30);
    final record = controller.createCurrentTripRecord()!;
    await tripRepository.save(record);
    final restored = TripRecord.fromMap(
      record.id,
      (await tripRepository.watchRecent().first).single.toMap(userId: 'user'),
    );

    expect(restored.trip.purpose, TripPurpose.personal);
    expect(restored.totalCosts, 1150);
    expect(restored.income, 0);
    expect(restored.netProfit, 0);
    expect(restored.marginPercent, 0);
    controller.dispose();
  });
}

const _route = RouteInfo(
  originName: 'A',
  destinationName: 'B',
  origin: LatLngValue(latitude: 1, longitude: 1),
  destination: LatLngValue(latitude: 2, longitude: 2),
  distanceKm: 100,
  durationMinutes: 60,
);

TripQuoteController _controller({MemoryTripRepository? tripRepository}) =>
    TripQuoteController(
      calculator: const ProfitabilityCalculator(
        marginThresholds: ProfitabilityThresholds(),
      ),
      routeService: ManualRouteService(),
      geocodingService: NominatimGeocodingService(),
      tollEstimator: const TollEstimator(ratePerKm: 0),
      vehicleProfileRepository: MemoryVehicleProfileRepository(),
      tripRepository: tripRepository ?? MemoryTripRepository(),
      initialCosts: const CostInputs(),
    );
