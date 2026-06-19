import '../../models/app_user_role.dart';
import '../../services/auth/auth_gateway.dart';
import '../models/driver.dart';
import '../models/location_point.dart';
import '../models/ride.dart';
import '../models/vehicle_class.dart';
import 'firebase_runtime_gateway.dart';
import 'ride_repository.dart';

class FirebaseRideRepository implements RideRepository {
  FirebaseRideRepository({
    FirebaseRuntimeGateway? gateway,
    GoldTaxiAuthGateway? authGateway,
  }) : _gateway =
            gateway ?? FirebaseRuntimeGatewayImpl(authGateway: authGateway);

  final FirebaseRuntimeGateway _gateway;

  Future<void> initialize() => _gateway.initialize();

  AppUserRole get userRole => _gateway.userRole;

  AuthProfile? get authProfile => _gateway.authProfile;

  Future<AppUserRole> refreshUserProfile() => _gateway.refreshUserProfile();

  @override
  Stream<List<Driver>> nearbyDrivers(LocationPoint center) {
    return _gateway.watchDrivers(center);
  }

  @override
  Future<Ride> createRide({
    required LocationPoint pickup,
    required LocationPoint dropoff,
    required VehicleClass vehicleClass,
  }) {
    return _gateway.createRide(
      pickup: pickup,
      dropoff: dropoff,
      vehicleClass: vehicleClass,
    );
  }

  @override
  Stream<Ride> watchRide(String rideId) => _gateway.watchRide(rideId);

  @override
  Future<void> acceptRide(String rideId) => _gateway.acceptRide(rideId);

  @override
  Future<void> declineRide(String rideId, String reason) =>
      _gateway.declineRide(rideId, reason);

  @override
  Future<void> markArrived(String rideId) => _gateway.markArrived(rideId);

  @override
  Future<void> startRide(String rideId) => _gateway.startRide(rideId);

  @override
  Future<void> completeRide(String rideId) => _gateway.completeRide(rideId);

  @override
  Future<void> cancelRide(String rideId, String reason) =>
      _gateway.cancelRide(rideId, reason);

  @override
  Future<void> adminCancelRide(String rideId, String reason) =>
      _gateway.adminCancelRide(rideId, reason);

  @override
  Future<void> setDriverOnline(bool online) => _gateway.setDriverOnline(online);

  @override
  void dispose() {}
}
