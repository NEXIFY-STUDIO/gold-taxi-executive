import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../theme/app_theme.dart';
import 'app_module.dart' deferred as app_module;
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';

class AppShellLoader extends StatefulWidget {
  const AppShellLoader({
    super.key,
    required this.config,
    required this.scaffoldMessengerKey,
  });

  final AppConfig config;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  State<AppShellLoader> createState() => _AppShellLoaderState();
}

class _AppShellLoaderState extends State<AppShellLoader> {
  late Future<void> _loadFuture = app_module.loadLibrary();

  void _retry() {
    setState(() {
      _loadFuture = app_module.loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppTheme.black,
            body: Center(
              child: SizedBox(
                width: 280,
                child: GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Loading the app shell',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Preparing passenger, driver and ops views.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      SizedBox(height: 18),
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.black,
            body: Center(
              child: SizedBox(
                width: 320,
                child: GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not load the app shell',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Try again to continue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: 'Retry',
                        icon: Icons.refresh_rounded,
                        onPressed: _retry,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return app_module.AppModule(
          config: widget.config,
          scaffoldMessengerKey: widget.scaffoldMessengerKey,
        );
      },
    );
  }
}
