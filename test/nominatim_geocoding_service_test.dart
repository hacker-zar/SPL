import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';

void main() {
  test('resolves comma separated coordinates without calling Nominatim', () async {
    final service = NominatimGeocodingService(
      client: MockClient((request) async {
        fail('Coordinates should not call HTTP.');
      }),
    );

    final result = await service.resolve('-32.9442, -60.6505');

    expect(result.point.latitude, -32.9442);
    expect(result.point.longitude, -60.6505);
    expect(result.name, '-32.94420, -60.65050');
  });

  test('resolves a place name through Nominatim', () async {
    final service = NominatimGeocodingService(
      client: MockClient((request) async {
        expect(request.url.path, '/search');
        expect(request.url.queryParameters['q'], 'Rosario');
        return http.Response(
          '[{"display_name":"Rosario, Santa Fe, Argentina","lat":"-32.9442","lon":"-60.6505"}]',
          200,
        );
      }),
    );

    final result = await service.resolve('Rosario');

    expect(result.name, 'Rosario, Santa Fe, Argentina');
    expect(result.point.latitude, -32.9442);
    expect(result.point.longitude, -60.6505);
  });

  test('throws when coordinates are out of range', () {
    final service = NominatimGeocodingService();

    expect(
      service.resolve('-132, -60'),
      throwsA(isA<GeocodingException>()),
    );
  });
}
