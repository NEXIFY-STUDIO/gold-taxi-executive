import 'package:flutter/material.dart';

import '../../services/push/push_notification_service.dart';
import 'status_chip.dart';

class NotificationStatusChip extends StatelessWidget {
  const NotificationStatusChip({
    super.key,
    required this.service,
  });

  final PushNotificationService service;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final state = service.permissionState;
        final label = switch (state) {
          PushPermissionState.granted => 'NOTIFS ON',
          PushPermissionState.denied => 'NOTIFS OFF',
          PushPermissionState.unsupported => 'NO PUSH',
          PushPermissionState.notRequested => 'ENABLE PUSH',
        };
        final color = switch (state) {
          PushPermissionState.granted => Colors.greenAccent,
          PushPermissionState.denied => Colors.redAccent,
          PushPermissionState.unsupported => Colors.grey,
          PushPermissionState.notRequested => Colors.orangeAccent,
        };
        return InkWell(
          onTap: state == PushPermissionState.granted ||
                  state == PushPermissionState.unsupported
              ? null
              : service.requestPermission,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: StatusChip(
              label: label,
              color: color,
              icon: state == PushPermissionState.granted
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
            ),
          ),
        );
      },
    );
  }
}
