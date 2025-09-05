import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/task_notification.dart';
import 'package:tasks/pages/sub_task_page.dart';
import 'package:tasks/pages/task_page.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/services/update_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  late tz.Location _local;
  bool _isInitialized = false;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (_isInitialized) return;
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('notification_icon');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response);
      },
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );

    tz.initializeTimeZones();
    _local = tz.local;
    await requestPermissions();
    _isInitialized = true;
  }

  Future<List<TaskNotification>?> getNotificationsByTaskId(int taskId, bool isFindSubTask) async {
    await init();
    if (!_isInitialized || !Platform.isAndroid) {
      return null;
    }

    final notifications = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();

    final filteredNotifications = notifications
        .map((notification) {
          if (notification.payload == null || !notification.payload!.contains(';')) {
            return null;
          }

          final parsedPayload = _parseNotificationPayload(notification.payload);
          if (parsedPayload == null) {
            return null;
          }

          final parsedTaskId = parsedPayload['taskId'] as int;
          final isSubTask = parsedPayload['isSubTask'] as bool;

          if (parsedTaskId == taskId && isFindSubTask == (isSubTask)) {
            return TaskNotification(
              taskId: parsedTaskId,
              scheduledDate: parsedPayload['scheduledDate'] as String,
              request: notification,
              isSubTask: isSubTask,
            );
          }
          return null;
        })
        .where((notification) => notification != null)
        .cast<TaskNotification>()
        .toList();

    return filteredNotifications;
  }

  @pragma('vm:entry-point')
  static void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {}

  static void onDidReceiveNotificationResponse(NotificationResponse response) {}

  Map<String, dynamic>? _parseNotificationPayload(String? payload) {
    if (payload == null || !payload.contains(';')) {
      if (kDebugMode) {
        print("Invalid payload format: $payload");
      }
      return null;
    }

    final parts = payload.split(';');
    if (parts.isEmpty) {
      if (kDebugMode) {
        print("Payload is empty after split: $payload");
      }
      return null;
    }

    final taskId = int.tryParse(parts[0]);
    if (taskId == null) {
      if (kDebugMode) {
        print("Failed to parse taskId from payload: $payload");
      }
      return null;
    }

    String scheduledDate = '';
    if (parts.length > 1) {
      scheduledDate = parts[1];
    }

    bool isSubTask = false;
    if (parts.length > 2) {
      isSubTask = bool.tryParse(parts[2]) ?? false;
    }

    return {
      'taskId': taskId,
      'scheduledDate': scheduledDate,
      'isSubTask': isSubTask,
    };
  }

  void _handleNotificationTap(NotificationResponse response) async {
    if (kDebugMode) {
      print('Notification action tapped: actionId=${response.actionId}, payload=${response.payload}');
    }
    final actionId = response.actionId;
    final payload = response.payload;
    final parsed = _parseNotificationPayload(payload);
    if (parsed == null) {
      if (kDebugMode) {
        print('Notification payload parse failed');
      }
      return;
    }

    final int taskId = parsed['taskId'] as int;

    if (actionId == 'complete') {
      try {
        await locator<TasksService>().markTaskAsCompleted(taskId);
        if (kDebugMode) {
          print('Task $taskId marked as completed from notification');
        }
        locator<UpdateProvider>().notifyListeners();
        final nav = navigatorKey.currentState;
        if (nav != null) {
          nav.pushNamedAndRemoveUntil('tasks/duedate', (route) => false);
        } else {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => navigatorKey.currentState?.pushNamedAndRemoveUntil('tasks/duedate', (route) => false));
        }
        return;
      } catch (_) {}
    }

    if (actionId == 'postpone_1d') {
      try {
        await locator<TasksService>().postponeTaskDueDate(taskId, days: 1);
        if (kDebugMode) {
          print('Task $taskId postponed by 1 day from notification');
        }
        locator<UpdateProvider>().notifyListeners();
        final nav = navigatorKey.currentState;
        if (nav != null) {
          nav.pushNamedAndRemoveUntil('tasks/duedate', (route) => false);
        } else {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => navigatorKey.currentState?.pushNamedAndRemoveUntil('tasks/duedate', (route) => false));
        }
        return;
      } catch (_) {}
    }

    _navigateFromPayload(payload);
  }

  void _navigateFromPayload(String? payload) {
    final parsedPayload = _parseNotificationPayload(payload);
    if (parsedPayload == null) {
      if (kDebugMode) {
        print("Failed to parse payload: $payload");
      }
      return;
    }

    final int taskId = parsedPayload['taskId'] as int;
    final bool isSubTask = parsedPayload['isSubTask'] as bool;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (kDebugMode) print('Navigator state is null, cannot navigate');
      return;
    }

    if (isSubTask) {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => SubTaskPage(title: "Sub Task", taskId: taskId),
        ),
      );
    } else {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => TaskPage(title: "Task", taskId: taskId),
        ),
      );
    }
  }

  Future<void> handleLaunchFromNotification() async {
    try {
      final details = await _flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
      if (details == null) return;

      final bool didLaunch = details.didNotificationLaunchApp;
      if (!didLaunch) return;

      final String? payload = details.notificationResponse?.payload;
      if (payload == null) return;

      if (navigatorKey.currentState == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _navigateFromPayload(payload));
        return;
      }

      _navigateFromPayload(payload);
    } catch (e) {
      if (kDebugMode) {
        print('Error handling launch from notification: $e');
      }
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final notificationGranted = await androidPlugin?.requestNotificationsPermission();
      final exactAlarmGranted = await androidPlugin?.requestExactAlarmsPermission();

      if (notificationGranted == false || exactAlarmGranted == false) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text(
              "Permissions missing: Notifications: $notificationGranted, Exact Alarms: $exactAlarmGranted",
            ),
          ),
        );
      }
    }
  }

  Future<void> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    }
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel_id',
          'Task Notifications',
          channelDescription: 'Notifications for task reminders',
          category: AndroidNotificationCategory.reminder,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          autoCancel: false,
          ongoing: false,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'complete',
              'Mark as done',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'postpone_1d',
              'Postpone +1 day',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    required bool isSubTask,
  }) async {
    try {
      if (Platform.isAndroid) {
        final uniqueId = DateTime.now().millisecondsSinceEpoch % 10000;
        final scheduledTZ = tz.TZDateTime.from(scheduledDate, _local);

        final nowTZ = tz.TZDateTime.now(_local);

        if (scheduledTZ.isBefore(nowTZ)) {
          if (kDebugMode) {
            print("Error: Scheduled time is in the past");
          }
          return;
        }

        await _flutterLocalNotificationsPlugin.zonedSchedule(
          uniqueId,
          title,
          body,
          scheduledTZ,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'task_channel_id',
              'Task Notifications',
              channelDescription: 'Notifications for Family Tasks',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              icon: 'notification_icon',
              category: AndroidNotificationCategory.alarm,
              actions: <AndroidNotificationAction>[
                AndroidNotificationAction(
                  'complete',
                  'Mark as done',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  'postpone_1d',
                  'Postpone +1 day',
                  showsUserInterface: true,
                ),
              ],
            ),
          ),
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: "${payload ?? ''};${DateFormat('dd.MM.yyyy HH:mm').format(scheduledDate)};$isSubTask",
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } else {
        if (kDebugMode) {
          showDialog(
            context: navigatorKey.currentContext!,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text("No support for this platform"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await init();
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> showNotificationWithBadge({
    required int count,
    String title = 'Urgent Tasks',
    String body = 'You have urgent tasks',
  }) async {
    await init();
    if (!_isInitialized || !Platform.isAndroid) return;

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'urgent_tasks',
      'Urgent Tasks',
      channelDescription: 'Notifications for urgent tasks',
      importance: Importance.max,
      priority: Priority.high,
      number: count,
      autoCancel: false,
    );
    NotificationDetails details = NotificationDetails(android: androidDetails);

    debugPrint("Showing notification with count: $count");
    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      '$body: $count',
      details,
    );
  }
}
