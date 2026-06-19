import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/ride.dart';
import '../../data/models/place_prediction.dart';
import '../../data/models/route_polyline.dart';
import '../../data/models/vehicle_class.dart';
import '../../services/maps/maps_service.dart';
import '../../state/app_state.dart';
import '../../services/push/push_notification_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/notification_status_chip.dart';
import '../widgets/mock_map.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_chip.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  late final TextEditingController _pickupController;
  late final TextEditingController _dropoffController;
  late final AppState _state;
  late final MapsService _mapsService;
  bool _controllersReady = false;
  Timer? _pickupDebounce;
  Timer? _dropoffDebounce;
  Timer? _routeDebounce;
  List<PlacePrediction> _pickupSuggestions = const [];
  List<PlacePrediction> _dropoffSuggestions = const [];
  RoutePolyline? _routePreview;
  String? _mapsError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllersReady) return;
    _state = AppStateScope.of(context);
    _mapsService = MapsServiceFactory.createFromConfig(_state.config);
    _pickupController = TextEditingController(text: _state.pickup.label);
    _dropoffController = TextEditingController(text: _state.dropoff.label);
    _pickupController
        .addListener(() => _queuePickupSearch(_pickupController.text));
    _dropoffController
        .addListener(() => _queueDropoffSearch(_dropoffController.text));
    _controllersReady = true;
    _queueRoutePreview();
  }

  @override
  void dispose() {
    _pickupDebounce?.cancel();
    _dropoffDebounce?.cancel();
    _routeDebounce?.cancel();
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text(
              'GoldTaxi',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Wrap(
                  spacing: 10,
                  children: [
                    NotificationStatusChip(service: PushScope.of(context)),
                    if (kDebugMode)
                      StatusChip(
                        label: state.config.backendMode.name.toUpperCase(),
                        color:
                            state.config.isMock ? Colors.orange : Colors.green,
                        icon: Icons.bolt_rounded,
                      ),
                  ],
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: MockMap(
                  drivers: _state.drivers,
                  pickup: _state.pickup,
                  dropoff: _state.dropoff,
                  ride: _state.activeRide,
                  route: _routePreview,
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: state.activeRide == null ? .52 : .42,
                minChildSize: .28,
                maxChildSize: .86,
                builder: (context, controller) {
                  return SingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: _state.activeRide == null
                        ? _BookingPanel(
                            pickupController: _pickupController,
                            dropoffController: _dropoffController,
                            mapsProviderName: _mapsService.providerName,
                            routePreview: _routePreview,
                            mapsError: _mapsError,
                            pickupSuggestions: _pickupSuggestions,
                            dropoffSuggestions: _dropoffSuggestions,
                            onPickupSuggestionSelected: _selectPickupSuggestion,
                            onDropoffSuggestionSelected:
                                _selectDropoffSuggestion,
                            onRefreshRoute: _queueRoutePreview,
                          )
                        : _ActiveRidePanel(ride: _state.activeRide!),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _queuePickupSearch(String query) {
    _pickupDebounce?.cancel();
    _pickupDebounce = Timer(const Duration(milliseconds: 220), () async {
      if (!mounted) return;
      if (query.trim().isEmpty) {
        setState(() => _pickupSuggestions = const []);
        return;
      }
      final results = await _mapsService.autocomplete(query).first;
      if (!mounted) return;
      setState(() => _pickupSuggestions = results);
    });
  }

  void _queueDropoffSearch(String query) {
    _dropoffDebounce?.cancel();
    _dropoffDebounce = Timer(const Duration(milliseconds: 220), () async {
      if (!mounted) return;
      if (query.trim().isEmpty) {
        setState(() => _dropoffSuggestions = const []);
        return;
      }
      final results = await _mapsService.autocomplete(query).first;
      if (!mounted) return;
      setState(() => _dropoffSuggestions = results);
    });
  }

  void _queueRoutePreview() {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(milliseconds: 220), () async {
      try {
        final route =
            await _mapsService.routeBetween(_state.pickup, _state.dropoff);
        if (!mounted) return;
        setState(() {
          _routePreview = route;
          _mapsError = null;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _mapsError = error.toString();
          _routePreview = null;
        });
      }
    });
  }

  void _selectPickupSuggestion(PlacePrediction prediction) {
    _pickupController.text = prediction.primaryText;
    _state.updatePickupLocation(prediction.location);
    setState(() {
      _pickupSuggestions = const [];
    });
    _queueRoutePreview();
  }

  void _selectDropoffSuggestion(PlacePrediction prediction) {
    _dropoffController.text = prediction.primaryText;
    _state.updateDropoffLocation(prediction.location);
    setState(() {
      _dropoffSuggestions = const [];
    });
    _queueRoutePreview();
  }
}

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({
    required this.pickupController,
    required this.dropoffController,
    required this.mapsProviderName,
    required this.routePreview,
    required this.mapsError,
    required this.pickupSuggestions,
    required this.dropoffSuggestions,
    required this.onPickupSuggestionSelected,
    required this.onDropoffSuggestionSelected,
    required this.onRefreshRoute,
  });

  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final String mapsProviderName;
  final RoutePolyline? routePreview;
  final String? mapsError;
  final List<PlacePrediction> pickupSuggestions;
  final List<PlacePrediction> dropoffSuggestions;
  final ValueChanged<PlacePrediction> onPickupSuggestionSelected;
  final ValueChanged<PlacePrediction> onDropoffSuggestionSelected;
  final VoidCallback onRefreshRoute;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const Text(
            'Book your ride',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                label: mapsProviderName.toUpperCase(),
                color: AppTheme.gold,
                icon: Icons.map_rounded,
              ),
              if (routePreview != null)
                StatusChip(
                  label:
                      '${routePreview!.distanceKm.toStringAsFixed(1)} km · ${routePreview!.durationMinutes} min',
                  color: Colors.greenAccent,
                  icon: Icons.route_rounded,
                ),
              if (mapsError != null)
                const StatusChip(
                  label: 'MAPS FALLBACK',
                  color: Colors.orangeAccent,
                  icon: Icons.info_outline,
                ),
            ],
          ),
          if (mapsError != null) ...[
            const SizedBox(height: 10),
            Text(
              'Live map lookup unavailable, using Zurich fallback routing.',
              style: TextStyle(color: Colors.white.withValues(alpha: .7)),
            ),
          ],
          const SizedBox(height: 14),
          const _AccountPanel(),
          const SizedBox(height: 12),
          TextField(
            controller: pickupController,
            onChanged: state.updatePickupLabel,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.radio_button_checked_rounded),
              labelText: 'Pickup point',
            ),
          ),
          const SizedBox(height: 10),
          _SuggestionList(
            suggestions: pickupSuggestions,
            onTap: onPickupSuggestionSelected,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: dropoffController,
            onChanged: state.updateDropoffLabel,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.flag_rounded),
              labelText: 'Drop-off point',
            ),
          ),
          const SizedBox(height: 18),
          _SuggestionList(
            suggestions: dropoffSuggestions,
            onTap: onDropoffSuggestionSelected,
          ),
          const SizedBox(height: 14),
          const Text(
            'Vehicle tier',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 12),
          for (final vehicleClass in VehicleClass.values)
            _VehicleClassTile(vehicleClass: vehicleClass),
          const SizedBox(height: 12),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                state.error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          PrimaryButton(
            label:
                'Book ${state.selectedClass.label} · CHF ${state.estimateFor(state.selectedClass).amount.toStringAsFixed(2)}',
            icon: Icons.local_taxi_rounded,
            isLoading: state.isLoading,
            onPressed: state.requestRide,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRefreshRoute,
            child: const Text('Refresh route preview'),
          ),
        ],
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.supportsGoogleSignIn) {
      return const SizedBox.shrink();
    }

    final isGuest = state.isGuestSession;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGuest
                    ? Icons.person_outline_rounded
                    : Icons.verified_user_rounded,
                color: isGuest ? AppTheme.textMuted : AppTheme.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.accountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      isGuest ? 'Guest checkout' : 'Google account',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: isGuest
                ? OutlinedButton.icon(
                    onPressed: state.isAuthActionLoading
                        ? null
                        : state.signInWithGoogle,
                    icon: state.isAuthActionLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: const Text('Sign in with Google'),
                  )
                : TextButton.icon(
                    onPressed: state.isAuthActionLoading
                        ? null
                        : state.continueAsGuest,
                    icon: const Icon(Icons.person_outline_rounded),
                    label: const Text('Use guest mode'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.suggestions,
    required this.onTap,
  });

  final List<PlacePrediction> suggestions;
  final ValueChanged<PlacePrediction> onTap;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (final suggestion in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white.withValues(alpha: .04),
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.place_rounded, color: AppTheme.gold),
                title: Text(
                  suggestion.primaryText,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(suggestion.secondaryText),
                onTap: () => onTap(suggestion),
              ),
            ),
          ),
      ],
    );
  }
}

