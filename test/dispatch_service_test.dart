import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/driver.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/location_point.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/vehicle_class.dart';
import 'package:goldtaxi_bolt_v2_5/src/services/dispatch_service.dart';

void main() {
  test('dispatch picks nearest eligible idle driver', () {
    const service = DispatchService();
    const pickup = LocationPoint(
      latitude: 47.3769,
      longitude: 8.5417,
      label: 'Pickup',
    );

    final drivers = [
      const Driver(
        id: 'far',
        name: 'Far',
        vehicleName: 'BMW',
        plateNumber: 'A',
        vehicleClass: VehicleClass.comfort,
        location: LocationPoint(
          latitude: 47.45,
          longitude: 8.55,
          label: 'Far',
        ),
        heading: 0,
        rating: 5,
        status: DriverStatus.idle,
        photoUrl: '',
      ),
      const Driver(
        id: 'near',
        name: 'Near',
        vehicleName: 'Mercedes',
        plateNumber: 'B',
        vehicleClass: VehicleClass.comfort,
        location: LocationPoint(
          latitude: 47.377,
          longitude: 8.542,
          label: 'Near',
        ),
        heading: 0,
        rating: 5,
        status: DriverStatus.idle,
        photoUrl: '',
      ),
    ];

    final driver = service.pickBestDriver(
      drivers: drivers,
      pickup: pickup,
      requestedClass: VehicleClass.comfort,
    );

    expect(driver?.id, 'near');
  });
}
