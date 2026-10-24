import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rentabilidad_flete/core/theme/app_theme.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/screens/trip_quote_screen.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/widgets/offer_costs_step.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/widgets/route_step.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/history/data/memory_trip_repository.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/place_search_result.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/services/geocoding_service.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/services/route_service.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/domain/models/vehicle_profile.dart';

void main() {
  test('reverse geocoding is queued and sends configured contact email',
      () async {
    var now = DateTime.utc(2026, 10, 24);
    final times = <DateTime>[];
    final service = NominatimGeocodingService(
      contactEmail: 'contacto@netokm.example',
      now: () => now,
      delay: (duration) async => now = now.add(duration),
      client: MockClient((request) async {
        times.add(now);
        expect(request.url.queryParameters['email'], 'contacto@netokm.example');
        if (request.url.path.endsWith('/search')) {
          return http.Response(
            '[{"lat":"-32.95","lon":"-60.66","display_name":"Rosario"}]',
            200,
          );
        }
        expect(request.url.path, endsWith('/reverse'));
        return http.Response('{"display_name":"Rosario, Argentina"}', 200);
      }),
    );
    await service.resolve('Rosario');
    final result = await service.reverse(_origin);
    expect(result.name, 'Rosario, Argentina');
    expect(times, hasLength(2));
    expect(times.last.difference(times.first),
        greaterThanOrEqualTo(const Duration(seconds: 1)));
  });

  test('Nominatim reports empty and unmatched locations in correct Spanish',
      () async {
    final service = NominatimGeocodingService(
      delay: (_) async {},
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    await expectLater(
      service.resolve('   '),
      throwsA(
        isA<GeocodingException>().having(
          (error) => error.message,
          'message',
          'Escribí una ubicación o coordenadas.',
        ),
      ),
    );
    await expectLater(
      service.resolve('No existe'),
      throwsA(
        isA<GeocodingException>().having(
          (error) => error.message,
          'message',
          'No encontré esa ubicación.',
        ),
      ),
    );
  });

  test('map point shows a provisional label, then the resolved name', () async {
    final completer = Completer<PlaceSearchResult>();
    final repository = MemoryTripRepository();
    final controller = _controller(
      _FakeGeocoder(reverseResult: completer.future),
      tripRepository: repository,
    )..setFlatRate(100000);
    controller.setOriginPoint(_origin);
    controller.setDestinationPoint(_destination);
    expect(controller.origin, 'Punto elegido en el mapa');
    completer.complete(const PlaceSearchResult(
      name: 'Rosario, Argentina',
      point: _origin,
    ));
    await Future<void>.delayed(Duration.zero);
    expect(controller.origin, 'Rosario, Argentina');
    expect(controller.createCurrentTripRecord()?.route.originName,
        'Rosario, Argentina');
    await controller.saveCurrentTrip();
    final savedTrips = await repository.watchRecent().first;
    expect(savedTrips.single.route.originName, 'Rosario, Argentina');
    controller.dispose();
  });

  test('failed reverse geocoding keeps the provisional map label', () async {
    final controller = _controller(_FakeGeocoder(failReverse: true));
    controller.setOriginPoint(_origin);
    await Future<void>.delayed(Duration.zero);
    expect(controller.origin, 'Punto elegido en el mapa');
    controller.dispose();
  });

  test('controller strips exception type from errors shown to users', () async {
    final controller = _controller(
      _FakeGeocoder(failResolve: true),
    )..setOriginText('Córdoba');
    await controller.resolveOrigin('Córdoba');
    expect(controller.errorMessage, 'No se pudo encontrar el lugar.');
    controller.dispose();
  });

  test('editing a confirmed place invalidates its route and blocks advance',
      () {
    final controller = _controller(_FakeGeocoder())
      ..route = _route
      ..originPoint = _origin
      ..destinationPoint = _destination;
    controller.setOriginText('Rosario centro');
    expect(controller.route, isNull);
    expect(controller.originPoint, isNull);
    expect(controller.validateRouteStep(), isFalse);
    expect(controller.errorMessage, contains('Confirmá'));
    controller.dispose();
  });

  testWidgets('editing origin hides distance and keeps the user on route step',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(_FakeGeocoder())
      ..route = _route
      ..originPoint = _origin
      ..destinationPoint = _destination;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: TripQuoteScreen(controller: controller),
    ));
    expect(find.textContaining('100,0 km en total'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Rosario nuevo');
    await tester.pump();
    expect(find.textContaining('100,0 km en total'), findsNothing);
    expect(find.text('Confirmá el origen.'), findsWidgets);
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('Paso 1 de 3 · Ruta'), findsOneWidget);
    controller.dispose();
  });

  test('reset preserves the selected empty return during this session', () {
    final controller = _controller(_FakeGeocoder())..setEmptyReturn(true);
    controller.resetSimulation();
    expect(controller.emptyReturn, isTrue);
    controller.dispose();
  });

  testWidgets('freight result warns for out-of-scale ratios only',
      (tester) async {
    final normal = _controller(_FakeGeocoder())..setFlatRate(100000);
    await tester.pumpWidget(_resultApp(normal));
    expect(
      find.text(
        'Estos números parecen fuera de lo normal. Revisá los importes que cargaste.',
      ),
      findsNothing,
    );
    normal.dispose();

    final extreme = _controller(_FakeGeocoder())..setFlatRate(100000000);
    await tester.pumpWidget(_resultApp(extreme));
    expect(
      find.text(
        'Estos números parecen fuera de lo normal. Revisá los importes que cargaste.',
      ),
      findsOneWidget,
    );
    expect(find.text('Revisar importes'), findsOneWidget);
    extreme.dispose();
  });

  testWidgets('amount field warns above nine digits without blocking entry',
      (tester) async {
    final controller = _controller(_FakeGeocoder());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => OfferCostsStep(controller: controller),
          ),
        ),
      ),
    ));
    final field = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Precio del viaje');
    await tester.enterText(field, '1000000000');
    await tester.pump();
    expect(find.text('El importe supera las 9 cifras; revisá si está bien.'),
        findsOneWidget);
    expect(controller.flatRate, 1000000000);
    controller.dispose();
  });

  testWidgets('freight route offers explicit one-way and empty-return choices',
      (tester) async {
    final controller = _controller(_FakeGeocoder());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body:
              SingleChildScrollView(child: RouteStep(controller: controller))),
    ));
    expect(find.text('Solo ida'), findsOneWidget);
    expect(find.text('Ida y vuelta vacío'), findsOneWidget);
    controller.dispose();
  });
}

