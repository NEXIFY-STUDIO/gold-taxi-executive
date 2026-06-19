import 'package:flutter/material.dart';

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
      title: 'GoldTaxi v2.5',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const GoldTaxiScrollBehavior(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const LandingPageScreen(),
      routes: {
        '/home': (context) => const LandingPageScreen(),
        '/app': (context) => AppShellLoader(
              config: widget.config,
              scaffoldMessengerKey: _scaffoldMessengerKey,
            ),
      },
    );
  }
}
