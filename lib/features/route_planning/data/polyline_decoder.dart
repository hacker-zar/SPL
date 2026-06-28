import '../domain/models/lat_lng_value.dart';

class PolylineDecoder {
  static List<LatLngValue> decode(String encoded) {
    final points = <LatLngValue>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      final latResult = _decodeNext(encoded, index);
      index = latResult.nextIndex;
      latitude += latResult.value;

      final lngResult = _decodeNext(encoded, index);
      index = lngResult.nextIndex;
      longitude += lngResult.value;

      points.add(
        LatLngValue(
          latitude: latitude / 1E5,
          longitude: longitude / 1E5,
        ),
      );
    }

    return points;
  }

  static _DecodeResult _decodeNext(String encoded, int startIndex) {
    var index = startIndex;
    var shift = 0;
    var result = 0;
    int byte;

    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    final value = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    return _DecodeResult(value: value, nextIndex: index);
  }
}

class _DecodeResult {
  const _DecodeResult({
    required this.value,
    required this.nextIndex,
  });

  final int value;
  final int nextIndex;
}
