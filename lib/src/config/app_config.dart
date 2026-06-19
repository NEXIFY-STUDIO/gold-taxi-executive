import 'maps_config.dart';

enum BackendMode { mock, firebase }

class AppConfig {
  const AppConfig({
    this.backendMode = BackendMode.mock,
    this.maps = const MapsConfig(),
    this.fcmWebVapidKey = const String.fromEnvironment(
      'FIREBASE_WEB_VAPID_KEY',
      defaultValue: '',
    ),
    this.googleMapsApiKey = const String.fromEnvironment(
      'GOOGLE_MAPS_API_KEY',
      defaultValue: '',
    ),
    this.googlePlacesApiKey = const String.fromEnvironment(
      'GOOGLE_PLACES_API_KEY',
      defaultValue: '',
    ),
  });

  factory AppConfig.fromEnvironment() {
    const backendMode = String.fromEnvironment(
      'BACKEND_MODE',
      defaultValue: 'mock',
    );
    return AppConfig(
      backendMode:
          backendMode.toLowerCase() == 'firebase' ? BackendMode.firebase : BackendMode.mock,
      googleMapsApiKey: const String.fromEnvironment(
        'GOOGLE_MAPS_API_KEY',
        defaultValue: '',
      ),
      googlePlacesApiKey: const String.fromEnvironment(
        'GOOGLE_PLACES_API_KEY',
        defaultValue: '',
      ),
    );
  }

  final BackendMode backendMode;
  final MapsConfig maps;
  final String fcmWebVapidKey;
  final String googleMapsApiKey;
  final String googlePlacesApiKey;

  bool get isMock => backendMode == BackendMode.mock;
  bool get useFirebaseRuntime => backendMode == BackendMode.firebase;

  /// Returns the effective Google Maps API key (maps key if available, otherwise places key)
  String get effectiveGoogleApiKey => googleMapsApiKey.isNotEmpty
      ? googleMapsApiKey
      : googlePlacesApiKey;
}
