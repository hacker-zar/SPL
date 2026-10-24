import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/core/utils/money_format.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/screens/trip_quote_screen.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/history/data/memory_trip_repository.dart';
import 'package:rentabilidad_flete/features/route_planning/data/manual_route_service.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';
import 'package:rentabilidad_flete/features/trip_data/domain/models/trip_inputs.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/domain/models/vehicle_profile.dart';

void main() {
  testWidgets('shows total break-even for flat rate', (tester) async {
    final controller = _controller(PricingMode.flatRate);
    expect(controller.analysis, isNotNull);
    await tester.pumpWidget(MaterialApp(
      home: TripResultScreen(controller: controller, onNewSimulation: () {}),
    ));
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(find.text('PRECIO DE EQUILIBRIO'), findsOneWidget);
    expect(find.textContaining('cubrís los costos: no ganás ni perdés.'),
        findsOneWidget);
    expect(find.text('PRECIO MÍNIMO POR TONELADA'), findsNothing);
    controller.dispose();
  });

  testWidgets('shows break-even per ton with its unit', (tester) async {
    final controller = _controller(PricingMode.perTon);
    expect(controller.analysis, isNotNull);
    await tester.pumpWidget(MaterialApp(
      home: TripResultScreen(controller: controller, onNewSimulation: () {}),
    ));
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(find.text('PRECIO MÍNIMO POR TONELADA'), findsOneWidget);
    final analysis = controller.analysis!;
    expect(
      find.text(
        'A ${money(analysis.minimumPricePerTon)} por tonelada cubrís los costos: no ganás ni perdés.',
      ),
      findsOneWidget,
    );
    expect(find.text('PRECIO DE EQUILIBRIO'), findsNothing);
    controller.dispose();
  });
}

TripQuoteController _controller(PricingMode mode) {
  final controller = TripQuoteController(
    calculator: const ProfitabilityCalculator(
      marginThresholds: ProfitabilityThresholds(),
    ),
    routeService: ManualRouteService(),
    geocodingService: NominatimGeocodingService(),
    tollEstimator: const TollEstimator(ratePerKm: 0),
    vehicleProfileRepository: MemoryVehicleProfileRepository(),
    tripRepository: MemoryTripRepository(),
    initialCosts: const CostInputs(fuelPricePerLiter: 1000),
  );
  controller.route = const RouteInfo(
    originName: 'Rosario',
    destinationName: 'Córdoba',
    origin: LatLngValue(latitude: -32, longitude: -60),
    destination: LatLngValue(latitude: -31, longitude: -64),
    distanceKm: 100,
    durationMinutes: 60,
  );
  controller.vehicleProfile = const VehicleProfile(
    consumptionLitersPer100Km: 30,
    maintenanceCostPerKm: 100,
    capacityTons: 30,
  );
  controller.setPricingMode(mode);
  if (mode == PricingMode.flatRate) {
    controller.setFlatRate(100000);
  } else {
    controller.setTons(10);
    controller.setPricePerTon(10000);
  }
  return controller;
}