class _VehicleClassTile extends StatelessWidget {
  const _VehicleClassTile({required this.vehicleClass});

  final VehicleClass vehicleClass;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final estimate = state.estimateFor(vehicleClass);
    final selected = state.selectedClass == vehicleClass;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => state.setSelectedClass(vehicleClass),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? vehicleClass.accentColor.withValues(alpha: .12)
                : Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? vehicleClass.accentColor : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: vehicleClass.accentColor.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.local_taxi_rounded,
                    color: vehicleClass.accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleClass.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${vehicleClass.description} · ${estimate.durationMinutes} min',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                'CHF ${estimate.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: vehicleClass.accentColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveRidePanel extends StatelessWidget {
  const _ActiveRidePanel({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final driver = ride.driver;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          StatusChip(
            label: ride.status.label,
            color: _statusColor(ride.status),
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 16),
          Text(
            _headlineFor(ride.status),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            '${ride.pickup.label} → ${ride.dropoff.label}',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          if (driver != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.gold,
                    child: Text(
                      driver.name.characters.first,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${driver.name}\n${driver.vehicleName} · ${driver.plateNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('★ ${driver.rating.toStringAsFixed(2)}'),
                ],
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Fare',
                  value:
                      'CHF ${(ride.finalFare ?? ride.estimatedFare).toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Distance',
                  value: '${ride.distanceKm.toStringAsFixed(1)} km',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'ETA',
                  value: '${ride.durationMinutes} min',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (ride.status == RideStatus.arrived)
            PrimaryButton(
              label: 'Begin trip',
              icon: Icons.play_arrow_rounded,
              onPressed: state.startRide,
            )
          else if (ride.status == RideStatus.inProgress)
            PrimaryButton(
              label: 'Complete trip',
              icon: Icons.check_rounded,
              onPressed: state.completeRide,
            )
          else if (ride.status == RideStatus.completed ||
              ride.status == RideStatus.cancelled)
            PrimaryButton(
              label: 'Book next ride',
              icon: Icons.refresh_rounded,
              onPressed: state.clearCompletedRide,
            )
          else
            OutlinedButton.icon(
              onPressed: state.cancelRide,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel'),
            ),
        ],
      ),
    );
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

  String _headlineFor(RideStatus status) {
    return switch (status) {
      RideStatus.searching => 'Finding the best driver',
      RideStatus.accepted => 'Driver confirmed',
      RideStatus.driverArriving => 'Driver en route',
      RideStatus.arrived => 'Driver at pickup',
      RideStatus.inProgress => 'Trip in progress',
      RideStatus.completed => 'Trip complete',
      RideStatus.cancelled => 'Trip cancelled',
      RideStatus.paymentFailed => 'Payment issue',
      RideStatus.draft => 'Draft trip',
    };
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}
