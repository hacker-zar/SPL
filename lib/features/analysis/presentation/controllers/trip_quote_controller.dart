import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/data/id_factory.dart';
import '../../../costs/domain/models/cost_inputs.dart';
import '../../../history/domain/models/trip_record.dart';
import '../../../history/domain/repositories/trip_repository.dart';
import '../../../route_planning/domain/models/route_info.dart';
import '../../../route_planning/domain/services/route_service.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
import '../../../vehicle_profile/domain/models/vehicle_profile.dart';
import '../../../vehicle_profile/domain/repositories/vehicle_profile_repository.dart';
import '../../domain/models/trip_analysis.dart';
import '../../domain/services/profitability_calculator.dart';

class TripQuoteController extends ChangeNotifier {
  TripQuoteController({
    required this.calculator,
    required this.routeService,
    required this.vehicleProfileRepository,
    required this.tripRepository,
    required CostInputs initialCosts,
  }) : costs = initialCosts;

  final ProfitabilityCalculator calculator;
  final RouteService routeService;
  final VehicleProfileRepository vehicleProfileRepository;
  final TripRepository tripRepository;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  VehicleProfile? vehicleProfile;
  List<TripRecord> history = [];

  String origin = '';
  String destination = '';
  PricingMode pricingMode = PricingMode.flatRate;
  double flatRate = 0;
  double tons = 0;
  double pricePerTon = 0;
  bool emptyReturn = false;
  bool isRouteLoading = false;
  bool isSaving = false;
  String? errorMessage;
  RouteInfo? route;
  CostInputs costs;

  RouteInfo? get effectiveRoute {
    final currentRoute = route;
    if (currentRoute == null) {
      return null;
    }
    return emptyReturn ? currentRoute.withEmptyReturn() : currentRoute;
  }

  TripInputs get tripInputs {
    return TripInputs(
      pricingMode: pricingMode,
      flatRate: flatRate,
      tons: tons,
      pricePerTon: pricePerTon,
    );
  }

  double get grossIncome => tripInputs.grossIncome;

  TripAnalysis? get analysis {
    final currentRoute = route;
    final profile = vehicleProfile;
    final trip = tripInputs;
    if (currentRoute == null || profile == null || !profile.isComplete) {
      return null;
    }
    if (!trip.isValid) {
      return null;
    }
    return calculator.calculate(
      route: currentRoute,
      trip: trip,
      costs: costs,
      vehicleProfile: profile,
      emptyReturn: emptyReturn,
    );
  }

  void load() {
    _subscriptions.add(
      vehicleProfileRepository.watch().listen((profile) {
        vehicleProfile = profile;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      tripRepository.watchRecent().listen((items) {
        history = items;
        notifyListeners();
      }),
    );
  }

  void setOrigin(String value) {
    origin = value.trim();
    route = null;
    notifyListeners();
  }

  void setDestination(String value) {
    destination = value.trim();
    route = null;
    notifyListeners();
  }

  Future<void> calculateRoute() async {
    if (origin.isEmpty || destination.isEmpty) {
      errorMessage = 'Carga origen y destino para calcular la ruta.';
      notifyListeners();
      return;
    }
    isRouteLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      route = await routeService.calculateRoute(
        origin: origin,
        destination: destination,
      );
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      isRouteLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveVehicleProfile(VehicleProfile profile) async {
    await vehicleProfileRepository.save(profile);
    vehicleProfile = profile;
    notifyListeners();
  }

  void setPricingMode(PricingMode value) {
    pricingMode = value;
    notifyListeners();
  }

  void setFlatRate(double value) {
    flatRate = value;
    notifyListeners();
  }

  void setTons(double value) {
    tons = value;
    notifyListeners();
  }

  void setPricePerTon(double value) {
    pricePerTon = value;
    notifyListeners();
  }

  void setFuelPrice(double value) {
    costs = costs.copyWith(fuelPricePerLiter: value);
    notifyListeners();
  }

  void setTolls(double value) {
    costs = costs.copyWith(tolls: value);
    notifyListeners();
  }

  void setAllowances(double value) {
    costs = costs.copyWith(allowances: value);
    notifyListeners();
  }

  void setEmptyReturn(bool value) {
    emptyReturn = value;
    notifyListeners();
  }

  Future<void> saveCurrentTrip() async {
    final currentRoute = route;
    final currentAnalysis = analysis;
    final trip = tripInputs;
    if (currentRoute == null || currentAnalysis == null || !trip.isValid) {
      errorMessage = 'Completa ruta, precio y perfil del vehiculo antes de guardar.';
      notifyListeners();
      return;
    }

    isSaving = true;
    errorMessage = null;
    notifyListeners();

    final record = TripRecord.fromAnalysis(
      id: createId('trip'),
      route: currentRoute,
      trip: trip,
      costs: costs,
      emptyReturn: emptyReturn,
      analysis: currentAnalysis,
    );

    try {
      await tripRepository.save(record);
    } on Object catch (error) {
      errorMessage = 'No se pudo guardar la simulacion: $error';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void openTrip(TripRecord record) {
    route = record.route;
    origin = record.route.originName;
    destination = record.route.destinationName;
    pricingMode = record.trip.pricingMode;
    flatRate = record.trip.flatRate;
    tons = record.trip.tons;
    pricePerTon = record.trip.pricePerTon;
    costs = record.costs;
    emptyReturn = record.emptyReturn;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
