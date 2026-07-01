import '../models/place_search_result.dart';

abstract class GeocodingService {
  Future<PlaceSearchResult> resolve(String input);
}
