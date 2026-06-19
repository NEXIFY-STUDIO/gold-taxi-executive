import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/config/brand_config.dart';

void main() {
  test('BrandConfig falls back to GoldTaxi labels when values are blank', () {
    const brand = BrandConfig(
      name: ' ',
      operatorLabel: '',
      marketLabel: '   ',
      poweredBy: '',
    );

    expect(brand.displayName, 'GoldTaxi');
    expect(brand.displayOperatorLabel, 'Private chauffeur platform');
    expect(brand.displayMarketLabel, 'Swiss premium mobility');
    expect(brand.displayPoweredBy, 'Powered by GoldTaxi');
    expect(brand.appTitle, 'GoldTaxi · Premium Mobility');
  });
}
