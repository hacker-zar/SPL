import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/core/theme/app_theme.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/screens/trip_quote_screen.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/widgets/trip_wizard.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/history/data/memory_trip_repository.dart';
import 'package:rentabilidad_flete/features/history/presentation/screens/history_screen.dart';
import 'package:rentabilidad_flete/features/route_planning/data/manual_route_service.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/domain/models/vehicle_profile.dart';

const _sizes = <Size>[
  Size(360, 640),
  Size(390, 844),
  Size(768, 1024),
  Size(1280, 800),
];

void main() {
  for (final size in _sizes) {
    for (final scale in <double>[1, 1.3]) {
      for (final step in WizardStep.values) {
        testWidgets(
            'wizard $step at ${size.width}x${size.height}, scale $scale',
            (tester) async {
          await _setViewport(tester, size, scale);
          final controller = _controller(profile: _profile);
          controller.setFlatRate(100000);
          await tester.pumpWidget(_app(
              TripQuoteScreen(
                controller: controller,
                initialStep: step,
              ),
              scale));
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
          if (size.width < 600) {
            _expectVisible(
                tester,
                find.text(
                  step == WizardStep.review
                      ? 'Ver cuánto te queda'
                      : 'Continuar',
                ),
                size.height);
          }
          if (size.width == 1280) {
            _expectMaxWidth(tester, 720);
          }
          controller.dispose();
        });
      }

      testWidgets('result at ${size.width}x${size.height}, scale $scale',
          (tester) async {
        await _setViewport(tester, size, scale);
        final controller = _controller(profile: _profile)..setFlatRate(100000);
        await tester.pumpWidget(_app(
            TripResultScreen(
              controller: controller,
              onNewSimulation: () {},
            ),
            scale));
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (size.width < 600) {
          _expectVisible(tester, find.text('Guardar simulación'), size.height);
        }
        if (size.width == 1280) _expectMaxWidth(tester, 1120);
        controller.dispose();
      });

      testWidgets('history at ${size.width}x${size.height}, scale $scale',
          (tester) async {
        await _setViewport(tester, size, scale);
        final controller = _controller();
        await tester.pumpWidget(_app(
            HistoryScreen(
              controller: controller,
              onOpenTrip: (_) async {},
              onDuplicateTrip: (_) async {},
              onStartTrip: () async {},
            ),
            scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width < 600) {
          _expectVisible(
            tester,
            find.text('Hacer mi primera simulación'),
            size.height,
          );
        }
        if (size.width == 1280) _expectMaxWidth(tester, 900);
        controller.dispose();
      });
    }
  }
}

Future<void> _setViewport(WidgetTester tester, Size size, double scale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget home, double scale) => MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: home,
    );

void _expectVisible(WidgetTester tester, Finder finder, double height) {
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(height));
}

void _expectMaxWidth(WidgetTester tester, double width) {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is ConstrainedBox && widget.constraints.maxWidth == width,
  );
  expect(finder, findsWidgets);
  for (final element in finder.evaluate()) {
    expect(tester.getSize(find.byWidget(element.widget)).width,
        lessThanOrEqualTo(width));
  }
}

TripQuoteController _controller({VehicleProfile? profile}) {
  final controller = TripQuoteController(
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
  if (profile != null) controller.vehicleProfile = profile;
  return controller;
}

const _profile = VehicleProfile(
  consumptionLitersPer100Km: 30,
  maintenanceCostPerKm: 100,
  capacityTons: 28,
);

const _route = RouteInfo(
  originName: 'Rosario',
  destinationName: 'Cordoba',
  origin: LatLngValue(latitude: -32, longitude: -60),
  destination: LatLngValue(latitude: -38, longitude: -62),
  distanceKm: 100,
  durationMinutes: 120,
);
