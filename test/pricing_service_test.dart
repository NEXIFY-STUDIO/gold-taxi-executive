import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/location_point.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/vehicle_class.dart';
import 'package:goldtaxi_bolt_v2_5/src/services/pricing_service.dart';

void main() {
  group('PricingService', () {
    test('returns minimum fare for very short standard ride', () {
      const service = PricingService();
      final estimate = service.estimate(
        pickup: const LocationPoint(
          latitude: 47.3769,
          longitude: 8.5417,
          label: 'A',
        ),
        dropoff: const LocationPoint(
          latitude: 47.3770,
          longitude: 8.5418,
          label: 'B',
        ),
        vehicleClass: VehicleClass.standard,
      );

      expect(estimate.amount, VehicleClass.standard.minimumFare);
    });

    test('premium is more expensive than standard', () {
      const service = PricingService();
      const pickup = LocationPoint(
        latitude: 47.3769,
        longitude: 8.5417,
        label: 'Zürich HB',
      );
      const dropoff = LocationPoint(
        latitude: 47.4581,
        longitude: 8.5555,
        label: 'Zürich Airport',
      );

      final standard = service.estimate(
        pickup: pickup,
        dropoff: dropoff,
        vehicleClass: VehicleClass.standard,
      );

      final premium = service.estimate(
        pickup: pickup,
        dropoff: dropoff,
        vehicleClass: VehicleClass.premium,
      );

      expect(premium.amount, greaterThan(standard.amount));
    });
  });
}
