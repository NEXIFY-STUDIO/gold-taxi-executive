enum MapsProvider { googleMaps, mapbox }

class MapsConfig {
  const MapsConfig({
    this.provider = MapsProvider.googleMaps,
    this.googleMapsApiKeyEnv = 'GOOGLE_MAPS_API_KEY',
    this.googlePlacesApiKeyEnv = 'GOOGLE_PLACES_API_KEY',
    this.androidPackageName = 'com.example.goldtaxi',
    this.iosBundleId = 'com.example.goldtaxi',
    this.webReferrer = 'https://goldtaxi-202ff.web.app/*',
  });

  final MapsProvider provider;
  final String googleMapsApiKeyEnv;
  final String googlePlacesApiKeyEnv;
  final String androidPackageName;
  final String iosBundleId;
  final String webReferrer;

  bool get isGoogleMaps => provider == MapsProvider.googleMaps;

  List<String> get recommendedApiKeyRestrictions => [
        'Android app restriction: $androidPackageName',
        'iOS app restriction: $iosBundleId',
        'HTTP referrer restriction: $webReferrer',
        'Restrict Maps SDKs to Maps, Places, Directions, and Roads only',
      ];
}
