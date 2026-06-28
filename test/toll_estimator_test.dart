import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';

void main() {
  const route = RouteInfo(
    originName: 'Rosario',
    destinationName: 'Cordoba',
    origin: LatLngValue(latitude: -32.9442, longitude: -60.6505),
    destination: LatLngValue(latitude: -31.4201, longitude: -64.1888),
    distanceKm: 401,
    durationMinutes: 360,
  );

  test('estimates tolls from route distance', () {
    const estimator = TollEstimator(ratePerKm: 35, roundTo: 100);

    final estimate = estimator.estimate(route: route, emptyReturn: false);

    expect(estimate.distanceKm, 401);
    expect(estimate.amount, 14000);
  });

  test('empty return doubles estimated toll distance', () {
    const estimator = TollEstimator(ratePerKm: 35, roundTo: 100);

    final estimate = estimator.estimate(route: route, emptyReturn: true);

    expect(estimate.distanceKm, 802);
    expect(estimate.amount, 28100);
  });

  test('uses minimum amount when route estimate is too low', () {
    const estimator = TollEstimator(
      ratePerKm: 1,
      minimumAmount: 5000,
      roundTo: 100,
    );

    final estimate = estimator.estimate(route: route, emptyReturn: false);

    expect(estimate.amount, 5000);
  });
}