Widget _resultApp(TripQuoteController controller) => MaterialApp(
      theme: AppTheme.dark(),
      home: TripResultScreen(
        controller: controller,
        onNewSimulation: () {},
      ),
    );

TripQuoteController _controller(
  GeocodingService geocoder, {
  MemoryTripRepository? tripRepository,
}) {
  return TripQuoteController(
    calculator: const ProfitabilityCalculator(
      marginThresholds: ProfitabilityThresholds(),
    ),
    routeService: _RouteService(),
    geocodingService: geocoder,
    tollEstimator: const TollEstimator(ratePerKm: 0),
    vehicleProfileRepository: MemoryVehicleProfileRepository(),
    tripRepository: tripRepository ?? MemoryTripRepository(),
    initialCosts: const CostInputs(fuelPricePerLiter: 1000),
  )
    ..route = _route
    ..originPoint = _origin
    ..destinationPoint = _destination
    ..vehicleProfile = _profile;
}

class _FakeGeocoder implements GeocodingService {
  _FakeGeocoder({
    this.reverseResult,
    this.failReverse = false,
    this.failResolve = false,
  });

  final Future<PlaceSearchResult>? reverseResult;
  final bool failReverse;
  final bool failResolve;

  @override
  Future<PlaceSearchResult> resolve(String input) async {
    if (failResolve) throw _PrefixedException();
    return PlaceSearchResult(name: input, point: _origin);
  }

  @override
  Future<PlaceSearchResult> reverse(LatLngValue point) {
    if (failReverse) throw Exception('reverse unavailable');
    return reverseResult ??
        Future.value(PlaceSearchResult(
          name: 'Rosario, Argentina',
          point: point,
        ));
  }
}

class _PrefixedException implements Exception {
  @override
  String toString() => 'GeocodingException: No se pudo encontrar el lugar.';
}

class _RouteService implements RouteService {
  @override
  Future<RouteInfo> calculateRoute({
    required LatLngValue origin,
    required LatLngValue destination,
    String? originName,
    String? destinationName,
  }) async =>
      RouteInfo(
        originName: originName ?? '',
        destinationName: destinationName ?? '',
        origin: origin,
        destination: destination,
        distanceKm: 100,
        durationMinutes: 120,
      );
}

const _origin = LatLngValue(latitude: -32.95, longitude: -60.66);
const _destination = LatLngValue(latitude: -31.42, longitude: -64.19);
const _route = RouteInfo(
  originName: 'Rosario',
  destinationName: 'Córdoba',
  origin: _origin,
  destination: _destination,
  distanceKm: 100,
  durationMinutes: 120,
);
const _profile = VehicleProfile(
  consumptionLitersPer100Km: 30,
  maintenanceCostPerKm: 100,
  capacityTons: 28,
);
