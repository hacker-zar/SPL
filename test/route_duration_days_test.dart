import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';

void main() {
  test('estimates days using ten driving hours per day', () {
    expect(_routeForHours(9).durationDays, 1);
    expect(_routeForHours(11).durationDays, 2);
    expect(_routeForHours(20).durationDays, 2);
    expect(_routeForHours(21).durationDays, 3);
    expect(drivingHoursPerDay, 10);
  });
}

RouteInfo _routeForHours(double hours) => RouteInfo(
      originName: 'Origen',
      destinationName: 'Destino',
      origin: const LatLngValue(latitude: -32, longitude: -60),
      destination: const LatLngValue(latitude: -31, longitude: -61),
      distanceKm: 100,
      durationMinutes: hours * 60,
    );
