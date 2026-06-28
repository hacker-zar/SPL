import 'lat_lng_value.dart';

class RouteInfo {
  const RouteInfo({
    required this.originName,
    required this.destinationName,
    required this.distanceKm,
    required this.durationMinutes,
    this.polyline = const [],
  });

  final String originName;
  final String destinationName;
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
      distanceKm: distanceKm * 2,
      durationMinutes: durationMinutes * 2,
      polyline: polyline,
    );
  }

  Map<String, dynamic> toMap() => {
        'originName': originName,
        'destinationName': destinationName,
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
        'polyline': polyline.map((point) => point.toMap()).toList(),
      };

  factory RouteInfo.fromMap(Map<String, dynamic> map) {
    return RouteInfo(
      originName: map['originName'] as String,
      destinationName: map['destinationName'] as String,
      distanceKm: (map['distanceKm'] as num).toDouble(),
      durationMinutes: (map['durationMinutes'] as num).toDouble(),
      polyline: ((map['polyline'] as List<dynamic>?) ?? [])
          .map((item) => LatLngValue.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}
