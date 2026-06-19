import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/config/app_config.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/ride.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/repositories/mock_ride_repository.dart';
import 'package:goldtaxi_bolt_v2_5/src/models/app_user_role.dart';
import 'package:goldtaxi_bolt_v2_5/src/state/app_state.dart';

void main() {
  test('driver can go online, accept, start and complete ride', () async {
    final repository = MockRideRepository(
      offerTimeout: const Duration(seconds: 5),
      approachTickInterval: const Duration(milliseconds: 1),
      approachProgressPerTick: 1,
    );
    final state = AppState(
      repository: repository,
      config: const AppConfig(),
      userRole: AppUserRole.driver,
    );

    addTearDown(() {
      state.dispose();
      repository.dispose();
    });

    await state.start();
    expect(state.driverOnline, isFalse);
    state.toggleDriverOnline();
    expect(state.driverOnline, isTrue);

    await state.requestRide();
    expect(state.activeRide, isNotNull);
    expect(state.activeRide!.status, RideStatus.searching);
    expect(state.driverOfferSecondsRemaining, 15);

    await state.acceptRideOffer();
    await _waitForRideStatus(state, RideStatus.arrived);

    await state.startRide();
    await _waitForRideStatus(state, RideStatus.inProgress);

    await state.completeRide();
    await _waitForRideStatus(state, RideStatus.completed);

    expect(state.completedTrips, 1);
    expect(state.earningsToday, greaterThan(0));
  });

  test('driver can decline a ride offer and reset countdown when offline',
      () async {
    final repository = MockRideRepository(
      offerTimeout: const Duration(seconds: 5),
      approachTickInterval: const Duration(milliseconds: 1),
      approachProgressPerTick: 1,
    );
    final state = AppState(
      repository: repository,
      config: const AppConfig(),
      userRole: AppUserRole.driver,
    );

    addTearDown(() {
      state.dispose();
      repository.dispose();
    });

    await state.start();
    state.toggleDriverOnline();
    await state.requestRide();
    expect(state.activeRide!.status, RideStatus.searching);
    expect(state.driverOfferSecondsRemaining, 15);

    await state.declineRideOffer();
    await _waitForRideStatus(state, RideStatus.cancelled);
    expect(state.driverOfferSecondsRemaining, 0);

    state.toggleDriverOnline();
    expect(state.driverOnline, isFalse);
    expect(state.driverOfferSecondsRemaining, 0);
  });
}

Future<void> _waitForRideStatus(
  AppState state,
  RideStatus status, {
  Duration timeout = const Duration(milliseconds: 500),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (state.activeRide?.status == status) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail(
    'Timed out waiting for ride status ${status.name}. Current: '
    '${state.activeRide?.status.name}',
  );
}
