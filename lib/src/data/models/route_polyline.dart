import 'location_point.dart';

class RoutePolyline {
  const RoutePolyline({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });

  final List<LocationPoint> points;
  final double distanceKm;
  final int durationMinutes;
}
