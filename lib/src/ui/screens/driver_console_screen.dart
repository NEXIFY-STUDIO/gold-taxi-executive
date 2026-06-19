import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/ride.dart';
import '../../state/app_state.dart';
import '../../services/push/push_notification_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/notification_status_chip.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_chip.dart';

class DriverConsoleScreen extends StatelessWidget {
  const DriverConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final activeRide = state.activeRide;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Driver',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: NotificationStatusChip(service: PushScope.of(context)),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(
                      label: state.driverOnline ? 'ONLINE' : 'OFFLINE',
                      color:
                          state.driverOnline ? Colors.greenAccent : Colors.grey,
                      icon: Icons.power_settings_new_rounded,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Driver shift',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DriverMetric(
                            label: 'Earnings',
                            value:
                                'CHF ${state.earningsToday.toStringAsFixed(2)}',
                          ),
                        ),
                        Expanded(
                          child: _DriverMetric(
                            label: 'Trips',
                            value: state.completedTrips.toString(),
                          ),
                        ),
                        const Expanded(
                          child: _DriverMetric(label: 'Rating', value: '4.94'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: state.driverOnline ? 'Go offline' : 'Go online',
                      icon: state.driverOnline
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      onPressed: state.toggleDriverOnline,
                    ),
                    const Divider(height: 32, color: Colors.white12),
                    Text(
                      state.driverOnline ? 'New offer' : 'Driver offline',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!state.driverOnline)
                      const Text(
                        'Go online to receive offers.',
                        style: TextStyle(color: AppTheme.textMuted),
                      )
                    else if (activeRide == null)
                      const Text(
                        'Waiting for the next ride offer.',
                        style: TextStyle(color: AppTheme.textMuted),
                      )
                    else if (activeRide.status == RideStatus.searching) ...[
                      Text(
                        'Accept in ${state.driverOfferSecondsRemaining}s',
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${activeRide.pickup.label} → ${activeRide.dropoff.label}',
                      ),
                      const SizedBox(height: 8),
                      Text('Class: ${activeRide.vehicleClass.label}'),
                      const SizedBox(height: 8),
                      Text(
                        'Estimated fare: CHF ${activeRide.estimatedFare.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Accept',
                              icon: Icons.check_rounded,
                              onPressed: state.acceptRideOffer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: state.declineRideOffer,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Decline'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      StatusChip(
                        label: activeRide.status.label.toUpperCase(),
                        color: _statusColor(activeRide.status),
                        icon: Icons.route_rounded,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${activeRide.pickup.label} → ${activeRide.dropoff.label}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Estimated fare: CHF ${activeRide.estimatedFare.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 16),
                      if (activeRide.status == RideStatus.accepted ||
                          activeRide.status == RideStatus.driverArriving)
                        PrimaryButton(
                          label: 'Arrived',
                          icon: Icons.place_rounded,
                          onPressed: state.markArrived,
                        )
                      else if (activeRide.status == RideStatus.arrived)
                        PrimaryButton(
                          label: 'Start trip',
                          icon: Icons.play_arrow_rounded,
                          onPressed: state.startRide,
                        )
                      else if (activeRide.status == RideStatus.inProgress)
                        PrimaryButton(
                          label: 'Complete trip',
                          icon: Icons.check_circle_rounded,
                          onPressed: state.completeRide,
                        ),
                    ],
                    const Divider(height: 32, color: Colors.white12),
                    const Text(
                      'Earnings',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DriverMetric(
                            label: 'Trips',
                            value: state.completedTrips.toString(),
                          ),
                        ),
                        Expanded(
                          child: _DriverMetric(
                            label: 'Revenue',
                            value:
                                'CHF ${state.earningsToday.toStringAsFixed(2)}',
                          ),
                        ),
                        const Expanded(
                          child: _DriverMetric(
                            label: 'Rating',
                            value: '4.94',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Color _statusColor(RideStatus status) {
  return switch (status) {
    RideStatus.searching => Colors.orange,
    RideStatus.accepted => AppTheme.gold,
    RideStatus.driverArriving => AppTheme.goldBright,
    RideStatus.arrived => Colors.greenAccent,
    RideStatus.inProgress => Colors.lightBlueAccent,
    RideStatus.completed => Colors.green,
    RideStatus.cancelled => Colors.redAccent,
    RideStatus.paymentFailed => Colors.redAccent,
    RideStatus.draft => Colors.grey,
  };
}

class _DriverMetric extends StatelessWidget {
  const _DriverMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
