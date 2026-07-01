import 'lat_lng_value.dart';

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.name,
    required this.point,
  });

  final String name;
  final LatLngValue point;
}
