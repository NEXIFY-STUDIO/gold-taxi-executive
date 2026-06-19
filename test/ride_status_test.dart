import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/ride.dart';

void main() {
  group('RideStatus transitions', () {
    test('allows the expected passenger lifecycle', () {
      expect(RideStatus.draft.canTransitionTo(RideStatus.searching), isTrue);
      expect(RideStatus.searching.canTransitionTo(RideStatus.accepted), isTrue);
      expect(
        RideStatus.accepted.canTransitionTo(RideStatus.driverArriving),
        isTrue,
      );
      expect(RideStatus.driverArriving.canTransitionTo(RideStatus.arrived),
          isTrue);
      expect(RideStatus.arrived.canTransitionTo(RideStatus.inProgress), isTrue);
      expect(
          RideStatus.inProgress.canTransitionTo(RideStatus.completed), isTrue);
    });

    test('rejects invalid jumps', () {
      expect(
        () => RideStatus.searching.transitionTo(RideStatus.completed),
        throwsStateError,
      );
      expect(
        () => RideStatus.arrived.transitionTo(RideStatus.accepted),
        throwsStateError,
      );
      expect(
          RideStatus.completed.canTransitionTo(RideStatus.searching), isFalse);
    });
  });
}
