import 'package:flutter/material.dart';

import '../../data/models/driver.dart';
import '../../data/models/location_point.dart';
import '../../data/models/ride.dart';
import '../../data/models/route_polyline.dart';
import '../../theme/app_theme.dart';

class MockMap extends StatelessWidget {
  const MockMap({
    super.key,
    required this.drivers,
    required this.pickup,
    required this.dropoff,
    this.ride,
    this.route,
  });

  final List<Driver> drivers;
  final LocationPoint pickup;
  final LocationPoint dropoff;
  final Ride? ride;
  final RoutePolyline? route;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final activeDriver = ride?.driver;
        final mapDrivers = [
          ...drivers.where((driver) => driver.id != activeDriver?.id),
          if (activeDriver != null) activeDriver,
        ];

        return Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _MapPainter(route: route),
            ),
            Positioned(
              left: 26,
              top: 120,
              child: _MapBadge(
                icon: Icons.radio_button_checked,
                label: pickup.label,
                color: AppTheme.gold,
              ),
            ),
            Positioned(
              right: 26,
              top: 210,
              child: _MapBadge(
                icon: Icons.flag_rounded,
                label: dropoff.label,
                color: Colors.white,
              ),
            ),
            for (final driver in mapDrivers)
              _DriverMarker(
                driver: driver,
                isActive: driver.id == activeDriver?.id,
              ),
          ],
        );
      },
    );
  }
}

class _DriverMarker extends StatelessWidget {
  const _DriverMarker({
    required this.driver,
    required this.isActive,
  });

  final Driver driver;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final hash = driver.id.hashCode.abs();
    final left = 42.0 + (hash % 260);
    final top = 150.0 + (hash % 370);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      left: left + (driver.location.longitude * 1000 % 60),
      top: top + (driver.location.latitude * 1000 % 60),
      child: AnimatedRotation(
        duration: const Duration(milliseconds: 650),
        turns: driver.heading / 360,
        child: Container(
          width: isActive ? 46 : 38,
          height: isActive ? 46 : 38,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.gold : const Color(0xFF1D1B13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? AppTheme.goldBright : Colors.white24,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? AppTheme.gold.withValues(alpha: .45)
                    : Colors.black.withValues(alpha: .3),
                blurRadius: isActive ? 24 : 10,
              ),
            ],
          ),
          child: Icon(
            Icons.local_taxi_rounded,
            color: isActive ? Colors.black : Colors.white,
            size: isActive ? 28 : 22,
          ),
        ),
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({this.route});

  final RoutePolyline? route;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF14140F),
          Color(0xFF070706),
          Color(0xFF201D12),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, bg);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..strokeWidth = 1;

    for (var x = -size.width; x < size.width * 2; x += 54) {
      canvas.drawLine(Offset(x.toDouble(), 0),
          Offset(x + size.height, size.height), gridPaint);
    }

    for (var y = 0; y < size.height; y += 80) {
      canvas.drawLine(
          Offset(0, y.toDouble()), Offset(size.width, y + 80), gridPaint);
    }

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: .12)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadAccent = Paint()
      ..color = AppTheme.gold.withValues(alpha: .18)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(20, size.height * .25)
      ..cubicTo(size.width * .25, size.height * .18, size.width * .36,
          size.height * .5, size.width * .58, size.height * .43)
      ..cubicTo(size.width * .82, size.height * .36, size.width * .7,
          size.height * .82, size.width - 10, size.height * .72);

    canvas.drawPath(path, roadPaint);
    canvas.drawPath(path, roadAccent);

    if (route != null && route!.points.length > 1) {
      final polylinePaint = Paint()
        ..color = AppTheme.goldBright.withValues(alpha: .35)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final polylineCore = Paint()
        ..color = AppTheme.gold
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final bounds = _bounds(route!.points);
      final routePath = Path();
      for (var i = 0; i < route!.points.length; i++) {
        final point = route!.points[i];
        final offset = _project(point, bounds, size);
        if (i == 0) {
          routePath.moveTo(offset.dx, offset.dy);
        } else {
          routePath.lineTo(offset.dx, offset.dy);
        }
      }

      canvas.drawPath(routePath, polylinePaint);
      canvas.drawPath(routePath, polylineCore);
    }

    final verticalRoad = Paint()
      ..color = Colors.white.withValues(alpha: .08)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * .22, 0),
      Offset(size.width * .34, size.height),
      verticalRoad,
    );

    canvas.drawLine(
      Offset(size.width * .78, 0),
      Offset(size.width * .62, size.height),
      verticalRoad,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) {
    return oldDelegate.route != route;
  }

  _RouteBounds _bounds(List<LocationPoint> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    return _RouteBounds(minLat, maxLat, minLng, maxLng);
  }

  Offset _project(LocationPoint point, _RouteBounds bounds, Size size) {
    final width = size.width - 80;
    final height = size.height - 120;
    final dx = bounds.maxLng == bounds.minLng
        ? 0.5
        : (point.longitude - bounds.minLng) / (bounds.maxLng - bounds.minLng);
    final dy = bounds.maxLat == bounds.minLat
        ? 0.5
        : (point.latitude - bounds.minLat) / (bounds.maxLat - bounds.minLat);
    return Offset(40 + dx * width, 60 + (1 - dy) * height);
  }
}

class _RouteBounds {
  _RouteBounds(this.minLat, this.maxLat, this.minLng, this.maxLng);

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
}
