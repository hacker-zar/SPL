import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/widgets/offer_costs_step.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/history/data/memory_trip_repository.dart';
import 'package:rentabilidad_flete/features/route_planning/data/manual_route_service.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';
import 'package:rentabilidad_flete/features/trip_data/domain/models/trip_inputs.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';

void main() {
  testWidgets('personal costs hide price and tonnage fields', (tester) async {
    final controller = _controller()..startTrip(TripPurpose.personal);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: OfferCostsStep(controller: controller)),
    ));
    expect(find.text('Precio del viaje'), findsNothing);
    expect(find.text('Toneladas'), findsNothing);
    expect(find.text('Precio por tonelada'), findsNothing);
    expect(find.text('Cantidad de personas que comparten los gastos'),
        findsOneWidget);
    controller.dispose();
  });

  testWidgets('freight retains per ton price fields', (tester) async {
    final controller = _controller()..setPricingMode(PricingMode.perTon);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: OfferCostsStep(controller: controller)),
    ));
    expect(find.text('Toneladas'), findsOneWidget);
    expect(find.text('Precio por tonelada'), findsOneWidget);
    controller.dispose();
  });
}

TripQuoteController _controller() => TripQuoteController(
      calculator: const ProfitabilityCalculator(
        marginThresholds: ProfitabilityThresholds(),
      ),
      routeService: ManualRouteService(),
      geocodingService: NominatimGeocodingService(),
      tollEstimator: const TollEstimator(ratePerKm: 0),
      vehicleProfileRepository: MemoryVehicleProfileRepository(),
      tripRepository: MemoryTripRepository(),
      initialCosts: const CostInputs(),
    );
