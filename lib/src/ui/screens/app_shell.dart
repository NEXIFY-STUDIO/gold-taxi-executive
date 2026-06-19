import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import 'admin_dashboard_screen.dart';
import 'driver_console_screen.dart';
import 'passenger_home_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final destinations = <_ShellDestination>[
          const _ShellDestination(
            shellIndex: 0,
            screen: PassengerHomeScreen(),
            item: BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded),
              label: 'Passenger',
            ),
          ),
          if (state.canAccessDriverConsole)
            const _ShellDestination(
              shellIndex: 1,
              screen: DriverConsoleScreen(),
              item: BottomNavigationBarItem(
                icon: Icon(Icons.local_taxi_rounded),
                label: 'Driver',
              ),
            ),
          if (state.canAccessOpsConsole)
            const _ShellDestination(
              shellIndex: 2,
              screen: AdminDashboardScreen(),
              item: BottomNavigationBarItem(
                icon: Icon(Icons.tune_rounded),
                label: 'Ops',
              ),
            ),
        ];
        final currentIndex = destinations.indexWhere(
          (destination) => destination.shellIndex == state.shellIndex,
        );
        final selectedIndex = currentIndex == -1 ? 0 : currentIndex;

        return Scaffold(
          body: destinations[selectedIndex].screen,
          bottomNavigationBar: destinations.length < 2
              ? null
              : BottomNavigationBar(
                  currentIndex: selectedIndex,
                  onTap: (index) => state.setShellIndex(
                    destinations[index].shellIndex,
                  ),
                  items: destinations
                      .map((destination) => destination.item)
                      .toList(),
                ),
        );
      },
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.shellIndex,
    required this.screen,
    required this.item,
  });

  final int shellIndex;
  final Widget screen;
  final BottomNavigationBarItem item;
}
