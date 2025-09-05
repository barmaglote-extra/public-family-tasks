import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class TaskNotification {
  final int taskId;
  final String scheduledDate;
  final PendingNotificationRequest request;
  final bool isSubTask;

  TaskNotification({
    required this.taskId,
    required this.scheduledDate,
    required this.request,
    required this.isSubTask,
  });
}
