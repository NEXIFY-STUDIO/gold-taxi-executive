import '../data/models/location_point.dart';
import '../data/models/vehicle_class.dart';

class PriceEstimate {
  const PriceEstimate({
    required this.distanceKm,
    required this.durationMinutes,
    required this.surgeMultiplier,
    required this.amount,
  });

  final double distanceKm;
  final int durationMinutes;
  final double surgeMultiplier;
  final double amount;
}

class PricingService {
  const PricingService();

  PriceEstimate estimate({
    required LocationPoint pickup,
    required LocationPoint dropoff,
    required VehicleClass vehicleClass,
    double surgeMultiplier = 1.0,
  }) {
    final distanceKm = pickup.distanceKmTo(dropoff);
    final durationMinutes = _estimateUrbanMinutes(distanceKm);
    final raw = vehicleClass.baseFare +
        distanceKm * vehicleClass.pricePerKm +
        durationMinutes * vehicleClass.pricePerMinute;

    final surged = raw * surgeMultiplier;
    final amount = _roundMoney(surged < vehicleClass.minimumFare
        ? vehicleClass.minimumFare
        : surged);

    return PriceEstimate(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      surgeMultiplier: surgeMultiplier,
      amount: amount,
    );
  }

  int _estimateUrbanMinutes(double distanceKm) {
    const averageUrbanKmh = 28.0;
    final minutes = (distanceKm / averageUrbanKmh) * 60.0;
    return minutes.ceil().clamp(3, 180);
  }

  double _roundMoney(double value) => (value * 100).roundToDouble() / 100;
}
