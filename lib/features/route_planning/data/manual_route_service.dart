import '../domain/models/lat_lng_value.dart';
import '../domain/models/route_info.dart';
import '../domain/services/route_service.dart';

class ManualRouteService implements RouteService {
  @override
  Future<RouteInfo> calculateRoute({
    required LatLngValue origin,
    required LatLngValue destination,
    String? originName,
    String? destinationName,
  }) {
    throw ManualRouteRequiredException(
      'No hay servicio de rutas disponible.',
    );
  }

  RouteInfo createRoute({
    required LatLngValue origin,
    required LatLngValue destination,
    required String originName,
    required String destinationName,
    required double distanceKm,
    required double durationMinutes,
  }) =>
      RouteInfo(
        originName: originName,
        destinationName: destinationName,
        origin: origin,
        destination: destination,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
      );
}

class ManualRouteRequiredException implements Exception {
  ManualRouteRequiredException(this.message);

  final String message;
}
