import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/screens/trip_quote_screen.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/widgets/trip_wizard.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/history/data/memory_trip_repository.dart';
import 'package:rentabilidad_flete/features/route_planning/data/manual_route_service.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/domain/models/vehicle_profile.dart';

void main() {
  testWidgets('freight starts at route and keeps history visible',
      (tester) async {
    final controller = _controller();
    await tester.pumpWidget(MaterialApp(
      home: TripQuoteScreen(controller: controller),
    ));

    expect(find.text('Paso 1 de 4 · Ruta'), findsOneWidget);
    expect(find.byTooltip('Historial'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('incomplete freight profile is the third step', (tester) async {
    final controller = _controller();
    controller.setFlatRate(100000);
    var step = WizardStep.route;
    await tester.pumpWidget(_wizardHarness(controller, step, (next) {
      step = next;
    }));
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('Paso 2 de 4 · Oferta y costos'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('Paso 3 de 4 · Camión'), findsOneWidget);
    controller.dispose();
  });

  testWidgets(
      'complete profile skips the vehicle step and is editable in review',
      (tester) async {
    final controller = _controller()
      ..route = _route
      ..vehicleProfile = _profile;
    await tester.pumpWidget(_wizardHarness(
      controller,
      WizardStep.offer,
      (_) {},
    ));
    expect(find.text('Paso 2 de 3 · Oferta y costos'), findsOneWidget);

    await tester.pumpWidget(_wizardHarness(
      controller,
      WizardStep.review,
      (_) {},
    ));
    expect(find.text('Paso 3 de 3 · Revisar'), findsOneWidget);
    expect(find.text('Tu camión: 30,0 L/100 km'), findsOneWidget);
    expect(find.text('Editar'), findsWidgets);
    controller.dispose();
  });

  testWidgets('new simulation returns to the first freight step',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller()
      ..vehicleProfile = _profile
      ..route = _route
      ..originPoint = _route.origin
      ..destinationPoint = _route.destination;
    controller.setFlatRate(100000);
    expect(controller.analysis, isNotNull);

    await tester.pumpWidget(MaterialApp(
      home: TripQuoteScreen(
        controller: controller,
        initialStep: WizardStep.review,
      ),
    ));
    await tester.tap(find.text('Ver cuánto te queda'));
    await tester.pumpAndSettle();
    expect(find.text('Resultado del viaje'), findsOneWidget);
    expect(find.text('No hay datos suficientes para mostrar el resultado.'),
        findsNothing);

    await tester.tap(find.text('Nueva simulación'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 3 · Ruta'), findsOneWidget);
    controller.dispose();
  });
}

Widget _wizardHarness(
  TripQuoteController controller,
  WizardStep initialStep,
  ValueChanged<WizardStep> onChanged,
) {
  var step = initialStep;
  return MaterialApp(
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => TripWizard(
          controller: controller,
          step: step,
          onStepChanged: (next) {
            step = next;
            onChanged(next);
            setState(() {});
          },
          onCalculate: () async {},
        ),
      ),
    ),
  );
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
    )
      ..route = _route
      ..originPoint = _route.origin
      ..destinationPoint = _route.destination;

const _profile = VehicleProfile(
  consumptionLitersPer100Km: 30,
  maintenanceCostPerKm: 100,
  capacityTons: 28,
);

const _route = RouteInfo(
  originName: 'Origen',
  destinationName: 'Destino',
  origin: LatLngValue(latitude: -32, longitude: -60),
  destination: LatLngValue(latitude: -38, longitude: -62),
  distanceKm: 100,
  durationMinutes: 120,
);
