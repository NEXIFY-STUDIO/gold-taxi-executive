import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/config/maps_config.dart';

void main() {
  test('defaults to Google Maps for MVP', () {
    const config = MapsConfig();

    expect(config.isGoogleMaps, isTrue);
    expect(config.provider, MapsProvider.googleMaps);
    expect(config.recommendedApiKeyRestrictions, isNotEmpty);
  });
}
