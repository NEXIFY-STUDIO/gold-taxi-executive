import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../firebase_options.dart';
import '../../models/app_user_role.dart';
import '../../services/auth/auth_gateway.dart';
import '../../services/auth/firebase_auth_gateway.dart';
import '../models/driver.dart';
import '../models/driver_approval.dart';
import '../models/location_point.dart';
import '../models/ride.dart';
import '../models/vehicle_class.dart';

abstract class FirebaseRuntimeGateway {
  Future<void> initialize();

  AppUserRole get userRole;

  AuthProfile? get authProfile;

  Future<AppUserRole> refreshUserProfile();

  Stream<List<Driver>> watchDrivers(LocationPoint center);

  Stream<Ride> watchRide(String rideId);

  Future<Ride> createRide({
    required LocationPoint pickup,
    required LocationPoint dropoff,
    required VehicleClass vehicleClass,
  });

  Future<void> acceptRide(String rideId);

  Future<void> declineRide(String rideId, String reason);

  Future<void> markArrived(String rideId);

  Future<void> startRide(String rideId);

  Future<void> completeRide(String rideId);

  Future<void> cancelRide(String rideId, String reason);

  Future<void> adminCancelRide(String rideId, String reason);

  Future<String> approveDriver(DriverApprovalInput input);

  Future<void> setDriverOnline(bool online);
}

class FirebaseRuntimeGatewayImpl implements FirebaseRuntimeGateway {
  FirebaseRuntimeGatewayImpl({
    GoldTaxiAuthGateway? authGateway,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    this.region = 'europe-west6',
  })  : _authGatewayOverride = authGateway,
        _firestoreOverride = firestore,
        _functionsOverride = functions;

  final GoldTaxiAuthGateway? _authGatewayOverride;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;
  final String region;
  late final GoldTaxiAuthGateway _authGateway;
  late final FirebaseFirestore _firestore;
  late final FirebaseFunctions _functions;
  AppUserRole _userRole = AppUserRole.passenger;
  AuthProfile? _authProfile;
  String? _uid;
  String? _driverId;
  bool _initialized = false;

  @override
  AppUserRole get userRole => _userRole;

  @override
  AuthProfile? get authProfile => _authProfile;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    _firestore = _firestoreOverride ?? FirebaseFirestore.instance;
    _functions =
        _functionsOverride ?? FirebaseFunctions.instanceFor(region: region);
    _authGateway = _authGatewayOverride ??
        FirebaseAuthGateway(functions: _functions, region: region);

    await _loadUserProfile();

