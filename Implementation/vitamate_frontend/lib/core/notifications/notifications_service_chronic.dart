part of 'notifications_service.dart';

Future<void> _syncChronicMedicationReminders(
  List<ChronicMedicationReminderPlan> plans,
) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();
  await NotificationsService._cancelPendingInRange(
    NotificationIds.chronicMedicationBase,
    NotificationIds.chronicMedicationRangeEnd,
  );

  for (final plan in plans) {
    await _scheduleChronicMedicationPlan(plan);
  }
}

Future<void> _scheduleChronicMedicationPlan(
  ChronicMedicationReminderPlan plan,
) async {
  if (plan.recurrenceDays.isEmpty) {
    await _scheduleChronicRecurringSlot(
      scheduleId: plan.scheduleId,
      medicationName: plan.medicationName,
      conditionName: plan.conditionName,
      dosage: plan.dosage,
      hour: plan.hour,
      minute: plan.minute,
      leadMinutes: plan.leadMinutes,
      weekday: null,
    );
    return;
  }

  for (final day in plan.recurrenceDays) {
    await _scheduleChronicRecurringSlot(
      scheduleId: plan.scheduleId,
      medicationName: plan.medicationName,
      conditionName: plan.conditionName,
      dosage: plan.dosage,
      hour: plan.hour,
      minute: plan.minute,
      leadMinutes: plan.leadMinutes,
      weekday: day,
    );
  }
}

Future<void> _scheduleChronicRecurringSlot({
  required int scheduleId,
  required String medicationName,
  required String conditionName,
  required String dosage,
  required int hour,
  required int minute,
  required int leadMinutes,
  required int? weekday,
}) async {
  final doseTime = weekday == null
      ? NotificationsService._nextTimeTodayOrTomorrow(
          hour: hour,
          minute: minute,
        )
      : NotificationsService._nextWeekdayTime(
          weekday: weekday + DateTime.monday,
          hour: hour,
          minute: minute,
        );
  final match = weekday == null
      ? DateTimeComponents.time
      : DateTimeComponents.dayOfWeekAndTime;
  final weekdaySlot = weekday == null ? 0 : weekday + 1;

  await NotificationsService._plugin.zonedSchedule(
    NotificationsService._chronicRecurringNotificationId(
      scheduleId: scheduleId,
      weekdaySlot: weekdaySlot,
      isLeadReminder: false,
    ),
    'Medication reminder',
    NotificationsService._chronicReminderBody(
      medicationName: medicationName,
      conditionName: conditionName,
      dosage: dosage,
      isLeadReminder: false,
    ),
    doseTime,
    NotificationsService._details(
      NotificationChannels.chronicMedicationId,
      NotificationChannels.chronicMedicationName,
      channelDescription: NotificationChannels.chronicMedicationDesc,
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: match,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );

  if (leadMinutes <= 0) {
    return;
  }

  final leadTime = doseTime.subtract(Duration(minutes: leadMinutes));
  if (!leadTime.isAfter(tz.TZDateTime.now(tz.local))) {
    return;
  }

  await NotificationsService._plugin.zonedSchedule(
    NotificationsService._chronicRecurringNotificationId(
      scheduleId: scheduleId,
      weekdaySlot: weekdaySlot,
      isLeadReminder: true,
    ),
    'Upcoming medication',
    NotificationsService._chronicReminderBody(
      medicationName: medicationName,
      conditionName: conditionName,
      dosage: dosage,
      isLeadReminder: true,
    ),
    leadTime,
    NotificationsService._details(
      NotificationChannels.chronicMedicationId,
      NotificationChannels.chronicMedicationName,
      channelDescription: NotificationChannels.chronicMedicationDesc,
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: match,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> _scheduleChronicMedicationSnooze({
  required int scheduleId,
  required String medicationName,
  required String conditionName,
  required String dosage,
  required DateTime reminderAt,
}) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();
  await _cancelChronicMedicationSnooze(scheduleId);

  final scheduled = tz.TZDateTime.from(reminderAt, tz.local);
  await NotificationsService._plugin.zonedSchedule(
    NotificationsService._chronicSnoozeNotificationId(scheduleId),
    'Snoozed medication',
    NotificationsService._chronicReminderBody(
      medicationName: medicationName,
      conditionName: conditionName,
      dosage: dosage,
      isLeadReminder: false,
    ),
    scheduled,
    NotificationsService._details(
      NotificationChannels.chronicMedicationId,
      NotificationChannels.chronicMedicationName,
      channelDescription: NotificationChannels.chronicMedicationDesc,
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> _cancelChronicMedicationSnooze(int scheduleId) async {
  await NotificationsService._plugin.cancel(
    NotificationsService._chronicSnoozeNotificationId(scheduleId),
  );
}
