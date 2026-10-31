import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/data/id_factory.dart';
import '../../../costs/domain/models/cost_inputs.dart';
import '../../../costs/domain/services/toll_estimator.dart';
import '../../../history/domain/models/trip_record.dart';
import '../../../history/domain/repositories/trip_repository.dart';
import '../../../route_planning/domain/models/lat_lng_value.dart';
import '../../../route_planning/domain/models/route_info.dart';
import '../../../route_planning/domain/services/geocoding_service.dart';
import '../../../route_planning/domain/services/route_service.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
import '../../../vehicle_profile/domain/models/vehicle_profile.dart';
import '../../../vehicle_profile/domain/repositories/vehicle_profile_repository.dart';
import '../../domain/models/trip_analysis.dart';
import '../../domain/models/profitability_status.dart';
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
  }) : costs = initialCosts;

  final ProfitabilityCalculator calculator;
  final RouteService routeService;
  final GeocodingService geocodingService;
  final TollEstimator tollEstimator;
  final VehicleProfileRepository vehicleProfileRepository;
  final TripRepository tripRepository;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription<List<TripRecord>>? _historySubscription;
  bool _historyLoaded = false;
  int _originRevision = 0;
  int _destinationRevision = 0;
  int _routeRevision = 0;
  Future<void> _pendingOriginName = Future<void>.value();
  Future<void> _pendingDestinationName = Future<void>.value();

  VehicleProfile? vehicleProfile;
  VehicleProfile? personalVehicle;
  TripPurpose purpose = TripPurpose.freight;
  int travelers = 1;
  List<TripRecord> history = [];
  bool isHistoryLoading = false;
  String? historyErrorMessage;

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
  bool isOriginResolving = false;
  bool isDestinationResolving = false;
  bool isSaving = false;
  String? errorMessage;
  String? vehicleProfileErrorMessage;
  RouteInfo? route;
  CostInputs costs;
  TollEstimate? tollEstimate;
  bool tollsEditedManually = false;
  TripRecord? _displayedSavedTrip;

  VehicleProfile? get activeVehicle =>
      purpose == TripPurpose.personal ? personalVehicle : vehicleProfile;

  TripRecord? get displayedSavedTrip => _displayedSavedTrip;

  double get costPerPerson =>
      (analysis?.totalCosts ?? 0) / (travelers < 1 ? 1 : travelers);

  RouteInfo? get effectiveRoute {
    final currentRoute = route;
    if (currentRoute == null) {
      return null;
    }
    return emptyReturn ? currentRoute.withEmptyReturn() : currentRoute;
  }

  bool get originNeedsConfirmation => origin.isNotEmpty && originPoint == null;
  bool get destinationNeedsConfirmation =>
      destination.isNotEmpty && destinationPoint == null;

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
    final savedTrip = _displayedSavedTrip;
    if (savedTrip != null) return analysisForRecord(savedTrip);
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
    final effectiveRoute =
        record.emptyReturn ? record.route.withEmptyReturn() : record.route;
    final distance = effectiveRoute.distanceKm;
    final profile = record.vehicleProfile;
    final fuelCost = profile == null
        ? 0.0
        : distance *
            profile.consumptionLitersPer100Km /
            100 *
            record.costs.fuelPricePerLiter;
    final maintenance =
        profile == null ? 0.0 : distance * profile.maintenanceCostPerKm;
    final tires = profile == null ? 0.0 : distance * profile.tireCostPerKm;
    final other =
        profile == null ? 0.0 : distance * profile.otherOperatingCostsPerKm;
    final fixed = profile == null
        ? record.totalCosts
        : record.costs.tolls + record.costs.allowances;
    final timeCost = profile == null || record.trip.purpose == TripPurpose.personal
        ? 0.0
        : profile.dailyFixedCost * effectiveRoute.durationDays;
    final status = switch (record.calculationStatus) {
      'profitable' => ProfitabilityStatus.profitable,
      'low' => ProfitabilityStatus.low,
      'loss' => ProfitabilityStatus.loss,
      _ => calculator.statusForValues(
          netProfit: record.netProfit,
          marginPercent: record.marginPercent,
        ),
    };
    double divide(double value, double by) => by == 0 ? 0 : value / by;
    return TripAnalysis(
      grossIncome: record.income,
      fuelCost: fuelCost,
      maintenanceCost: maintenance,
      tireCost: tires,
      otherOperatingCost: other,
      fixedCosts: fixed,
      timeCost: timeCost,
      totalCosts: record.totalCosts,
      netProfit: record.netProfit,
      marginPercent: record.marginPercent,
      incomePerKm: divide(record.income, distance),
      costPerKm: divide(record.totalCosts, distance),
      profitPerKm: divide(record.netProfit, distance),
      breakEvenPrice: record.totalCosts,
      minimumPricePerTon: divide(record.totalCosts, record.trip.tons),
      status: status,
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
            : 'Cargá el consumo, mantenimiento y la capacidad del camión para continuar.',
      );
    }
    return _clearValidationError();
  }

  bool validateRouteStep() {
    if (originPoint == null || destinationPoint == null) {
      return _setValidationError(
          'Confirmá el origen y el destino para continuar.');
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
    if (purpose == TripPurpose.freight && !tripInputs.isValid) {
      return _setValidationError('Cargá un precio válido para continuar.');
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
    _displayedSavedTrip = null;
    _originRevision++;
    _destinationRevision++;
    _pendingOriginName = Future<void>.value();
    _pendingDestinationName = Future<void>.value();
    _routeRevision++;
    origin = '';
    destination = '';
    originPoint = null;
    destinationPoint = null;
    pricingMode = PricingMode.flatRate;
    flatRate = 0;
    tons = 0;
    pricePerTon = 0;
    travelers = 1;
    isRouteLoading = false;
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
      vehicleProfileRepository.watchAll().listen(
        (profiles) {
          vehicleProfileErrorMessage = null;
          final freight = profiles.where((profile) =>
              profile.vehicleType != 'auto' && profile.vehicleType != 'moto');
          final personal = profiles.where((profile) =>
              profile.vehicleType == 'auto' || profile.vehicleType == 'moto');
          vehicleProfile = _primaryVehicle(freight);
          personalVehicle = _primaryVehicle(personal);
          notifyListeners();
        },
        onError: (_) {
          vehicleProfileErrorMessage =
              'No se pudo cargar el vehículo guardado. Revisá la conexión.';
          notifyListeners();
        },
      ),
    );
  }

  VehicleProfile? _primaryVehicle(Iterable<VehicleProfile> profiles) {
    for (final profile in profiles) {
      if (profile.isPrimary) return profile;
    }
    return profiles.firstOrNull;
  }

  void loadHistory() {
    if (_historyLoaded || isHistoryLoading) {
      return;
    }
    isHistoryLoading = true;
    notifyListeners();
    unawaited(_historySubscription?.cancel());
    _historySubscription = tripRepository.watchRecent().listen(
      (items) {
        history = items;
        isHistoryLoading = false;
        _historyLoaded = true;
        historyErrorMessage = null;
        notifyListeners();
      },
      onError: (_) {
        isHistoryLoading = false;
        _historyLoaded = false;
        _historyLoaded = false;
        _historyLoaded = false;
        historyErrorMessage =
            'No se pudo cargar el historial. Revisá tu conexión e intentá de nuevo.';
        notifyListeners();
      },
    );
  }

  void setOriginPoint(LatLngValue point) {
    _displayedSavedTrip = null;
    final revision = ++_originRevision;
    originPoint = point;
    origin = 'Punto elegido en el mapa';
    _invalidateRoute();
    errorMessage = null;
    _calculateRouteIfReady();
    notifyListeners();
    isOriginResolving = false;
    _pendingOriginName = _resolveMapPointName(
      point,
      isOrigin: true,
      revision: revision,
    );
  }

  void setDestinationPoint(LatLngValue point) {
    _displayedSavedTrip = null;
    final revision = ++_destinationRevision;
    destinationPoint = point;
    destination = 'Punto elegido en el mapa';
    _invalidateRoute();
    errorMessage = null;
    _calculateRouteIfReady();
    notifyListeners();
    isDestinationResolving = false;
    _pendingDestinationName = _resolveMapPointName(
      point,
      isOrigin: false,
      revision: revision,
    );
  }

  void setOriginText(String value) {
    _displayedSavedTrip = null;
    if (origin == value && originPoint == null) return;
    if (origin != value) _originRevision++;
    origin = value;
    originPoint = null;
    isOriginResolving = false;
    _invalidateRoute();
    errorMessage = value.trim().isEmpty ? null : 'Confirmá el origen.';
    notifyListeners();
  }

  void setDestinationText(String value) {
    _displayedSavedTrip = null;
    if (destination == value && destinationPoint == null) return;
    if (destination != value) _destinationRevision++;
    destination = value;
    destinationPoint = null;
    isDestinationResolving = false;
    _invalidateRoute();
    errorMessage = value.trim().isEmpty ? null : 'Confirmá el destino.';
    notifyListeners();
  }

  Future<void> calculateRoute() async {
    final origin = originPoint;
    final destination = destinationPoint;
    if (origin == null || destination == null) {
      errorMessage = 'Confirmá el origen y el destino.';
      notifyListeners();
      return;
    }
    final revision = ++_routeRevision;
    isRouteLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final calculatedRoute = await routeService.calculateRoute(
        origin: origin,
        destination: destination,
        originName: this.origin,
        destinationName: this.destination,
      );
      if (revision == _routeRevision &&
          _samePoint(originPoint, origin) &&
          _samePoint(destinationPoint, destination)) {
        route = RouteInfo(
          originName: this.origin,
          destinationName: this.destination,
          origin: calculatedRoute.origin,
          destination: calculatedRoute.destination,
          distanceKm: calculatedRoute.distanceKm,
          durationMinutes: calculatedRoute.durationMinutes,
          polyline: calculatedRoute.polyline,
        );
        _applyEstimatedTolls(force: !tollsEditedManually || costs.tolls == 0);
      }
    } on Object catch (error) {
      if (revision == _routeRevision) {
        errorMessage = _readableError(error);
      }
    } finally {
      if (revision == _routeRevision) {
        isRouteLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveVehicleProfile(VehicleProfile profile) async {
    _displayedSavedTrip = null;
    errorMessage = null;
    try {
      vehicleProfile = await vehicleProfileRepository.save(profile);
    } on Object catch (error) {
      errorMessage = 'No se pudo guardar el vehículo: ${_readableError(error)}';
    }
    notifyListeners();
  }

  Future<void> savePersonalVehicle(VehicleProfile profile) async {
    _displayedSavedTrip = null;
    errorMessage = null;
    try {
      personalVehicle = await vehicleProfileRepository.save(profile);
    } on Object catch (error) {
      errorMessage = 'No se pudo guardar el vehículo: ${_readableError(error)}';
    }
    if (errorMessage != null) return;
    notifyListeners();
  }

  Future<void> deleteTrip(String tripId) async {
    await tripRepository.delete(tripId);
  }

  void setTravelers(int value) {
    _displayedSavedTrip = null;
    travelers = value < 1 ? 1 : value;
    notifyListeners();
  }

  void setPricingMode(PricingMode value) {
    _displayedSavedTrip = null;
    pricingMode = value;
    notifyListeners();
  }

  void setFlatRate(double value) {
    _displayedSavedTrip = null;
    flatRate = value;
    notifyListeners();
  }

  void setTons(double value) {
    _displayedSavedTrip = null;
    tons = value;
    notifyListeners();
  }

  void setPricePerTon(double value) {
    _displayedSavedTrip = null;
    pricePerTon = value;
    notifyListeners();
  }

  void setFuelPrice(double value) {
    _displayedSavedTrip = null;
    costs = costs.copyWith(fuelPricePerLiter: value);
    notifyListeners();
  }

  void setTolls(double value) {
    _displayedSavedTrip = null;
    tollsEditedManually = true;
    costs = costs.copyWith(tolls: value);
    notifyListeners();
  }

  void useEstimatedTolls() {
    _applyEstimatedTolls(force: true);
    notifyListeners();
  }

  void setAllowances(double value) {
    _displayedSavedTrip = null;
    costs = costs.copyWith(allowances: value);
    notifyListeners();
  }

  void setEmptyReturn(bool value) {
    _displayedSavedTrip = null;
    emptyReturn = value;
    if (!tollsEditedManually) _applyEstimatedTolls(force: true);
    notifyListeners();
  }

  Future<void> saveCurrentTrip() async {
    var record = createCurrentTripRecord();
    if (record == null) {
      errorMessage = purpose == TripPurpose.personal
          ? 'Completá la ruta y el perfil del vehículo antes de guardar.'
          : 'Completá la ruta, el precio y el perfil del vehículo antes de guardar.';
      notifyListeners();
      return;
    }

    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([_pendingOriginName, _pendingDestinationName]);
      record = createCurrentTripRecord();
      if (record == null) {
        errorMessage =
            'Completá la ruta, el precio y el perfil del vehículo antes de guardar.';
        return;
      }
      await tripRepository.save(record);
    } on Object catch (error) {
      errorMessage =
          'No se pudo guardar la simulación: ${_readableError(error)}';
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
      vehicleProfile: _displayedSavedTrip?.vehicleProfile ?? activeVehicle,
    );
  }

  void openTrip(TripRecord record) {
    _displayedSavedTrip = null;
    openTripForResult(record);
  }

  void openTripForResult(TripRecord record) {
    _displayedSavedTrip = record;
    _originRevision++;
    _destinationRevision++;
    _routeRevision++;
    _pendingOriginName = Future<void>.value();
    _pendingDestinationName = Future<void>.value();
    isRouteLoading = false;
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

  Future<void> _resolveLocation({
    required String input,
    required bool isOrigin,
  }) async {
    final revision = isOrigin ? _originRevision : _destinationRevision;
    if (isOrigin) {
      isOriginResolving = true;
    } else {
      isDestinationResolving = true;
    }
    errorMessage = null;
    notifyListeners();

    try {
      final result = await geocodingService.resolve(input);
      final isCurrent = isOrigin
          ? revision == _originRevision && origin.trim() == input.trim()
          : revision == _destinationRevision &&
              destination.trim() == input.trim();
      if (!isCurrent) return;
      if (isOrigin) {
        originPoint = result.point;
        origin = result.name;
      } else {
        destinationPoint = result.point;
        destination = result.name;
      }
      _invalidateRoute();
      errorMessage = null;
      _calculateRouteIfReady();
    } on Object catch (error) {
      final isCurrent = isOrigin
          ? revision == _originRevision
          : revision == _destinationRevision;
      if (isCurrent) errorMessage = _readableError(error);
    } finally {
      final isCurrent = isOrigin
          ? revision == _originRevision
          : revision == _destinationRevision;
      if (isCurrent) {
        if (isOrigin) {
          isOriginResolving = false;
        } else {
          isDestinationResolving = false;
        }
        notifyListeners();
      }
    }
  }

  Future<void> _resolveMapPointName(
    LatLngValue point, {
    required bool isOrigin,
    required int revision,
  }) async {
    try {
      final result = await geocodingService.reverse(point);
      final currentPoint = isOrigin ? originPoint : destinationPoint;
      final currentRevision = isOrigin ? _originRevision : _destinationRevision;
      if (revision != currentRevision || !_samePoint(currentPoint, point)) {
        return;
      }
      if (isOrigin) {
        origin = result.name;
      } else {
        destination = result.name;
      }
      final currentRoute = route;
      if (currentRoute != null) {
        route = RouteInfo(
          originName: origin,
          destinationName: destination,
          origin: currentRoute.origin,
          destination: currentRoute.destination,
          distanceKm: currentRoute.distanceKm,
          durationMinutes: currentRoute.durationMinutes,
          polyline: currentRoute.polyline,
        );
      }
      notifyListeners();
    } on Object {
      // Keep the provisional map label when reverse geocoding is unavailable.
    }
  }

  bool _samePoint(LatLngValue? first, LatLngValue second) =>
      first?.latitude == second.latitude &&
      first?.longitude == second.longitude;

  String _readableError(Object error) {
    final message = error.toString();
    return message.replaceFirst(
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*(?:Exception|Error):\s*'),
      '',
    );
  }

  void _calculateRouteIfReady() {
    if (originPoint == null || destinationPoint == null || isRouteLoading) {
      return;
    }
    unawaited(calculateRoute());
  }

  void _invalidateRoute() {
    _routeRevision++;
    route = null;
    tollEstimate = null;
    isRouteLoading = false;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _historySubscription?.cancel();
    super.dispose();
  }
}
