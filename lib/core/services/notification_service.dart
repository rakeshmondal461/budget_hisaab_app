import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/tasks/models/task_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Fallback if unable to detect local timezone
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );

    // Request permissions on Android 13+
    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> updateTaskReminder(List<TaskModel> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notificationsEnabled') ?? true;

    if (!enabled) {
      await _notificationsPlugin.cancel(1001);
      return;
    }

    final pendingTasks = tasks
        .where((t) => t.status == TaskStatus.todo || t.status == TaskStatus.inProgress)
        .toList();

    if (pendingTasks.isEmpty) {
      await _notificationsPlugin.cancel(1001);
      return;
    }

    // Count by priority
    int critical = 0;
    int high = 0;
    int medium = 0;
    int low = 0;
    for (final t in pendingTasks) {
      switch (t.priority) {
        case TaskPriority.critical:
          critical++;
          break;
        case TaskPriority.high:
          high++;
          break;
        case TaskPriority.medium:
          medium++;
          break;
        case TaskPriority.low:
          low++;
          break;
      }
    }

    // Prepare message
    final total = pendingTasks.length;
    String body = "You have $total pending tasks to complete.";
    final details = <String>[];
    if (critical > 0) details.add("$critical Critical");
    if (high > 0) details.add("$high High");
    if (medium > 0) details.add("$medium Medium");
    if (low > 0) details.add("$low Low");
    if (details.isNotEmpty) {
      body += " (${details.join(', ')} priority)";
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_task_reminder_channel',
      'Daily Task Reminders',
      channelDescription: 'Reminder for daily pending tasks scheduled at 7 PM',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    final scheduledTime = _nextInstanceOf7PM();

    await _notificationsPlugin.zonedSchedule(
      1001,
      '📋 Pending Tasks Reminder',
      body,
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf7PM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      19, // 7 PM
      0,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