    _initialized = true;
  }

  @override
  Future<AppUserRole> refreshUserProfile() async {
    _ensureInitialized();
    await _loadUserProfile();
    return _userRole;
  }

  Future<void> _loadUserProfile() async {
    final profile = await _authGateway.ensureSignedInProfile();
    _authProfile = profile;
    _uid = profile.session.uid;
    _userRole = profile.role;
    _driverId = null;

    if (!_userRole.canAccessDriverTools) {
      return;
    }

    final driverSnap = await _firestore
        .collection('drivers')
        .where('userId', isEqualTo: _uid)
        .limit(1)
        .get();
    if (driverSnap.docs.isNotEmpty) {
      _driverId = driverSnap.docs.first.id;
    }
  }

  @override
  Stream<List<Driver>> watchDrivers(LocationPoint center) {
    _ensureInitialized();
    return _firestore.collection('drivers').snapshots().map((snapshot) {
      final drivers = snapshot.docs
          .map(
            (doc) => Driver.fromJson(<String, dynamic>{
              ...doc.data(),
              'id': doc.id,
            }),
          )
          .toList()
        ..sort((a, b) {
          final aDistance = a.location.distanceKmTo(center);
          final bDistance = b.location.distanceKmTo(center);
          return aDistance.compareTo(bDistance);
        });
      return drivers;
    });
  }

  @override
  Stream<Ride> watchRide(String rideId) {
    _ensureInitialized();
    return _firestore.doc('rides/$rideId').snapshots().asyncMap((snap) async {
      if (!snap.exists) {
        throw StateError('Ride not found.');
      }
      return _mapRide(snap.data()!, snap.id);
    });
  }

  @override
  Future<Ride> createRide({
    required LocationPoint pickup,
    required LocationPoint dropoff,
    required VehicleClass vehicleClass,
  }) async {
    _ensureInitialized();
    final response =
        await _functions.httpsCallable('createRide').call(<String, dynamic>{
      'pickup': pickup.toJson(),
      'dropoff': dropoff.toJson(),
      'vehicleClass': vehicleClass.name,
      'commandId': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    final rideId = data['rideId']?.toString();
    if (rideId == null || rideId.isEmpty) {
      throw StateError('createRide returned no rideId.');
    }
    final rideSnap = await _firestore.doc('rides/$rideId').get();
    if (!rideSnap.exists) {
      return Ride(
        id: rideId,
        pickup: pickup,
        dropoff: dropoff,
        vehicleClass: vehicleClass,
        status: RideStatus.searching,
        estimatedFare: (data['estimatedFare'] as num?)?.toDouble() ?? 0,
        finalFare: null,
        distanceKm: pickup.distanceKmTo(dropoff),
        durationMinutes: 0,
        createdAt: DateTime.now(),
      );
    }
    return _mapRide(rideSnap.data()!, rideSnap.id);
  }

  @override
  Future<void> acceptRide(String rideId) async {
    _ensureInitialized();
    await _functions.httpsCallable('acceptRide').call(<String, dynamic>{
      'rideId': rideId,
      'commandId': DateTime.now().millisecondsSinceEpoch.toString(),
    });
  }

  @override
  Future<void> declineRide(String rideId, String reason) async {
    _ensureInitialized();
    await _functions.httpsCallable('declineRide').call(<String, dynamic>{
      'rideId': rideId,
      'reason': reason,
      'commandId': DateTime.now().millisecondsSinceEpoch.toString(),
    });
  }

  @override
  Future<void> markArrived(String rideId) async {
    _ensureInitialized();
    await _functions.httpsCallable('driverArrived').call(<String, dynamic>{
      'rideId': rideId,
    });
  }

  @override
  Future<void> startRide(String rideId) async {
    _ensureInitialized();
    await _functions.httpsCallable('startRide').call(<String, dynamic>{
      'rideId': rideId,
    });
  }

  @override
  Future<void> completeRide(String rideId) async {
    _ensureInitialized();
    await _functions.httpsCallable('completeRide').call(<String, dynamic>{
      'rideId': rideId,
    });
  }

  @override
  Future<void> cancelRide(String rideId, String reason) async {
    _ensureInitialized();
    await _functions.httpsCallable('cancelRide').call(<String, dynamic>{
      'rideId': rideId,
      'reason': reason,
    });
  }

  @override
  Future<void> adminCancelRide(String rideId, String reason) async {
    _ensureInitialized();
    await _functions.httpsCallable('opsCancelRide').call(<String, dynamic>{
      'rideId': rideId,
      'reason': reason,
    });
  }

  @override
  Future<String> approveDriver(DriverApprovalInput input) async {
    _ensureInitialized();
    final response =
        await _functions.httpsCallable('approveDriver').call(input.toJson());
    final data = Map<String, dynamic>.from(response.data as Map);
    final driverId = data['driverId']?.toString();
    if (driverId == null || driverId.isEmpty) {
      throw StateError('approveDriver returned no driverId.');
    }
    return driverId;
  }

  @override
  Future<void> setDriverOnline(bool online) async {
    _ensureInitialized();
    if (!_userRole.canAccessDriverTools) {
      throw StateError('Driver role required to change driver availability.');
    }
    await _functions.httpsCallable('setDriverOnline').call(<String, dynamic>{
      'online': online,
      'driverId': _driverId,
    });
  }

  Future<Ride> _mapRide(Map<String, dynamic> data, String rideId) async {
    final pickup = _readLocation(
      data['pickup'],
      fallbackLabel: 'Pickup',
    );
    final dropoff = _readLocation(
      data['dropoff'],
      fallbackLabel: 'Dropoff',
    );
    final driverId = data['driverId']?.toString();
    Driver? driver;
    if (driverId != null && driverId.isNotEmpty) {
      final driverSnap = await _firestore.doc('drivers/$driverId').get();
      if (driverSnap.exists) {
        driver = Driver.fromJson(<String, dynamic>{
          ...driverSnap.data()!,
          'id': driverSnap.id,
        });
      }
    }

    return Ride(
      id: rideId,
      pickup: pickup,
      dropoff: dropoff,
      vehicleClass: _parseVehicleClass(data['vehicleClass']),
      status: _parseRideStatus(data['status']),
      estimatedFare: _readDouble(data['estimatedFare']),
      finalFare: _readNullableDouble(data['finalFare']),
      distanceKm: _readDouble(data['distanceKm']),
      durationMinutes: _readInt(data['durationMinutes']),
      createdAt: _readDateTime(data['createdAt']) ?? DateTime.now(),
      driver: driver,
      waitMinutes: _readInt(data['waitMinutes']),
      surgeMultiplier: _readDouble(data['surgeMultiplier'], defaultValue: 1.0),
    );
  }

  LocationPoint _readLocation(
    Object? value, {
    required String fallbackLabel,
  }) {
    if (value is Map<String, dynamic>) {
      return LocationPoint(
        latitude: _readDouble(value['latitude']),
        longitude: _readDouble(value['longitude']),
        label: value['label']?.toString() ?? fallbackLabel,
      );
    }
    return LocationPoint(
      latitude: 47.3769,
      longitude: 8.5417,
      label: fallbackLabel,
    );
  }

  RideStatus _parseRideStatus(Object? value) {
    return RideStatus.values.firstWhere(
      (status) => status.name == value?.toString(),
      orElse: () => RideStatus.searching,
    );
  }

  VehicleClass _parseVehicleClass(Object? value) {
    return VehicleClass.values.firstWhere(
      (status) => status.name == value?.toString(),
      orElse: () => VehicleClass.standard,
    );
  }

  double _readDouble(Object? value, {double defaultValue = 0}) {
    return value is num ? value.toDouble() : defaultValue;
  }

  double? _readNullableDouble(Object? value) {
    return value is num ? value.toDouble() : null;
  }

  int _readInt(Object? value, {int defaultValue = 0}) {
    return value is num ? value.toInt() : defaultValue;
  }

  DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Firebase runtime has not finished initialization.');
    }
  }
}
