import 'lat_lng_value.dart';

class RouteInfo {
  const RouteInfo({
    required this.originName,
    required this.destinationName,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.durationMinutes,
    this.polyline = const [],
  });

  final String originName;
  final String destinationName;
  final LatLngValue origin;
  final LatLngValue destination;
  final double distanceKm;
  final double durationMinutes;
  final List<LatLngValue> polyline;

  double get durationDays {
    final days = durationMinutes / (60 * 24);
    return days < 1 ? 1 : days;
  }

  RouteInfo withEmptyReturn() {
    return RouteInfo(
      originName: originName,
      destinationName: destinationName,
      origin: origin,
      destination: destination,
      distanceKm: distanceKm * 2,
      durationMinutes: durationMinutes * 2,
      polyline: polyline,
    );
  }

  Map<String, dynamic> toMap() => {
        'originName': originName,
        'destinationName': destinationName,
        'origin': origin.toMap(),
        'destination': destination.toMap(),
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
        'polyline': polyline.map((point) => point.toMap()).toList(),
      };

  factory RouteInfo.fromMap(Map<String, dynamic> map) {
    final polyline = ((map['polyline'] as List<dynamic>?) ?? [])
        .map((item) => LatLngValue.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    final originMap = map['origin'] as Map<String, dynamic>?;
    final destinationMap = map['destination'] as Map<String, dynamic>?;
    const fallbackPoint = LatLngValue(latitude: 0, longitude: 0);
    return RouteInfo(
      originName: map['originName'] as String,
      destinationName: map['destinationName'] as String,
      origin: originMap == null
          ? (polyline.isEmpty ? fallbackPoint : polyline.first)
          : LatLngValue.fromMap(Map<String, dynamic>.from(originMap)),
      destination: destinationMap == null
          ? (polyline.isEmpty ? fallbackPoint : polyline.last)
          : LatLngValue.fromMap(Map<String, dynamic>.from(destinationMap)),
      distanceKm: (map['distanceKm'] as num).toDouble(),
      durationMinutes: (map['durationMinutes'] as num).toDouble(),
      polyline: polyline,
    );
  }
}
