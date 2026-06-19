import 'dart:math';

class LocationPoint {
  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;

  double distanceKmTo(LocationPoint other) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(other.latitude - latitude);
    final dLng = _degToRad(other.longitude - longitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(latitude)) *
            cos(_degToRad(other.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double bearingTo(LocationPoint other) {
    final lat1 = _degToRad(latitude);
    final lat2 = _degToRad(other.latitude);
    final dLng = _degToRad(other.longitude - longitude);
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return (_radToDeg(atan2(y, x)) + 360) % 360;
  }

  LocationPoint interpolateTo(LocationPoint other, double t, {String? label}) {
    final clamped = t.clamp(0.0, 1.0);
    return LocationPoint(
      latitude: latitude + (other.latitude - latitude) * clamped,
      longitude: longitude + (other.longitude - longitude) * clamped,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
      };

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      label: json['label'] as String? ?? 'Unknown location',
    );
  }

  static double _degToRad(double degrees) => degrees * pi / 180.0;
  static double _radToDeg(double radians) => radians * 180.0 / pi;
}
