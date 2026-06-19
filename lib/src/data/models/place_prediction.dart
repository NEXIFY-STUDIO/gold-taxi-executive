import 'location_point.dart';

class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.location,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final LocationPoint location;
}
