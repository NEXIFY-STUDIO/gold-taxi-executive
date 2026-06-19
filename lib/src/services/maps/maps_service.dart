import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../config/maps_config.dart';
import '../../data/models/location_point.dart';
import '../../data/models/place_prediction.dart';
import '../../data/models/route_polyline.dart';

abstract class MapsService {
  String get providerName;

  Stream<List<PlacePrediction>> autocomplete(String query);

  Future<RoutePolyline> routeBetween(
    LocationPoint origin,
    LocationPoint destination,
  );
}

class MapsServiceFactory {
  const MapsServiceFactory();

  /// Creates a MapsService from AppConfig which contains the API keys
  static MapsService createFromConfig(AppConfig appConfig) {
    final mapsConfig = appConfig.maps;
    if (!mapsConfig.isGoogleMaps) {
      return const MockMapsService();
    }

    final effectiveKey = appConfig.effectiveGoogleApiKey;

    if (effectiveKey.isEmpty) {
      return const MockMapsService();
    }

    return ResilientMapsService(
      primary: GoogleHttpMapsService(apiKey: effectiveKey),
      fallback: const MockMapsService(),
    );
  }

  /// Legacy method for backwards compatibility - reads from environment directly
  static MapsService create(MapsConfig config) {
    if (!config.isGoogleMaps) {
      return const MockMapsService();
    }

    const apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    const placesKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
    final effectiveKey = apiKey.isNotEmpty ? apiKey : placesKey;

    if (effectiveKey.isEmpty) {
      return const MockMapsService();
    }

    return ResilientMapsService(
      primary: GoogleHttpMapsService(apiKey: effectiveKey),
      fallback: const MockMapsService(),
    );
  }
}

class ResilientMapsService implements MapsService {
  const ResilientMapsService({
    required this.primary,
    required this.fallback,
  });

  final MapsService primary;
  final MapsService fallback;

  @override
  String get providerName => primary.providerName;

  @override
  Stream<List<PlacePrediction>> autocomplete(String query) async* {
    try {
      yield* primary.autocomplete(query);
    } catch (_) {
      yield* fallback.autocomplete(query);
    }
  }

  @override
  Future<RoutePolyline> routeBetween(
    LocationPoint origin,
    LocationPoint destination,
  ) async {
    try {
      return await primary.routeBetween(origin, destination);
    } catch (_) {
      return fallback.routeBetween(origin, destination);
    }
  }
}

class MockMapsService implements MapsService {
  const MockMapsService();

  static const _places = [
    _PlaceSeed('Zürich Hauptbahnhof', 'Zürich, Switzerland', 47.37818, 8.54019),
    _PlaceSeed('Zürich Airport', 'Kloten, Switzerland', 47.45810, 8.55550),
    _PlaceSeed('Bahnhofstrasse', 'Zürich, Switzerland', 47.36908, 8.53842),
    _PlaceSeed('Enge Station', 'Zürich, Switzerland', 47.36560, 8.53470),
    _PlaceSeed('Bellevue', 'Zürich, Switzerland', 47.36755, 8.54680),
    _PlaceSeed('Hardbrücke', 'Zürich, Switzerland', 47.38420, 8.51980),
    _PlaceSeed('Oerlikon', 'Zürich, Switzerland', 47.41170, 8.54420),
  ];

  @override
  String get providerName => 'Mock Maps';

  @override
  Stream<List<PlacePrediction>> autocomplete(String query) async* {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      yield const [];
      return;
    }

    final matches = _places
        .where((place) =>
            place.primaryText.toLowerCase().contains(q) ||
            place.secondaryText.toLowerCase().contains(q))
        .take(5)
        .map(
          (place) => PlacePrediction(
            placeId: place.primaryText.toLowerCase().replaceAll(' ', '_'),
            primaryText: place.primaryText,
            secondaryText: place.secondaryText,
            location: LocationPoint(
              latitude: place.latitude,
              longitude: place.longitude,
              label: place.primaryText,
            ),
          ),
        )
        .toList();

