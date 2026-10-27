import 'dart:math' as math;

class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lng == lng;
  @override
  int get hashCode => Object.hash(lat, lng);

  String get label => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  /// Rough planar distance in degrees, enough to pick the nearest sample place.
  double distanceTo(GeoPoint o) => math.sqrt(math.pow(lat - o.lat, 2) + math.pow(lng - o.lng, 2));
}

/// Address pieces resolved from a place or a coordinate.
class ResolvedPlace {
  const ResolvedPlace({
    required this.point,
    required this.areaLine,
    required this.city,
    required this.state,
    required this.pincode,
  });
  final GeoPoint point;
  final String areaLine;
  final String city;
  final String state;
  final String pincode;

  String get summary => [areaLine, city, state, pincode].where((p) => p.isNotEmpty).join(', ');
}

class PlaceSuggestion {
  const PlaceSuggestion({required this.id, required this.primary, required this.secondary});
  final String id;
  final String primary;
  final String secondary;
}
