class NotificationPlanModel {
  const NotificationPlanModel({
    required this.planId,
    required this.kind,
    required this.category,
    required this.type,
    required this.priority,
    required this.title,
    required this.body,
    required this.route,
    required this.payload,
    required this.scheduleSpec,
    required this.deliverAt,
    required this.expireAt,
    required this.soundProfile,
    required this.exactRequired,
    required this.foregroundBehavior,
    required this.dedupeKey,
    required this.status,
    this.revision = 1,
    this.channelId = '',
    this.cancellationKey = '',
    this.sourceEventType = '',
    this.sourceEventId = '',
  });

  final String planId;
  final String kind;
  final String category;
  final String type;
  final int priority;
  final String title;
  final String body;
  final String route;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> scheduleSpec;
  final DateTime? deliverAt;
  final DateTime? expireAt;
  final String soundProfile;
  final bool exactRequired;
  final String foregroundBehavior;
  final String dedupeKey;
  final String status;
  final int revision;
  final String channelId;
  final String cancellationKey;
  final String sourceEventType;
  final String sourceEventId;

  factory NotificationPlanModel.fromJson(Map<String, dynamic> json) {
    return NotificationPlanModel(
      planId: (json['plan_id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      priority: int.tryParse((json['priority'] ?? '0').toString()) ?? 0,
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      route: (json['route'] ?? '').toString(),
      payload: Map<String, dynamic>.from((json['payload'] as Map?) ?? const {}),
      scheduleSpec: Map<String, dynamic>.from(
        (json['schedule_spec'] as Map?) ?? const {},
      ),
      deliverAt: DateTime.tryParse((json['deliver_at'] ?? '').toString()),
      expireAt: DateTime.tryParse((json['expire_at'] ?? '').toString()),
      soundProfile: (json['sound_profile'] ?? '').toString(),
      exactRequired: json['exact_required'] == true,
      foregroundBehavior: (json['foreground_behavior'] ?? '').toString(),
      dedupeKey: (json['dedupe_key'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      revision: int.tryParse((json['revision'] ?? '1').toString()) ?? 1,
      channelId: (json['channel_id'] ?? '').toString(),
      cancellationKey: (json['cancellation_key'] ?? '').toString(),
      sourceEventType: (json['source_event_type'] ?? '').toString(),
      sourceEventId: (json['source_event_id'] ?? '').toString(),
    );
  }

  Map<String, dynamic> schedulingFingerprint() => <String, dynamic>{
    'revision': revision,
    'category': category,
    'type': type,
    'title': title,
    'body': body,
    'route': route,
    'payload': payload,
    'schedule_spec': scheduleSpec,
    'deliver_at': deliverAt?.toUtc().toIso8601String(),
    'expire_at': expireAt?.toUtc().toIso8601String(),
    'channel_id': channelId,
    'sound_profile': soundProfile,
    'exact_required': exactRequired,
  };
}
