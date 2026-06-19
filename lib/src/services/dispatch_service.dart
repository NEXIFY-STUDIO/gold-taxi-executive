import '../data/models/driver.dart';
import '../data/models/location_point.dart';
import '../data/models/vehicle_class.dart';

class DispatchService {
  const DispatchService();

  Driver? pickBestDriver({
    required List<Driver> drivers,
    required LocationPoint pickup,
    required VehicleClass requestedClass,
  }) {
    final eligible = drivers
        .where((driver) =>
            driver.status == DriverStatus.idle &&
            driver.vehicleClass.index >= requestedClass.index)
        .toList();

    if (eligible.isEmpty) return null;

    eligible.sort((a, b) {
      final scoreA = _score(a, pickup, requestedClass);
      final scoreB = _score(b, pickup, requestedClass);
      return scoreA.compareTo(scoreB);
    });

    return eligible.first;
  }

  double _score(
    Driver driver,
    LocationPoint pickup,
    VehicleClass requestedClass,
  ) {
    final distanceKm = driver.location.distanceKmTo(pickup);
    final classPenalty = (driver.vehicleClass.index - requestedClass.index).abs();
    final ratingBonus = (5.0 - driver.rating).clamp(0, 2);
    return distanceKm + classPenalty * 0.35 + ratingBonus * 0.15;
  }
}
