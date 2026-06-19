import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase hosted /home and /app return 200', () async {
    final client = HttpClient();
    addTearDown(client.close);

    final baseUrl = Platform.environment['HOSTING_BASE_URL'] ??
        'https://gold-taxi-clean.web.app';

    for (final path in ['/home', '/app']) {
      final request = await client.getUrl(Uri.parse('$baseUrl$path'));
      final response = await request.close();
      final body = await utf8.decodeStream(response);

      expect(response.statusCode, 200, reason: path);
      expect(response.headers.contentType?.mimeType, contains('text'));
      expect(body, isNotEmpty);
    }
  });

  test('hosting exposes manifest, offline fallback and service worker',
      () async {
    final client = HttpClient();
    addTearDown(client.close);

    final baseUrl = Platform.environment['HOSTING_BASE_URL'] ??
        'https://gold-taxi-clean.web.app';

    final manifestResponse =
        await (await client.getUrl(Uri.parse('$baseUrl/manifest.json')))
            .close();
    final manifestBody = await utf8.decodeStream(manifestResponse);
    expect(manifestResponse.statusCode, 200);
    expect(manifestBody, contains('"start_url": "/home"'));
  });

  test('local manifest contains explicit PWA routing metadata', () {
    final manifestBody = File('web/manifest.json').readAsStringSync();
    expect(manifestBody, contains('"id": "/home"'));
    expect(manifestBody, contains('"start_url": "/home"'));
    expect(manifestBody, contains('"scope": "/"'));
    expect(manifestBody, contains('"purpose": "any maskable"'));
  });

  test('local offline fallback page contains expected Slovak copy', () {
    final offlineBody = File('web/offline.html').readAsStringSync();
    expect(
        offlineBody,
        contains(
            'Ste offline. Verejná časť aplikácie je dostupná iba čiastočne.'));
    expect(offlineBody, contains('rezervácia jazdy vyžaduje internet'));
    expect(offlineBody, contains('Skúsiť znova'));
  });

  test('local service worker contains safe handlers and offline fallback logic',
      () {
    final swBody = File('web/sw.js').readAsStringSync();
    expect(swBody, contains("self.addEventListener('install'"));
    expect(swBody, contains("self.addEventListener('activate'"));
    expect(swBody, contains("self.addEventListener('fetch'"));
    expect(swBody, contains("request.mode === 'navigate'"));
    expect(swBody, contains("cache.match('/offline.html')"));
    expect(swBody, contains("/apple-touch-icon.png"));
    expect(swBody, contains("/favicon.ico"));
  });

  test('service worker excludes unsafe runtime cache targets', () {
    final sw = File('web/sw.js').readAsStringSync();

    for (final token in const [
      'firebase',
      'firestore',
      'identitytoolkit',
      'securetoken',
      'googleapis',
      'supabase',
      '/api/',
      'auth',
    ]) {
      expect(sw, contains(token),
          reason: 'Missing explicit exclusion for $token');
    }

    expect(sw, contains("request.mode === 'navigate'"));
    expect(sw, contains("cache.match('/offline.html')"));
    expect(sw, isNot(contains('caches.open(\'firebase')));
    expect(sw, isNot(contains('indexeddb')));
    expect(sw, isNot(contains('authorization')));
    expect(sw, isNot(contains('bearer ')));
  });

  test('web icon set is complete and linked from the shell', () {
    for (final path in const [
      'web/apple-touch-icon.png',
      'web/favicon-16x16.png',
      'web/favicon-32x32.png',
      'web/favicon.ico',
      'web/icons/Icon-192.png',
      'web/icons/Icon-512.png',
      'web/icons/Icon-maskable-192.png',
      'web/icons/Icon-maskable-512.png',
    ]) {
      expect(File(path).existsSync(), isTrue,
          reason: 'Missing icon asset: $path');
    }

    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('apple-touch-icon.png'));
    expect(html, contains('favicon-32x32.png'));
    expect(html, contains('favicon-16x16.png'));
    expect(html, contains('favicon.ico'));
  });

  test('PWA service worker is registered by the HTML shell only', () {
    final html = File('web/index.html').readAsStringSync();
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

    expect(html, contains('window.goldTaxiServiceWorkerReady'));
    expect(html, contains("navigator.serviceWorker"));
    expect(html, contains(".register('/sw.js', { scope: '/' })"));
    expect(bootstrap, contains('_flutter.loader.load();'));
    expect(bootstrap, isNot(contains('navigator.serviceWorker.register')));
  });
}
