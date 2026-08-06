import 'notification_plan_model.dart';

class NotificationSyncPayload {
  const NotificationSyncPayload({
    required this.deliveryEnabled,
    required this.reason,
    required this.cancelAllLocalPlans,
    required this.device,
    required this.serverNow,
    required this.channelsVersion,
    required this.horizonHours,
    required this.plans,
    required this.cancelPlanIds,
    required this.inAppEvents,
  });

  final bool deliveryEnabled;
  final String? reason;
  final bool cancelAllLocalPlans;
  final Map<String, dynamic> device;
  final DateTime? serverNow;
  final int channelsVersion;
  final int horizonHours;
  final List<NotificationPlanModel> plans;
  final List<String> cancelPlanIds;
  final List<NotificationPlanModel> inAppEvents;

  factory NotificationSyncPayload.empty() => const NotificationSyncPayload(
    deliveryEnabled: false,
    reason: 'not_synced',
    cancelAllLocalPlans: false,
    device: <String, dynamic>{},
    serverNow: null,
    channelsVersion: 1,
    horizonHours: 72,
    plans: <NotificationPlanModel>[],
    cancelPlanIds: <String>[],
    inAppEvents: <NotificationPlanModel>[],
  );

  factory NotificationSyncPayload.fromJson(Map<String, dynamic> json) {
    return NotificationSyncPayload(
      deliveryEnabled: json['delivery_enabled'] == true,
      reason: json['reason']?.toString(),
      cancelAllLocalPlans: json['cancel_all_local_plans'] == true,
      device: Map<String, dynamic>.from((json['device'] as Map?) ?? const {}),
      serverNow: DateTime.tryParse((json['server_now'] ?? '').toString()),
      channelsVersion:
          int.tryParse((json['channels_version'] ?? '1').toString()) ?? 1,
      horizonHours:
          int.tryParse((json['horizon_hours'] ?? '72').toString()) ?? 72,
      plans: ((json['plans'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                NotificationPlanModel.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
      cancelPlanIds:
          ((json['cancel_plan_ids'] as List?) ??
                  (json['cancelled_plan_ids'] as List?) ??
                  const [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
      inAppEvents: ((json['in_app_events'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                NotificationPlanModel.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}
