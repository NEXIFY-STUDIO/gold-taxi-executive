import 'package:flutter/material.dart';

import 'browser_route.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../ui/screens/home_landing_screen.dart';
import '../ui/screens/app_shell_loader.dart';

class GoldTaxiApp extends StatefulWidget {
  const GoldTaxiApp({super.key, required this.config});

  final AppConfig config;

  @override
  State<GoldTaxiApp> createState() => _GoldTaxiAppState();
}

class _GoldTaxiAppState extends State<GoldTaxiApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: widget.config.brand.appTitle,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const GoldTaxiScrollBehavior(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      initialRoute: _initialRoute(),
      routes: {
        '/': (context) => LandingPageScreen(brand: widget.config.brand),
        '/home': (context) => LandingPageScreen(brand: widget.config.brand),
        '/app': (context) => AppShellLoader(
              config: widget.config,
              scaffoldMessengerKey: _scaffoldMessengerKey,
            ),
      },
    );
  }

  String _initialRoute() {
    return resolveGoldTaxiInitialRoute(
      browserPath: currentBrowserPath(),
      platformRoute:
          WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    );
  }
}

@visibleForTesting
String resolveGoldTaxiInitialRoute({
  required String browserPath,
  required String platformRoute,
}) {
  return _knownRoute(browserPath) ?? _knownRoute(platformRoute) ?? '/';
}

String? _knownRoute(String value) {
  final trimmed = value.trim();
  final route = trimmed.length > 1 && trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
  return switch (route) {
    '' || '/' => '/',
    '/home' || '/app' => route,
    _ => null,
  };
}
