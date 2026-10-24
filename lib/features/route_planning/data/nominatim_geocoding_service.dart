import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/models/lat_lng_value.dart';
import '../domain/models/place_search_result.dart';
import '../domain/services/geocoding_service.dart';

class NominatimGeocodingService implements GeocodingService {
  NominatimGeocodingService({
    this.baseUrl = 'https://nominatim.openstreetmap.org',
    this.contactEmail = '',
    this.minimumRequestInterval = const Duration(seconds: 1),
    Future<void> Function(Duration duration)? delay,
    DateTime Function()? now,
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _delay = delay ?? _defaultDelay,
        _now = now ?? DateTime.now;

  final String baseUrl;
  final String contactEmail;
  final Duration minimumRequestInterval;
  final http.Client _client;
  final Future<void> Function(Duration duration) _delay;
  final DateTime Function() _now;
  final Map<String, PlaceSearchResult> _cache = {};
  final Map<String, PlaceSearchResult> _reverseCache = {};
  Future<void> _requestQueue = Future<void>.value();
  DateTime? _lastRequestAt;
  bool _warnedAboutMissingEmail = false;

  @override
  Future<PlaceSearchResult> resolve(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      throw GeocodingException('Escribí una ubicación o coordenadas.');
    }

    final coordinateResult = _parseCoordinates(query);
    if (coordinateResult != null) {
      return coordinateResult;
    }

    final cacheKey = query.toLowerCase();
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }
    if (contactEmail.trim().isEmpty && !_warnedAboutMissingEmail) {
      _warnedAboutMissingEmail = true;
      debugPrint(
        'Advertencia: configurá NOMINATIM_CONTACT_EMAIL para identificar Netokm.',
      );
    }

    final result = _enqueue(() async {
      final queuedCacheResult = _cache[cacheKey];
      if (queuedCacheResult != null) {
        return queuedCacheResult;
      }

      final response = await _get(Uri.parse('$baseUrl/search').replace(
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'limit': '1',
          'addressdetails': '0',
          if (contactEmail.trim().isNotEmpty) 'email': contactEmail.trim(),
        },
      ));

      if (response.statusCode != 200) {
        throw GeocodingException('No se pudo buscar esa ubicación.');
      }

      final payload = jsonDecode(response.body) as List<dynamic>;
      if (payload.isEmpty) {
        throw GeocodingException('No encontré esa ubicación.');
      }

      final first = payload.first as Map<String, dynamic>;
      final latitude = double.tryParse(first['lat'] as String? ?? '');
      final longitude = double.tryParse(first['lon'] as String? ?? '');
      if (latitude == null || longitude == null) {
        throw GeocodingException(
            'La ubicación encontrada no tiene coordenadas.');
      }

      final result = PlaceSearchResult(
        name: first['display_name'] as String? ?? query,
        point: LatLngValue(latitude: latitude, longitude: longitude),
      );
      _cache[cacheKey] = result;
      return result;
    });
    return result;
  }

  @override
  Future<PlaceSearchResult> reverse(LatLngValue point) async {
    final key = '${point.latitude},${point.longitude}';
    final cached = _reverseCache[key];
    if (cached != null) return cached;
    if (contactEmail.trim().isEmpty && !_warnedAboutMissingEmail) {
      _warnedAboutMissingEmail = true;
      debugPrint(
        'Advertencia: configurá NOMINATIM_CONTACT_EMAIL para identificar Netokm.',
      );
    }
    return _enqueue(() async {
      final queuedCached = _reverseCache[key];
      if (queuedCached != null) return queuedCached;
      final response = await _get(Uri.parse('$baseUrl/reverse').replace(
        queryParameters: {
          'lat': point.latitude.toString(),
          'lon': point.longitude.toString(),
          'format': 'jsonv2',
          if (contactEmail.trim().isNotEmpty) 'email': contactEmail.trim(),
        },
      ));
      if (response.statusCode != 200) {
        throw GeocodingException('No se pudo buscar el nombre del lugar.');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final name = payload['display_name'] as String?;
      if (name == null || name.trim().isEmpty) {
        throw GeocodingException('No se encontró el nombre del lugar.');
      }
      final result = PlaceSearchResult(name: name, point: point);
      _reverseCache[key] = result;
      return result;
    });
  }

  Future<http.Response> _get(Uri uri) async {
    final lastRequestAt = _lastRequestAt;
    if (lastRequestAt != null) {
      final elapsed = _now().difference(lastRequestAt);
      final remaining = minimumRequestInterval - elapsed;
      if (remaining > Duration.zero) await _delay(remaining);
    }
    _lastRequestAt = _now();
    final headers = <String, String>{'Accept': 'application/json'};
    if (!kIsWeb) {
      headers['User-Agent'] = contactEmail.trim().isEmpty
          ? 'Netokm/1.0'
          : 'Netokm/1.0 (${contactEmail.trim()})';
    }
    return _client.get(uri, headers: headers);
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _requestQueue.then((_) => operation());
    _requestQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  static Future<void> _defaultDelay(Duration duration) =>
      Future<void>.delayed(duration);

  PlaceSearchResult? _parseCoordinates(String input) {
    final normalized =
        input.replaceAll(';', ',').replaceAll(RegExp(r'\s+'), ' ').trim();
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
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw GeocodingException('Las coordenadas están fuera de rango.');
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
