import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';

void main() {
  test('rate limits requests and caches repeated queries for the session',
      () async {
    var currentTime = DateTime.utc(2026, 1, 1);
    final requestTimes = <DateTime>[];
    final waits = <Duration>[];
    final service = NominatimGeocodingService(
      contactEmail: 'contacto@netokm.example',
      now: () => currentTime,
      delay: (duration) async {
        waits.add(duration);
        currentTime = currentTime.add(duration);
      },
      client: MockClient((request) async {
        requestTimes.add(currentTime);
        expect(request.url.queryParameters['email'], 'contacto@netokm.example');
        expect(request.headers['user-agent'],
            'Netokm/1.0 (contacto@netokm.example)');
        return http.Response(
          '[{"lat":"-34.6","lon":"-58.4","display_name":"${request.url.queryParameters['q']}"}]',
          200,
        );
      }),
    );

    final first = await service.resolve(' Córdoba ');
    final second = await service.resolve('Mendoza');
    final cached = await service.resolve('córdoba');

    expect(first.name, 'Córdoba');
    expect(second.name, 'Mendoza');
    expect(cached, same(first));
    expect(requestTimes, hasLength(2));
    expect(requestTimes.last.difference(requestTimes.first),
        greaterThanOrEqualTo(const Duration(seconds: 1)));
    expect(waits, [const Duration(seconds: 1)]);
  });

  test('does not send email query parameter when contact is not configured',
      () async {
    final service = NominatimGeocodingService(
      client: MockClient((request) async {
        expect(request.url.queryParameters.containsKey('email'), isFalse);
        return http.Response(
          '[{"lat":"-34.6","lon":"-58.4","display_name":"Córdoba"}]',
          200,
        );
      }),
    );

    await service.resolve('Córdoba');
  });
}
