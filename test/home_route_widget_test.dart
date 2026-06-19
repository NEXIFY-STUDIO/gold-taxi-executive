import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/app/gold_taxi_app.dart';
import 'package:goldtaxi_bolt_v2_5/src/config/app_config.dart';
import 'package:goldtaxi_bolt_v2_5/src/ui/screens/app_shell_loader.dart';
import 'package:goldtaxi_bolt_v2_5/src/ui/screens/home_landing_screen.dart';

void main() {
  testWidgets('renders the /home landing route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/home',
        routes: {
          '/home': (_) => const LandingPageScreen(),
          '/app': (_) => AppShellLoader(
                config: const AppConfig(),
                scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
              ),
        },
      ),
    );

    expect(find.text('FOUNDING PARTNER PROGRAM 2026'), findsOneWidget);
    expect(find.text('BOOK PREMIUM RIDE'), findsOneWidget);
    expect(find.text('VIEW RIDE FLOW'), findsOneWidget);

    await tester.tap(find.text('BOOK PREMIUM RIDE'));
    await tester.pumpAndSettle();

    expect(find.text('Loading the app shell'), findsNothing);
    expect(find.text('Book your ride'), findsOneWidget);
  });

  testWidgets('GoldTaxiApp respects direct /app browser route', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/app';
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(
      const GoldTaxiApp(config: AppConfig()),
    );

    expect(find.text('Loading the app shell'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Book your ride'), findsOneWidget);
    expect(find.text('FOUNDING PARTNER PROGRAM 2026'), findsNothing);
  });
}
