import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/lat_lng_value.dart';
import '../domain/models/place_search_result.dart';
import '../domain/services/geocoding_service.dart';

class NominatimGeocodingService implements GeocodingService {
  NominatimGeocodingService({
    this.baseUrl = 'https://nominatim.openstreetmap.org',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<PlaceSearchResult> resolve(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      throw GeocodingException('Escribi una ubicacion o coordenadas.');
    }

    final coordinateResult = _parseCoordinates(query);
    if (coordinateResult != null) {
      return coordinateResult;
    }

    final uri = Uri.parse('$baseUrl/search').replace(
      queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'limit': '1',
        'addressdetails': '0',
      },
    );
    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'rentabilidad-flete/0.1 contact:local-dev',
      },
    );

    if (response.statusCode != 200) {
      throw GeocodingException('No se pudo buscar esa ubicacion.');
    }

    final payload = jsonDecode(response.body) as List<dynamic>;
    if (payload.isEmpty) {
      throw GeocodingException('No encontre esa ubicacion.');
    }

    final first = payload.first as Map<String, dynamic>;
    final latitude = double.tryParse(first['lat'] as String? ?? '');
    final longitude = double.tryParse(first['lon'] as String? ?? '');
    if (latitude == null || longitude == null) {
      throw GeocodingException('La ubicacion encontrada no tiene coordenadas.');
    }

    return PlaceSearchResult(
      name: first['display_name'] as String? ?? query,
      point: LatLngValue(latitude: latitude, longitude: longitude),
    );
  }

  PlaceSearchResult? _parseCoordinates(String input) {
    final normalized = input
        .replaceAll(';', ',')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final commaParts = normalized.split(',');
    final parts = commaParts.length == 2
        ? commaParts.map((part) => part.trim()).toList()
        : normalized.split(' ');
    if (parts.length != 2) {
      return null;
    }

    final latitude = double.tryParse(parts[0]);
    final longitude = double.tryParse(parts[1]);
    if (latitude == null || longitude == null) {
      return null;
    }
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw GeocodingException('Las coordenadas estan fuera de rango.');
    }

    return PlaceSearchResult(
      name: '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      point: LatLngValue(latitude: latitude, longitude: longitude),
    );
  }
}

class GeocodingException implements Exception {
  GeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}
