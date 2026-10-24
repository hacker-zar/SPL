import '../models/lat_lng_value.dart';
import '../models/place_search_result.dart';

abstract class GeocodingService {
  Future<PlaceSearchResult> resolve(String input);

  Future<PlaceSearchResult> reverse(LatLngValue point);
}
