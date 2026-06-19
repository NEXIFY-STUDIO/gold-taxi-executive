import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/config/app_config.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/driver.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/location_point.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/ride.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/vehicle_class.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/repositories/ride_repository.dart';
import 'package:goldtaxi_bolt_v2_5/src/models/app_user_role.dart';
import 'package:goldtaxi_bolt_v2_5/src/services/auth/auth_gateway.dart';
import 'package:goldtaxi_bolt_v2_5/src/state/app_state.dart';

void main() {
  test('Google sign-in keeps new users in passenger role', () async {
    final authGateway = _FakeAuthGateway();
    final repository = _AuthFlowRideRepository();
    final state = AppState(
      repository: repository,
      config: const AppConfig(),
      authGateway: authGateway,
      refreshUserRole: () async => authGateway.currentProfile!.role,
    );

    addTearDown(() {
      state.dispose();
      repository.dispose();
    });

    await state.start();
    await state.signInWithGoogle();

    expect(authGateway.googleSignInCalls, 1);
    expect(state.isGuestSession, isFalse);
    expect(state.userRole, AppUserRole.passenger);
    expect(state.canAccessDriverConsole, isFalse);
    expect(state.canAccessOpsConsole, isFalse);
  });

  test('guest fallback resets account state without privileged role', () async {
    final authGateway = _FakeAuthGateway(
      initialProfile: _FakeAuthGateway.googleProfile,
    );
    final repository = _AuthFlowRideRepository();
    final state = AppState(
      repository: repository,
      config: const AppConfig(),
      authGateway: authGateway,
      authProfile: authGateway.currentProfile,
      userRole: AppUserRole.passenger,
      refreshUserRole: () async => authGateway.currentProfile!.role,
    );

    addTearDown(() {
      state.dispose();
      repository.dispose();
    });

    await state.start();
    await state.continueAsGuest();

    expect(authGateway.signOutCalls, 1);
    expect(state.isGuestSession, isTrue);
    expect(state.userRole, AppUserRole.passenger);
    expect(state.visibleShellIndices, [0]);
  });
}

class _FakeAuthGateway implements GoldTaxiAuthGateway {
  _FakeAuthGateway({
    AuthProfile? initialProfile,
  }) : _profile = initialProfile ?? guestProfile;

  static const guestProfile = AuthProfile(
    session: AuthSession(
      uid: 'guest-user',
      provider: AuthProviderKind.guest,
      displayName: 'GoldTaxi Passenger',
    ),
    role: AppUserRole.passenger,
  );

  static const googleProfile = AuthProfile(
    session: AuthSession(
      uid: 'google-user',
      provider: AuthProviderKind.google,
      displayName: 'Erik Passenger',
      email: 'erik@example.com',
    ),
    role: AppUserRole.passenger,
  );

  AuthProfile _profile;
  int googleSignInCalls = 0;
  int signOutCalls = 0;

  @override
  bool get supportsGoogleSignIn => true;

  @override
  AuthProfile? get currentProfile => _profile;

  @override
  Future<AuthProfile> ensureSignedInProfile() async => _profile;

  @override
  Future<AuthProfile> signInWithGoogle() async {
    googleSignInCalls += 1;
    _profile = googleProfile;
    return _profile;
  }

  @override
  Future<AuthProfile> signOutToGuest() async {
    signOutCalls += 1;
    _profile = guestProfile;
    return _profile;
  }
}

class _AuthFlowRideRepository implements RideRepository {
  final _driversController = StreamController<List<Driver>>.broadcast()
    ..add(const []);

  @override
  Stream<List<Driver>> nearbyDrivers(LocationPoint center) =>
      _driversController.stream;

  @override
  Future<Ride> createRide({
    required LocationPoint pickup,
    required LocationPoint dropoff,
    required VehicleClass vehicleClass,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<Ride> watchRide(String rideId) => const Stream<Ride>.empty();

  @override
  Future<void> acceptRide(String rideId) async {}

  @override
  Future<void> declineRide(String rideId, String reason) async {}

  @override
  Future<void> markArrived(String rideId) async {}

  @override
  Future<void> startRide(String rideId) async {}

  @override
  Future<void> completeRide(String rideId) async {}

  @override
  Future<void> cancelRide(String rideId, String reason) async {}

  @override
  Future<void> adminCancelRide(String rideId, String reason) async {}

  @override
  Future<void> setDriverOnline(bool online) async {}

  @override
  void dispose() {
    _driversController.close();
  }
}
