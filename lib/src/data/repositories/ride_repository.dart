import '../models/driver.dart';
import '../models/location_point.dart';
import '../models/ride.dart';
import '../models/vehicle_class.dart';

abstract class RideRepository {
  Stream<List<Driver>> nearbyDrivers(LocationPoint center);

  Future<Ride> createRide({
    required LocationPoint pickup,
    required LocationPoint dropoff,
    required VehicleClass vehicleClass,
  });

  Stream<Ride> watchRide(String rideId);

  Future<void> acceptRide(String rideId);

  Future<void> declineRide(String rideId, String reason);

  Future<void> markArrived(String rideId);

  Future<void> startRide(String rideId);

  Future<void> completeRide(String rideId);

  Future<void> cancelRide(String rideId, String reason);

  Future<void> adminCancelRide(String rideId, String reason) =>
      cancelRide(rideId, reason);

  Future<void> setDriverOnline(bool online) async {}

  void dispose() {}
}
