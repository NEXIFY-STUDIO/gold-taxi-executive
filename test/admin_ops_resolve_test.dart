import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/config/app_config.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/ride.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/repositories/mock_ride_repository.dart';
import 'package:goldtaxi_bolt_v2_5/src/models/app_user_role.dart';
import 'package:goldtaxi_bolt_v2_5/src/state/app_state.dart';

void main() {
  test('ops resolve cancels the ride and writes a notice', () async {
    final repository = MockRideRepository(
      offerTimeout: const Duration(seconds: 5),
      approachTickInterval: const Duration(milliseconds: 1),
      approachProgressPerTick: 1,
    );
    final state = AppState(
      repository: repository,
      config: const AppConfig(),
      userRole: AppUserRole.admin,
    );

    addTearDown(() {
      state.dispose();
      repository.dispose();
    });

    await state.start();
    await state.requestRide();
    final ride = state.activeRide;
    expect(ride, isNotNull);
    expect(ride!.status, RideStatus.searching);

    await state.resolveRidePlaceholder(ride);
    await _waitForRideStatus(state, RideStatus.cancelled);

    expect(state.opsNotice, contains('resolved in mock ops state'));
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
