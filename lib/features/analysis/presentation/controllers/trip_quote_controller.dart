import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/data/id_factory.dart';
import '../../../costs/domain/models/cost_inputs.dart';
import '../../../costs/domain/services/toll_estimator.dart';
import '../../../history/domain/models/trip_record.dart';
import '../../../history/domain/repositories/trip_repository.dart';
import '../../../route_planning/data/manual_route_service.dart';
import '../../../route_planning/domain/models/lat_lng_value.dart';
import '../../../route_planning/domain/models/route_info.dart';
import '../../../route_planning/domain/services/geocoding_service.dart';
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
    required this.geocodingService,
    required this.tollEstimator,
    required this.vehicleProfileRepository,
    required this.tripRepository,
    required CostInputs initialCosts,
    ManualRouteService? manualRouteService,
  })  : costs = initialCosts,
        manualRouteService = manualRouteService ?? ManualRouteService();

  final ProfitabilityCalculator calculator;
  final RouteService routeService;
  final GeocodingService geocodingService;
  final TollEstimator tollEstimator;
  final VehicleProfileRepository vehicleProfileRepository;
  final TripRepository tripRepository;
  final ManualRouteService manualRouteService;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _historyLoaded = false;

  VehicleProfile? vehicleProfile;
  VehicleProfile? personalVehicle;
  TripPurpose purpose = TripPurpose.freight;
  int travelers = 1;
  List<TripRecord> history = [];
  bool isHistoryLoading = false;

  String origin = '';
  String destination = '';
  LatLngValue? originPoint;
  LatLngValue? destinationPoint;
  PricingMode pricingMode = PricingMode.flatRate;
  double flatRate = 0;
  double tons = 0;
  double pricePerTon = 0;
  bool emptyReturn = false;
  bool isRouteLoading = false;
  bool isManualRouteRequired = false;
  bool isOriginResolving = false;
  bool isDestinationResolving = false;
  bool isSaving = false;
  String? errorMessage;
  RouteInfo? route;
  CostInputs costs;
  TollEstimate? tollEstimate;
  bool tollsEditedManually = false;
  final Set<String> invalidOfferFields = {};

  VehicleProfile? get activeVehicle =>
      purpose == TripPurpose.personal ? personalVehicle : vehicleProfile;

  double get costPerPerson =>
      (analysis?.totalCosts ?? 0) / (travelers < 1 ? 1 : travelers);

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
      purpose: purpose,
    );
  }

  double get grossIncome => tripInputs.grossIncome;

  TripAnalysis? get analysis {
    final profile = activeVehicle;
    final currentRoute = route;
    if (currentRoute == null ||
        profile == null ||
        !profile.isCompleteFor(purpose)) {
      return null;
    }
    return _calculateAnalysis(
      route: currentRoute,
      trip: tripInputs,
      costs: costs,
      emptyReturn: emptyReturn,
    );
  }

  TripAnalysis? analysisForRecord(TripRecord record) {
    return _calculateAnalysis(
      route: record.route,
      trip: record.trip,
      costs: record.costs,
      emptyReturn: record.emptyReturn,
    );
  }

  TripAnalysis? _calculateAnalysis({
    required RouteInfo route,
    required TripInputs trip,
    required CostInputs costs,
    required bool emptyReturn,
  }) {
    final profile =
        trip.purpose == TripPurpose.personal ? personalVehicle : vehicleProfile;
    if (profile == null ||
        !profile.isCompleteFor(trip.purpose) ||
        !trip.isValid) {
      return null;
    }
    return calculator.calculate(
      route: route,
      trip: trip,
      costs: costs,
      vehicleProfile: trip.purpose == TripPurpose.personal
          ? profile.copyWith(dailyFixedCost: 0)
          : profile,
      emptyReturn: emptyReturn,
    );
  }

  Future<bool> prepareAnalysis() async {
    if (route == null) {
      await calculateRoute();
    }
    return validateVehicleStep() &&
        validateRouteStep() &&
        validateOfferStep() &&
        analysis != null;
  }

  bool validateVehicleStep() {
    final profile = activeVehicle;
    if (profile == null || !profile.isCompleteFor(purpose)) {
      return _setValidationError(
        purpose == TripPurpose.personal
            ? 'Cargá consumo y mantenimiento del vehículo para continuar.'
            : 'Carga consumo, mantenimiento y capacidad del vehículo para continuar.',
      );
    }
    return _clearValidationError();
  }

  bool validateRouteStep() {
    if (originPoint == null || destinationPoint == null) {
      return _setValidationError('Selecciona origen y destino para continuar.');
    }
    if (isOriginResolving || isDestinationResolving) {
      return _setValidationError('Esperá a que terminemos de buscar el lugar.');
    }
    if (isRouteLoading) {
      return _setValidationError(
          'Esperá a que terminemos de calcular la ruta.');
    }
    if (route == null) {
      return _setValidationError(
          'No se pudo calcular la ruta. Revisá los puntos.');
    }
    return _clearValidationError();
  }

  bool validateOfferStep() {
    if (invalidOfferFields.isNotEmpty || costs.fuelPricePerLiter <= 0) {
      return _setValidationError(
        'Revisá los importes: el combustible por litro debe ser mayor que cero.',
      );
    }
    if (purpose == TripPurpose.freight && !tripInputs.isValid) {
      return _setValidationError('Carga un precio válido para continuar.');
    }
    if (costs.fuelPricePerLiter < 0 ||
        costs.tolls < 0 ||
        costs.allowances < 0) {
      return _setValidationError('Los costos no pueden ser negativos.');
    }
    final profile = activeVehicle;
    if (purpose == TripPurpose.freight &&
        pricingMode == PricingMode.perTon &&
        profile != null &&
        tons > profile.capacityTons) {
      return _setValidationError(
        'Tu vehículo tiene capacidad para ${profile.capacityTons} toneladas. Ajustá la carga o el vehículo.',
      );
    }
    return _clearValidationError();
  }

  void setOfferFieldValidity(String field, bool isValid) {
    if (isValid) {
      invalidOfferFields.remove(field);
    } else {
      invalidOfferFields.add(field);
    }
    notifyListeners();
  }

  bool _setValidationError(String message) {
    errorMessage = message;
    notifyListeners();
    return false;
  }

  bool _clearValidationError() {
    if (errorMessage != null) {
      errorMessage = null;
      notifyListeners();
    }
    return true;
  }

  void resetSimulation() {
    origin = '';
    destination = '';
    originPoint = null;
    destinationPoint = null;
    pricingMode = PricingMode.flatRate;
    flatRate = 0;
    tons = 0;
    pricePerTon = 0;
    travelers = 1;
    invalidOfferFields.clear();
    emptyReturn = false;
    isRouteLoading = false;
    isManualRouteRequired = false;
    isOriginResolving = false;
    isDestinationResolving = false;
    isSaving = false;
    errorMessage = null;
    route = null;
    costs = const CostInputs();
    tollEstimate = null;
    tollsEditedManually = false;
    notifyListeners();
  }

  void startTrip(TripPurpose nextPurpose) {
    resetSimulation();
    purpose = nextPurpose;
    notifyListeners();
  }

  Future<void> resolveOrigin(String input) async {
    await _resolveLocation(
      input: input,
      isOrigin: true,
    );
  }

  Future<void> resolveDestination(String input) async {
    await _resolveLocation(
      input: input,
      isOrigin: false,
    );
  }

  void load() {
    _subscriptions.add(
      vehicleProfileRepository.watch().listen((profile) {
        vehicleProfile = profile;
        notifyListeners();
      }),
    );
  }

  void loadHistory() {
    if (_historyLoaded || isHistoryLoading) {
      return;
    }
    isHistoryLoading = true;
    notifyListeners();
    _subscriptions.add(
      tripRepository.watchRecent().listen(
        (items) {
          history = items;
          isHistoryLoading = false;
          _historyLoaded = true;
          notifyListeners();
        },
        onError: (_) {
          isHistoryLoading = false;
          notifyListeners();
        },
      ),
    );
  }

  void setOriginPoint(LatLngValue point) {
    originPoint = point;
    origin = _formatPoint(point);
    route = null;
    isManualRouteRequired = false;
    tollEstimate = null;
    _calculateRouteIfReady();
    notifyListeners();
  }

  void setDestinationPoint(LatLngValue point) {
    destinationPoint = point;
    destination = _formatPoint(point);
    route = null;
    isManualRouteRequired = false;
    tollEstimate = null;
    _calculateRouteIfReady();
    notifyListeners();
  }

  void setOriginText(String value) {
    origin = value;
    originPoint = null;
    route = null;
    tollEstimate = null;
    isManualRouteRequired = false;
    errorMessage = null;
    notifyListeners();
  }

  void setDestinationText(String value) {
    destination = value;
    destinationPoint = null;
    route = null;
    tollEstimate = null;
    isManualRouteRequired = false;
    errorMessage = null;
    notifyListeners();
  }

  bool setManualRoute({
    required double distanceKm,
    required double durationHours,
  }) {
    final originPoint = this.originPoint;
    final destinationPoint = this.destinationPoint;
    if (originPoint == null ||
        destinationPoint == null ||
        distanceKm <= 0 ||
        durationHours <= 0) {
      errorMessage = 'Ingresá kilómetros y horas mayores a cero.';
      notifyListeners();
      return false;
    }
    route = manualRouteService.createRoute(
      origin: originPoint,
      destination: destinationPoint,
      originName: origin,
      destinationName: destination,
      distanceKm: distanceKm,
      durationMinutes: durationHours * 60,
    );
    isManualRouteRequired = false;
    errorMessage = null;
    _applyEstimatedTolls(force: !tollsEditedManually || costs.tolls == 0);
    notifyListeners();
    return true;
  }

  Future<void> calculateRoute() async {
    final origin = originPoint;
    final destination = destinationPoint;
    if (origin == null || destination == null) {
      errorMessage = 'Selecciona origen y destino en el mapa.';
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
        originName: this.origin,
        destinationName: this.destination,
      );
      _applyEstimatedTolls(force: !tollsEditedManually || costs.tolls == 0);
    } on Object catch (error) {
      errorMessage = error.toString();
      isManualRouteRequired = true;
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

  void savePersonalVehicle(VehicleProfile profile) {
    personalVehicle = profile;
    notifyListeners();
  }

  void setTravelers(int value) {
    travelers = value < 1 ? 1 : value;
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
    tollsEditedManually = true;
    costs = costs.copyWith(tolls: value);
    notifyListeners();
  }

  void useEstimatedTolls() {
    _applyEstimatedTolls(force: true);
    notifyListeners();
  }

  void setAllowances(double value) {
    costs = costs.copyWith(allowances: value);
    notifyListeners();
  }

  void setEmptyReturn(bool value) {
    emptyReturn = value;
    if (!tollsEditedManually) _applyEstimatedTolls(force: true);
    notifyListeners();
  }

  Future<void> saveCurrentTrip() async {
    final record = createCurrentTripRecord();
    if (record == null) {
      errorMessage = purpose == TripPurpose.personal
          ? 'Completa ruta y perfil del vehículo antes de guardar.'
          : 'Completa ruta, precio y perfil del vehículo antes de guardar.';
      notifyListeners();
      return;
    }

    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      await tripRepository.save(record);
    } on Object catch (error) {
      errorMessage = 'No se pudo guardar la simulacion: $error';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  TripRecord? createCurrentTripRecord() {
    final currentRoute = route;
    final currentAnalysis = analysis;
    final trip = tripInputs;
    if (currentRoute == null || currentAnalysis == null || !trip.isValid) {
      return null;
    }
    return TripRecord.fromAnalysis(
      id: createId('trip'),
      route: currentRoute,
      trip: trip,
      costs: costs,
      emptyReturn: emptyReturn,
      analysis: currentAnalysis,
    );
  }

  void openTrip(TripRecord record) {
    route = record.route;
    purpose = record.trip.purpose;
    origin = record.route.originName;
    destination = record.route.destinationName;
    originPoint = record.route.origin;
    destinationPoint = record.route.destination;
    pricingMode = record.trip.pricingMode;
    flatRate = record.trip.flatRate;
    tons = record.trip.tons;
    pricePerTon = record.trip.pricePerTon;
    costs = record.costs;
    emptyReturn = record.emptyReturn;
    final estimate = tollEstimator.estimate(
      route: record.route,
      emptyReturn: record.emptyReturn,
    );
    tollEstimate = estimate.ratePerKm > 0 ? estimate : null;
    tollsEditedManually = true;
    errorMessage = null;
    notifyListeners();
  }

  void _applyEstimatedTolls({required bool force}) {
    final currentRoute = route;
    if (currentRoute == null) {
      tollEstimate = null;
      return;
    }

    final estimate = tollEstimator.estimate(
      route: currentRoute,
      emptyReturn: emptyReturn,
    );
    tollEstimate = estimate.ratePerKm > 0 ? estimate : null;
    if (estimate.ratePerKm <= 0) return;
    if (force) {
      costs = costs.copyWith(tolls: estimate.amount);
      tollsEditedManually = false;
    }
  }

  String _formatPoint(LatLngValue point) {
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  Future<void> _resolveLocation({
    required String input,
    required bool isOrigin,
  }) async {
    if (isOrigin) {
      isOriginResolving = true;
    } else {
      isDestinationResolving = true;
    }
    errorMessage = null;
    notifyListeners();

    try {
      final result = await geocodingService.resolve(input);
      isManualRouteRequired = false;
      if (isOrigin) {
        originPoint = result.point;
        origin = result.name;
      } else {
        destinationPoint = result.point;
        destination = result.name;
      }
      route = null;
      tollEstimate = null;
      _calculateRouteIfReady();
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      if (isOrigin) {
        isOriginResolving = false;
      } else {
        isDestinationResolving = false;
      }
      notifyListeners();
    }
  }

  void _calculateRouteIfReady() {
    if (originPoint == null || destinationPoint == null || isRouteLoading) {
      return;
    }
    unawaited(calculateRoute());
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
