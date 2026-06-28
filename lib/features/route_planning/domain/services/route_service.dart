import '../models/lat_lng_value.dart';
import '../models/route_info.dart';

abstract class RouteService {
  Future<RouteInfo> calculateRoute({
    required LatLngValue origin,
    required LatLngValue destination,
  });
}
