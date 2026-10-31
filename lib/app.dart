import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/supabase_bootstrap.dart';
import 'core/services/session_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/analysis/domain/services/profitability_calculator.dart';
import 'features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'features/costs/domain/models/cost_inputs.dart';
import 'features/costs/domain/services/toll_estimator.dart';
import 'features/history/data/memory_trip_repository.dart';
import 'features/history/data/supabase_trip_repository.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/analysis/presentation/screens/trip_quote_screen.dart';
import 'features/route_planning/data/nominatim_geocoding_service.dart';
import 'features/route_planning/data/osrm_route_service.dart';
import 'features/vehicle_profile/data/memory_vehicle_profile_repository.dart';
import 'features/vehicle_profile/data/supabase_vehicle_profile_repository.dart';

const bool enablePersonalMode = bool.fromEnvironment(
  'ENABLE_PERSONAL_MODE',
  defaultValue: false,
);
const String nominatimContactEmail = String.fromEnvironment(
  'NOMINATIM_CONTACT_EMAIL',
  defaultValue: '',
);
const String feedbackWhatsAppNumber = String.fromEnvironment(
  'FEEDBACK_WHATSAPP',
  defaultValue: '',
);

class TripDecisionApp extends StatefulWidget {
  const TripDecisionApp({
    this.supabaseInitializer = SupabaseBootstrap.initialize,
    this.anonymousSignIn,
    super.key,
  });

  final Future<SupabaseClient?> Function() supabaseInitializer;
  final AnonymousSignIn? anonymousSignIn;

  @override
  State<TripDecisionApp> createState() => _TripDecisionAppState();
}

class _TripDecisionAppState extends State<TripDecisionApp> {
  late final TripQuoteController controller;
  late final SessionProvider sessionProvider;

  @override
  void initState() {
    super.initState();
    final clientFuture = widget.supabaseInitializer();
    sessionProvider = SessionProvider(
      clientLoader: () => clientFuture,
      anonymousSignIn: widget.anonymousSignIn,
    );
    controller = _createController(sessionProvider)
      ..load()
      ..loadHistory();
    unawaited(sessionProvider.ensureUserId());
  }

  TripQuoteController _createController(SessionProvider sessionProvider) {
    final memoryVehicleRepository = MemoryVehicleProfileRepository();
    final memoryTripRepository = MemoryTripRepository();
    final vehicleProfileRepository = SupabaseVehicleProfileRepository(
      sessionProvider: sessionProvider,
      fallbackRepository: memoryVehicleRepository,
    );
    final tripRepository = SupabaseTripRepository(
      sessionProvider: sessionProvider,
      fallbackRepository: memoryTripRepository,
    );

    const osrmBaseUrl = String.fromEnvironment(
      'OSRM_BASE_URL',
      defaultValue: 'https://router.project-osrm.org',
    );
    final routeService = OsrmRouteService(baseUrl: osrmBaseUrl);
    const nominatimBaseUrl = String.fromEnvironment(
      'NOMINATIM_BASE_URL',
      defaultValue: 'https://nominatim.openstreetmap.org',
    );
    final geocodingService = NominatimGeocodingService(
      baseUrl: nominatimBaseUrl,
      contactEmail: nominatimContactEmail,
    );
    final tollEstimator = TollEstimator(
      ratePerKm: _doubleEnvironment('TOLL_RATE_PER_KM', 0),
      minimumAmount: _doubleEnvironment('TOLL_MINIMUM', 0),
      roundTo: _doubleEnvironment('TOLL_ROUND_TO', 100),
    );

    return TripQuoteController(
      calculator: const ProfitabilityCalculator(
        marginThresholds: ProfitabilityThresholds(),
      ),
      routeService: routeService,
      geocodingService: geocodingService,
      tollEstimator: tollEstimator,
      vehicleProfileRepository: vehicleProfileRepository,
      tripRepository: tripRepository,
      initialCosts: const CostInputs(),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netokm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: enablePersonalMode
          ? HomeScreen(
              controller: controller,
              personalModeEnabled: enablePersonalMode,
              feedbackWhatsAppNumber: feedbackWhatsAppNumber,
              sessionProvider: sessionProvider,
            )
          : TripQuoteScreen(
              controller: controller,
              personalModeEnabled: enablePersonalMode,
              feedbackWhatsAppNumber: feedbackWhatsAppNumber,
              sessionProvider: sessionProvider,
            ),
    );
  }
}

double _doubleEnvironment(String name, double fallback) {
  final value = switch (name) {
    'TOLL_RATE_PER_KM' => const String.fromEnvironment('TOLL_RATE_PER_KM'),
    'TOLL_MINIMUM' => const String.fromEnvironment('TOLL_MINIMUM'),
    'TOLL_ROUND_TO' => const String.fromEnvironment('TOLL_ROUND_TO'),
    _ => '',
  };
  return double.tryParse(value) ?? fallback;
}
