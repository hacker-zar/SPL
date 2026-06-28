import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/lat_lng_value.dart';
import '../domain/models/route_info.dart';
import '../domain/services/route_service.dart';

class OsrmRouteService implements RouteService {
  OsrmRouteService({
    this.baseUrl = 'https://router.project-osrm.org',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<RouteInfo> calculateRoute({
    required LatLngValue origin,
    required LatLngValue destination,
  }) async {
    final coordinates =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.parse('$baseUrl/route/v1/driving/$coordinates').replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw RouteException('No se pudo calcular la ruta con OSRM.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['code'] != 'Ok') {
      throw RouteException(
        payload['message'] as String? ??
            'OSRM no encontro una ruta para esos puntos.',
      );
    }

    final route = (payload['routes'] as List<dynamic>).first
        as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinatesList = geometry['coordinates'] as List<dynamic>;
    final polyline = coordinatesList
        .map((item) {
          final pair = item as List<dynamic>;
          return LatLngValue(
            latitude: (pair[1] as num).toDouble(),
            longitude: (pair[0] as num).toDouble(),
          );
        })
        .toList();

    return RouteInfo(
      originName: _formatPoint(origin),
      destinationName: _formatPoint(destination),
      origin: origin,
      destination: destination,
      distanceKm: (route['distance'] as num).toDouble() / 1000,
      durationMinutes: (route['duration'] as num).toDouble() / 60,
      polyline: polyline,
    );
  }

  String _formatPoint(LatLngValue point) {
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }
}

class RouteException implements Exception {
  RouteException(this.message);

  final String message;

  @override
  String toString() => message;
}
