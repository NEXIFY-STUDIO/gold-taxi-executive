import '../models/driver.dart';
import '../models/driver_approval.dart';
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

  Future<String> submitDriverApplication(DriverApplicationInput input) =>
      throw UnimplementedError('Driver applications are not available.');

  Future<List<DriverApplication>> loadDriverApplications() async => const [];

  Future<String> approveDriverApplication(String applicationId) =>
      throw UnimplementedError('Driver request approval is not available.');

  Future<void> rejectDriverApplication(
    String applicationId,
    String reason,
  ) async {
    throw UnimplementedError('Driver request rejection is not available.');
  }

  Future<String> approveDriver(DriverApprovalInput input) =>
      throw UnimplementedError('Admin driver provisioning is not available.');

  Future<void> setDriverOnline(bool online) async {}

  void dispose() {}
}
