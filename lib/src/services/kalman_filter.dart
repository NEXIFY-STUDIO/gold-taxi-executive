class KalmanFilter1D {
  KalmanFilter1D({
    this.processNoise = 0.00001,
    this.measurementNoise = 0.0008,
    double initialEstimate = 0,
    double initialError = 1,
  })  : _estimate = initialEstimate,
        _error = initialError;

  final double processNoise;
  final double measurementNoise;

  double _estimate;
  double _error;

  double filter(double measurement) {
    _error += processNoise;
    final gain = _error / (_error + measurementNoise);
    _estimate = _estimate + gain * (measurement - _estimate);
    _error = (1 - gain) * _error;
    return _estimate;
  }
}

class GpsKalmanFilter {
  GpsKalmanFilter(double initialLat, double initialLng)
      : _lat = KalmanFilter1D(initialEstimate: initialLat),
        _lng = KalmanFilter1D(initialEstimate: initialLng);

  final KalmanFilter1D _lat;
  final KalmanFilter1D _lng;

  ({double latitude, double longitude}) filter(double latitude, double longitude) {
    return (
      latitude: _lat.filter(latitude),
      longitude: _lng.filter(longitude),
    );
  }
}
