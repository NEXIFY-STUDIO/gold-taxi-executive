import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/config/app_config.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/driver.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/location_point.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/ride.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/vehicle_class.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/repositories/ride_repository.dart';
import 'package:goldtaxi_bolt_v2_5/src/models/app_user_role.dart';
import 'package:goldtaxi_bolt_v2_5/src/services/auth/auth_gateway.dart';
import 'package:goldtaxi_bolt_v2_5/src/services/push/client_profile_repository.dart';
import 'package:goldtaxi_bolt_v2_5/src/services/push/push_notification_service.dart';
import 'package:goldtaxi_bolt_v2_5/src/state/app_state.dart';
import 'package:goldtaxi_bolt_v2_5/src/ui/screens/app_shell.dart';

void main() {
  testWidgets('passenger sees only passenger navigation', (tester) async {
    final harness = await _pumpShell(
      tester,
      role: AppUserRole.passenger,
    );

    addTearDown(harness.dispose);

    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.text('Driver'), findsNothing);
    expect(find.text('Ops'), findsNothing);
    expect(find.text('Book your ride'), findsOneWidget);
  });

  testWidgets('passenger auth panel offers Google without privileged tabs',
      (tester) async {
    final harness = await _pumpShell(
      tester,
      role: AppUserRole.passenger,
      authGateway: _ShellAuthGateway(),
    );

    addTearDown(harness.dispose);

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Driver'), findsNothing);
    expect(find.text('Ops'), findsNothing);
  });

  testWidgets('driver sees driver navigation but not ops', (tester) async {
    final harness = await _pumpShell(
      tester,
      role: AppUserRole.driver,
    );

    addTearDown(harness.dispose);

    expect(find.text('Passenger'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Ops'), findsNothing);

    await tester.tap(find.text('Driver'));
    await tester.pumpAndSettle();

    expect(find.text('Driver shift'), findsOneWidget);
  });

  testWidgets('admin sees ops navigation but not driver', (tester) async {
    final harness = await _pumpShell(
      tester,
      role: AppUserRole.admin,
    );

    addTearDown(harness.dispose);

    expect(find.text('Passenger'), findsOneWidget);
    expect(find.text('Driver'), findsNothing);
    expect(find.text('Ops'), findsOneWidget);

    await tester.tap(find.text('Ops'));
    await tester.pumpAndSettle();

    expect(find.text('Live operations'), findsOneWidget);
  });
}

Future<_ShellHarness> _pumpShell(
  WidgetTester tester, {
  required AppUserRole role,
  GoldTaxiAuthGateway? authGateway,
}) async {
  final repository = _ShellRideRepository();
  final state = AppState(
    repository: repository,
    config: const AppConfig(),
    userRole: role,
    authGateway: authGateway,
    authProfile: authGateway?.currentProfile,
  );
  final pushService = PushNotificationService(
    messagingClient: const NoopPushMessagingClient(),
    profileRepository: const NoopClientProfileRepository(),
    scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
    onOpenNotification: (_) {},
  );
  await state.start();

  await tester.pumpWidget(
    MaterialApp(
      home: PushScope(
        state: pushService,
        child: AppStateScope(
          state: state,
          child: const AppShell(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _ShellHarness(
    repository: repository,
    state: state,
    pushService: pushService,
  );
}

class _ShellHarness {
  const _ShellHarness({
    required this.repository,
    required this.state,
    required this.pushService,
  });

  final _ShellRideRepository repository;
  final AppState state;
  final PushNotificationService pushService;

  void dispose() {
    pushService.dispose();
    state.dispose();
    repository.dispose();
  }
}

class _ShellAuthGateway implements GoldTaxiAuthGateway {
  static const _profile = AuthProfile(
    session: AuthSession(
      uid: 'passenger-user',
      provider: AuthProviderKind.guest,
      displayName: 'GoldTaxi Passenger',
    ),
    role: AppUserRole.passenger,
  );

  @override
  bool get supportsGoogleSignIn => true;

  @override
  AuthProfile? get currentProfile => _profile;

  @override
  Future<AuthProfile> ensureSignedInProfile() async => _profile;

  @override
  Future<AuthProfile> signInWithGoogle() async => _profile;

  @override
  Future<AuthProfile> signOutToGuest() async => _profile;
}

class _ShellRideRepository implements RideRepository {
  final _driversController = StreamController<List<Driver>>.broadcast()
    ..add(const []);

  @override
  Stream<List<Driver>> nearbyDrivers(LocationPoint center) {
    return _driversController.stream;
  }

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
