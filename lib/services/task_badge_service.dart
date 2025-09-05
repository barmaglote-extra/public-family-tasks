import 'package:flutter/material.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:tasks/main.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/services/notification_service.dart';

class TaskBadgeService with WidgetsBindingObserver {
  final _tasksService = locator<TasksService>();
  final _notificationService = locator<NotificationService>();

  TaskBadgeService() {
    initialize();
  }

  Future<void> initialize() async {
    bool supported = await AppBadgePlus.isSupported();
    debugPrint("Badges supported: $supported");
    await updateTasksAndBadge(doNotify: false);
  }

  Future<void> updateTasksAndBadge({bool doNotify = false}) async {
    try {
      final tasks = await _tasksService.getUrgentOverdueTasks();
      debugPrint("Tasks found: ${tasks.length}");
      if (tasks.isNotEmpty) {
        if (doNotify) {
          await _notificationService.showImmediateNotification(
            id: 0,
            title: "Urgent Tasks",
            body: "You have ${tasks.length} urgent task${tasks.length > 1 ? 's' : ''}",
          );
        }
        AppBadgePlus.updateBadge(tasks.length);
      } else {
        AppBadgePlus.updateBadge(0);
      }
    } catch (e) {
      debugPrint('Error updating badge: $e');
      AppBadgePlus.updateBadge(0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      updateTasksAndBadge(doNotify: true);
    }
  }
}
