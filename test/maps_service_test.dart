import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/location_point.dart';
import 'package:goldtaxi_bolt_v2_5/src/services/maps/maps_service.dart';

void main() {
  test('mock maps service returns Zurich suggestions', () async {
    const service = MockMapsService();

    final suggestions = await service.autocomplete('zürich').first;

    expect(suggestions, isNotEmpty);
    expect(suggestions.first.location, isA<LocationPoint>());
    expect(suggestions.first.primaryText, contains('Zürich'));
  });

  test('mock maps service returns route polyline between points', () async {
    const service = MockMapsService();

    final route = await service.routeBetween(
      const LocationPoint(
        latitude: 47.3769,
        longitude: 8.5417,
        label: 'Zürich HB',
      ),
      const LocationPoint(
        latitude: 47.4581,
        longitude: 8.5555,
        label: 'Zürich Airport',
      ),
    );

    expect(route.points.length, greaterThan(2));
    expect(route.distanceKm, greaterThan(0));
    expect(route.durationMinutes, greaterThan(0));
  });

  test('browser-safe Google maps service avoids direct REST calls', () async {
    const service = BrowserSafeGoogleMapsService();

    expect(service.providerName, 'Google Maps');
    expect(await service.autocomplete('airport').first, isNotEmpty);

    final route = await service.routeBetween(
      const LocationPoint(
        latitude: 47.3769,
        longitude: 8.5417,
        label: 'Zürich HB',
      ),
      const LocationPoint(
        latitude: 47.4581,
        longitude: 8.5555,
        label: 'Zürich Airport',
      ),
    );

    expect(route.distanceKm, greaterThan(0));
    expect(route.durationMinutes, greaterThan(0));
  });
}
