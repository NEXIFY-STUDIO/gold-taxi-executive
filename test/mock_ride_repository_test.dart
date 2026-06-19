import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/location_point.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/ride.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/vehicle_class.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/repositories/mock_ride_repository.dart';

void main() {
  group('MockRideRepository lifecycle', () {
    test('runs the full passenger flow in order', () async {
      final repository = MockRideRepository(
        offerTimeout: const Duration(milliseconds: 1),
        approachTickInterval: const Duration(milliseconds: 1),
        approachProgressPerTick: 1,
      );
      addTearDown(repository.dispose);

      final ride = await repository.createRide(
        pickup: const LocationPoint(
          latitude: 47.3769,
          longitude: 8.5417,
          label: 'Zürich HB',
        ),
        dropoff: const LocationPoint(
          latitude: 47.4581,
          longitude: 8.5555,
          label: 'Zürich Airport',
        ),
        vehicleClass: VehicleClass.comfort,
      );

      expect(ride.status, RideStatus.searching);

      final events = <Ride>[];
      final sub = repository.watchRide(ride.id).listen(events.add);
      addTearDown(sub.cancel);

      await repository.acceptRide(ride.id);
      await _waitForStatus(events, RideStatus.accepted);
      await _waitForStatus(events, RideStatus.driverArriving);
      await _waitForStatus(events, RideStatus.arrived);

      expect(events.any((item) => item.status == RideStatus.accepted), isTrue);
      expect(
        events.any((item) => item.status == RideStatus.driverArriving),
        isTrue,
      );
      final acceptedIndex =
          events.indexWhere((item) => item.status == RideStatus.accepted);
      final arrivingIndex =
          events.indexWhere((item) => item.status == RideStatus.driverArriving);
      final arrivedIndex =
          events.indexWhere((item) => item.status == RideStatus.arrived);
      expect(acceptedIndex, isNonNegative);
      expect(arrivingIndex, greaterThan(acceptedIndex));
      expect(arrivedIndex, greaterThan(arrivingIndex));

      await repository.startRide(ride.id);
      await _waitForStatus(events, RideStatus.inProgress);

      await repository.completeRide(ride.id);
      await _waitForStatus(events, RideStatus.completed);
      final completedRide =
          events.firstWhere((item) => item.status == RideStatus.completed);
      expect(completedRide.finalFare, isNotNull);
    });

    test('rejects invalid lifecycle jumps', () async {
      final repository = MockRideRepository(
        offerTimeout: const Duration(milliseconds: 1),
        approachTickInterval: const Duration(milliseconds: 1),
        approachProgressPerTick: 1,
      );
      addTearDown(repository.dispose);

      final ride = await repository.createRide(
        pickup: const LocationPoint(
          latitude: 47.3769,
          longitude: 8.5417,
          label: 'Pickup',
        ),
        dropoff: const LocationPoint(
          latitude: 47.3776,
          longitude: 8.5431,
          label: 'Dropoff',
        ),
        vehicleClass: VehicleClass.standard,
      );

      expect(repository.completeRide(ride.id), throwsStateError);
      expect(
        repository.startRide(ride.id),
        throwsStateError,
      );
    });
  });
}

Future<void> _waitForStatus(
  List<Ride> events,
  RideStatus status, {
  Duration timeout = const Duration(milliseconds: 300),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (events.any((item) => item.status == status)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail(
    'Timed out waiting for ${status.name}. Seen: '
    '${events.map((item) => item.status.name).join(' -> ')}',
  );
}
