import 'package:flutter/material.dart';

import '../../data/models/driver.dart';
import '../../data/models/driver_approval.dart';
import '../../data/models/ride.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/status_chip.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final activeDrivers = state.drivers
            .where((driver) => driver.status != DriverStatus.offline)
            .toList();
        final activeRides = state.rides
            .where((ride) => ride.status.isActive)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final monitoredRide = state.activeRide ?? _firstRide(activeRides);

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Operations',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live operations',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        const StatusChip(
                          label: 'Live feed',
                          color: Colors.greenAccent,
                          icon: Icons.sensors_rounded,
                        ),
                        StatusChip(
                          label: state.config.backendMode.name,
                          color: AppTheme.gold,
                          icon: Icons.storage_rounded,
                        ),
                        StatusChip(
                          label: '${activeDrivers.length} drivers online',
                          color: Colors.lightBlueAccent,
                          icon: Icons.local_taxi_rounded,
                        ),
                        StatusChip(
                          label: '${activeRides.length} active rides',
                          color: Colors.orangeAccent,
                          icon: Icons.route_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _OpsMetric(
                            label: 'Revenue today',
                            value:
                                'CHF ${state.earningsToday.toStringAsFixed(2)}',
                          ),
                        ),
                        Expanded(
                          child: _OpsMetric(
                            label: 'Online drivers',
                            value: activeDrivers.length.toString(),
                          ),
                        ),
                        Expanded(
                          child: _OpsMetric(
                            label: 'Active rides',
                            value: activeRides.length.toString(),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32, color: Colors.white12),
                    const Text(
                      'Live rides',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    if (activeRides.isEmpty)
                      const Text(
                        'No live rides right now.',
                        style: TextStyle(color: AppTheme.textMuted),
                      )
                    else
                      ...activeRides.map(
                        (ride) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RideTile(
                            ride: ride,
                            onCancel: () => state.adminCancelRide(ride),
                            onResolve: () => state.resolveRide(ride),
                          ),
                        ),
                      ),
                    const Divider(height: 32, color: Colors.white12),
                    const Text(
                      'Drivers online',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    if (activeDrivers.isEmpty)
                      const Text(
                        'No drivers online right now.',
                        style: TextStyle(color: AppTheme.textMuted),
                      )
                    else
                      ...activeDrivers.map(
                        (driver) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: driver.status == DriverStatus.busy
                                ? Colors.orange
                                : Colors.greenAccent,
                            child: Text(
                              driver.name.characters.first,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          title: Text(driver.name),
                          subtitle: Text(
                            '${driver.vehicleName} · ${driver.plateNumber}',
                          ),
                          trailing: StatusChip(
                            label: driver.status.label.toUpperCase(),
                            color: driver.status == DriverStatus.busy
                                ? Colors.orange
                                : Colors.greenAccent,
                            icon: Icons.person_pin_circle_rounded,
                          ),
                        ),
                      ),
                    const Divider(height: 32, color: Colors.white12),
                    const _DriverApplicationsPanel(),
                    const Divider(height: 32, color: Colors.white12),
                    const Text(
                      'Ride control',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    if (monitoredRide == null)
                      const Text(
                        'Open any live ride to inspect it.',
                        style: TextStyle(color: AppTheme.textMuted),
                      )
                    else ...[
                      StatusChip(
                        label: monitoredRide.status.label,
                        color: _statusColor(monitoredRide.status),
                        icon: Icons.bolt_rounded,
                      ),
                      const SizedBox(height: 10),
                      Text(monitoredRide.id),
                      const SizedBox(height: 6),
                      Text(
                        '${monitoredRide.pickup.label} → ${monitoredRide.dropoff.label}',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Class: ${monitoredRide.vehicleClass.label} · Fare CHF ${monitoredRide.estimatedFare.toStringAsFixed(2)}',
                      ),
                    ],
                    const Divider(height: 32, color: Colors.white12),
                    const Text(
                      'Operator summary',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _OpsMetric(
                            label: 'Online drivers',
                            value: activeDrivers.length.toString(),
                          ),
                        ),
                        Expanded(
                          child: _OpsMetric(
                            label: 'Active rides',
                            value: activeRides.length.toString(),
                          ),
                        ),
                        Expanded(
                          child: _OpsMetric(
                            label: 'Completed',
                            value: state.completedTrips.toString(),
                          ),
                        ),
                      ],
                    ),
                    if (state.opsNotice != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.opsNotice!,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
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

class _DriverApplicationsPanel extends StatefulWidget {
  const _DriverApplicationsPanel();

  @override
  State<_DriverApplicationsPanel> createState() =>
      _DriverApplicationsPanelState();
}

class _DriverApplicationsPanelState extends State<_DriverApplicationsPanel> {
  bool _queuedInitialLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queuedInitialLoad) return;
    _queuedInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppStateScope.of(context).loadDriverApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final pending = state.driverApplications
        .where((item) => item.status == DriverApplicationStatus.pending)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Žiadosti vodičov',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            IconButton.filledTonal(
              onPressed: state.isLoadingDriverApplications
                  ? null
                  : state.loadDriverApplications,
              icon: state.isLoadingDriverApplications
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh driver requests',
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Review passenger applications and approve only verified drivers.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 14),
        if (pending.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .035),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'No pending driver requests.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          )
        else
          ...pending.map(
            (application) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DriverApplicationTile(application: application),
            ),
          ),
      ],
    );
  }
}

class _DriverApplicationTile extends StatelessWidget {
  const _DriverApplicationTile({required this.application});

  final DriverApplication application;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final busy = state.isReviewingDriverApplication;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.goldBright, AppTheme.gold],
                  ),
                ),
                child: const Icon(
                  Icons.drive_eta_rounded,
                  color: Colors.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${application.vehicleLabel} · ${application.licensePlate}',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${application.phone} · ${application.userId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(
                label: application.vehicleClass.label.toUpperCase(),
                color: AppTheme.gold,
                icon: Icons.workspace_premium_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => state.approveDriverApplication(application),
                icon: busy
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_rounded),
                label: const Text('Approve'),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => state.rejectDriverApplication(application),
                icon: const Icon(Icons.block_rounded),
                label: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Ride? _firstRide(List<Ride> rides) {
  return rides.isEmpty ? null : rides.first;
}

class _RideTile extends StatelessWidget {
  const _RideTile({
    required this.ride,
    required this.onCancel,
    required this.onResolve,
  });

  final Ride ride;
  final VoidCallback onCancel;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(
            label: ride.status.label.toUpperCase(),
            color: _statusColor(ride.status),
            icon: Icons.route_rounded,
          ),
          const SizedBox(height: 10),
          Text(
            '${ride.pickup.label} → ${ride.dropoff.label}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Class: ${ride.vehicleClass.label} · ETA ${ride.durationMinutes} min',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onResolve,
                icon: const Icon(Icons.build_circle_rounded),
                label: const Text('Resolve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpsMetric extends StatelessWidget {
  const _OpsMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
      ],
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
