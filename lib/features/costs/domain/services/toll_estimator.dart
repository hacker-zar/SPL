import '../../../route_planning/domain/models/route_info.dart';

class TollEstimate {
  const TollEstimate({
    required this.amount,
    required this.ratePerKm,
    required this.distanceKm,
  });

  final double amount;
  final double ratePerKm;
  final double distanceKm;
}

class TollEstimator {
  const TollEstimator({
    required this.ratePerKm,
    this.minimumAmount = 0,
    this.roundTo = 100,
  });

  final double ratePerKm;
  final double minimumAmount;
  final double roundTo;

  TollEstimate estimate({
    required RouteInfo route,
    required bool emptyReturn,
  }) {
    final effectiveRoute = emptyReturn ? route.withEmptyReturn() : route;
    final rawAmount = effectiveRoute.distanceKm * ratePerKm;
    final withMinimum = rawAmount < minimumAmount ? minimumAmount : rawAmount;
    final amount = _roundAmount(withMinimum);

    return TollEstimate(
      amount: amount,
      ratePerKm: ratePerKm,
      distanceKm: effectiveRoute.distanceKm,
    );
  }

  double _roundAmount(double value) {
    if (roundTo <= 0) {
      return value;
    }
    return (value / roundTo).roundToDouble() * roundTo;
  }
}
