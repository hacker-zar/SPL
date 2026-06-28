import '../domain/models/lat_lng_value.dart';
import '../domain/models/route_info.dart';
import '../domain/services/route_service.dart';

class ManualRouteService implements RouteService {
  @override
  Future<RouteInfo> calculateRoute({
    required LatLngValue origin,
    required LatLngValue destination,
  }) {
    throw ManualRouteRequiredException(
      'No hay servicio de rutas disponible.',
    );
  }
}

class ManualRouteRequiredException implements Exception {
  ManualRouteRequiredException(this.message);

  final String message;
}
