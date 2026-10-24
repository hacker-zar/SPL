import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';

void main() {
  RouteInfo routeForHours(double hours) => RouteInfo(
        originName: 'A',
        destinationName: 'B',
        origin: const LatLngValue(latitude: 1, longitude: 1),
        destination: const LatLngValue(latitude: 2, longitude: 2),
        distanceKm: 100,
        durationMinutes: hours * 60,
      );

  test('estimates integer days at ten driving hours per day', () {
    expect(routeForHours(9).durationDays, 1);
    expect(routeForHours(11).durationDays, 2);
    expect(routeForHours(20).durationDays, 2);
    expect(routeForHours(21).durationDays, 3);
  });

  test('empty return doubles minutes before calculating days', () {
    expect(routeForHours(9).withEmptyReturn().durationDays, 2);
  });
}
