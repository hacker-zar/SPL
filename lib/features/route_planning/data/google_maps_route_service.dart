import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/route_info.dart';
import '../domain/services/route_service.dart';
import 'polyline_decoder.dart';

class GoogleMapsRouteService implements RouteService {
  GoogleMapsRouteService({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  @override
  Future<RouteInfo> calculateRoute({
    required String origin,
    required String destination,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': origin,
        'destination': destination,
        'key': apiKey,
        'units': 'metric',
        'language': 'es',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw RouteException('Google Maps did not return a valid response.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['status'] != 'OK') {
      throw RouteException(payload['error_message'] as String? ??
          'No route was found between those points.');
    }

    final route = (payload['routes'] as List<dynamic>).first;
    final leg = (route['legs'] as List<dynamic>).first as Map<String, dynamic>;
    final distanceMeters = (leg['distance']['value'] as num).toDouble();
    final durationSeconds = (leg['duration']['value'] as num).toDouble();
    final encodedPolyline = route['overview_polyline']['points'] as String?;

    return RouteInfo(
      originName: leg['start_address'] as String? ?? origin,
      destinationName: leg['end_address'] as String? ?? destination,
      distanceKm: distanceMeters / 1000,
      durationMinutes: durationSeconds / 60,
      polyline: encodedPolyline == null
          ? const []
          : PolylineDecoder.decode(encodedPolyline),
    );
  }
}

class RouteException implements Exception {
  RouteException(this.message);

  final String message;

  @override
  String toString() => message;
}
