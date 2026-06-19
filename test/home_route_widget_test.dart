import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/app/gold_taxi_app.dart';
import 'package:goldtaxi_bolt_v2_5/src/config/app_config.dart';
import 'package:goldtaxi_bolt_v2_5/src/ui/screens/app_shell_loader.dart';
import 'package:goldtaxi_bolt_v2_5/src/ui/screens/welcome_screen.dart';

void main() {
  testWidgets('renders the /home landing route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/home',
        routes: {
          '/home': (context) => WelcomeScreen(
                onContinue: () => Navigator.of(context).pushNamed('/app'),
              ),
          '/app': (_) => AppShellLoader(
                config: const AppConfig(),
                scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
              ),
        },
      ),
    );

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('To the world of executive mobility'), findsOneWidget);
    expect(
        find.text('We are here to make your trip memorable.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
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
    expect(find.text('Welcome'), findsNothing);
  });

  test('resolves browser path before platform route on hosted web', () {
    expect(
      resolveGoldTaxiInitialRoute(
        browserPath: '/app',
        platformRoute: '/',
      ),
      '/app',
    );
    expect(
      resolveGoldTaxiInitialRoute(
        browserPath: '/home',
        platformRoute: '/app',
      ),
      '/home',
    );
    expect(
      resolveGoldTaxiInitialRoute(
        browserPath: '/unknown',
        platformRoute: '/',
      ),
      '/',
    );
  });
}
