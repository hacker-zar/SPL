import '../domain/models/route_info.dart';
import '../domain/services/route_service.dart';

class ManualRouteService implements RouteService {
  @override
  Future<RouteInfo> calculateRoute({
    required String origin,
    required String destination,
  }) {
    throw ManualRouteRequiredException(
      'Configure GOOGLE_MAPS_API_KEY to calculate routes automatically.',
    );
  }
}

class ManualRouteRequiredException implements Exception {
  ManualRouteRequiredException(this.message);

  final String message;
}