    yield matches;
  }

  @override
  Future<RoutePolyline> routeBetween(
    LocationPoint origin,
    LocationPoint destination,
  ) async {
    final points = List<LocationPoint>.generate(12, (index) {
      final t = index / 11;
      return origin.interpolateTo(
        destination,
        t,
        label: index == 0
            ? origin.label
            : index == 11
                ? destination.label
                : 'Route point',
      );
    });
    final distanceKm = origin.distanceKmTo(destination);
    final durationMinutes = (distanceKm / 0.6).ceil().clamp(4, 48);
    return RoutePolyline(
      points: points,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
    );
  }
}

class GoogleHttpMapsService implements MapsService {
  GoogleHttpMapsService({required this.apiKey});

  final String apiKey;

  @override
  String get providerName => 'Google Maps';

  @override
  Stream<List<PlacePrediction>> autocomplete(String query) async* {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      yield const [];
      return;
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': trimmed,
        'key': apiKey,
        'components': 'country:ch',
        'language': 'en',
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
          'Places autocomplete failed with ${response.statusCode}.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 'OK' && body['status'] != 'ZERO_RESULTS') {
      throw StateError('Places autocomplete returned ${body['status']}.');
    }

    final predictions = (body['predictions'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final results = <PlacePrediction>[];

    for (final prediction in predictions.take(5)) {
      final placeId = prediction['place_id']?.toString() ?? '';
      if (placeId.isEmpty) continue;
      final details = await _fetchDetails(placeId);
      final formatting =
          prediction['structured_formatting'] as Map<String, dynamic>?;
      results.add(
        PlacePrediction(
          placeId: placeId,
          primaryText: formatting?['main_text']?.toString() ??
              prediction['description']?.toString() ??
              placeId,
          secondaryText: formatting?['secondary_text']?.toString() ??
              'Zürich, Switzerland',
          location: details,
        ),
      );
    }

    yield results;
  }

  @override
  Future<RoutePolyline> routeBetween(
    LocationPoint origin,
    LocationPoint destination,
  ) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': apiKey,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
          'Directions request failed with ${response.statusCode}.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 'OK') {
      throw StateError('Directions returned ${body['status']}.');
    }

    final routes = body['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw StateError('No routes returned.');
    }

    final route = routes.first as Map<String, dynamic>;
    final leg = (route['legs'] as List<dynamic>).first as Map<String, dynamic>;
    final overviewPolyline =
        route['overview_polyline'] as Map<String, dynamic>?;
    final polyline = overviewPolyline?['points']?.toString() ?? '';
    return RoutePolyline(
      points: _decodePolyline(polyline),
      distanceKm: ((leg['distance']?['value'] as num?)?.toDouble() ?? 0) / 1000,
      durationMinutes:
          (((leg['duration']?['value'] as num?)?.toDouble() ?? 0) / 60).ceil(),
    );
  }

  Future<LocationPoint> _fetchDetails(String placeId) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'geometry,name,formatted_address',
        'key': apiKey,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError('Place details failed with ${response.statusCode}.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 'OK') {
      throw StateError('Place details returned ${body['status']}.');
    }

    final result = body['result'] as Map<String, dynamic>;
    final geometry = result['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;
    return LocationPoint(
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
      label: result['name']?.toString() ??
          result['formatted_address']?.toString() ??
          'Selected place',
    );
  }

  List<LocationPoint> _decodePolyline(String encoded) {
    final poly = <LocationPoint>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var b = 0;
      var shift = 0;
      var result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(
        LocationPoint(
          latitude: lat / 1E5,
          longitude: lng / 1E5,
          label: 'Route point',
        ),
      );
    }

    return poly;
  }
}

class _PlaceSeed {
  const _PlaceSeed(
    this.primaryText,
    this.secondaryText,
    this.latitude,
    this.longitude,
  );

  final String primaryText;
  final String secondaryText;
  final double latitude;
  final double longitude;
}
