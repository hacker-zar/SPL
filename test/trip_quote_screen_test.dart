import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/core/utils/money_format.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/screens/trip_quote_screen.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/history/data/memory_trip_repository.dart';
import 'package:rentabilidad_flete/features/history/domain/models/trip_record.dart';
import 'package:rentabilidad_flete/features/history/domain/repositories/trip_repository.dart';
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

  testWidgets('save failure is visible on the result screen', (tester) async {
    final controller =
        _controller(PricingMode.flatRate, _FailingTripRepository());
    await tester.pumpWidget(MaterialApp(
      home: TripResultScreen(controller: controller, onNewSimulation: () {}),
    ));
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar simulación'));
    await tester.pumpAndSettle();

    expect(controller.errorMessage, contains('No se pudo guardar'));
    expect(find.textContaining('No se pudo guardar'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('confirms a successful save briefly', (tester) async {
    final controller = _controller(PricingMode.flatRate);
    await tester.pumpWidget(MaterialApp(
      home: TripResultScreen(controller: controller, onNewSimulation: () {}),
    ));
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar simulación'));
    await tester.pumpAndSettle();
    expect(find.text('Simulación guardada.'), findsOneWidget);
    controller.dispose();
  });
}

TripQuoteController _controller(PricingMode mode,
    [TripRepository? repository]) {
  final controller = TripQuoteController(
    calculator: const ProfitabilityCalculator(
      marginThresholds: ProfitabilityThresholds(),
    ),
    routeService: ManualRouteService(),
    geocodingService: NominatimGeocodingService(),
    tollEstimator: const TollEstimator(ratePerKm: 0),
    vehicleProfileRepository: MemoryVehicleProfileRepository(),
    tripRepository: repository ?? MemoryTripRepository(),
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

class _FailingTripRepository implements TripRepository {
  @override
  Stream<List<TripRecord>> watchRecent() => const Stream.empty();

  @override
  Future<void> save(TripRecord trip) async {
    throw StateError('guardado fallido');
  }
}
