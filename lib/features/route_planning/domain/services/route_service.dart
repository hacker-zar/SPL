import '../models/route_info.dart';

abstract class RouteService {
  Future<RouteInfo> calculateRoute({
    required String origin,
    required String destination,
  });
}
