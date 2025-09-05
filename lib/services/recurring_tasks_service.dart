import 'package:tasks/models/todo_recurrent.dart';
import 'package:tasks/main.dart';
import 'package:tasks/services/task_completions_service.dart';
import 'package:tasks/services/tasks_service.dart';

class RecurringTasksService {
  final _tasksService = locator<TasksService>();
  final _taskCompletionsService = locator<TaskCompletionsService>();

  Future<List<TodoRecurrent>?> getRecurringTasks(String recurrenceType, {int? collectionId}) async {
    return await _tasksService.getItemsByField<TodoRecurrent>({
      'recurrenceInterval': recurrenceType,
      if (collectionId != null) 'collectionId': collectionId,
    });
  }

  Future<List<TodoRecurrent>> getTodayRecurringTasks({int? collectionId}) async {
    final allTasks = await _tasksService.getTodayRecurrentTasks();
    if (collectionId == null) return allTasks;
    return allTasks.where((task) => task.collectionId == collectionId).toList();
  }

  Future<Map<int, bool>> getTodayCompletionStatuses(List<TodoRecurrent> tasks) async {
    final completionStatus = <int, bool>{};
    final now = DateTime.now();

    for (final task in tasks) {
      DateTime startDate;
      DateTime endDate;

      switch (task.recurrenceInterval?.toLowerCase()) {
        case 'weekly':
          final daysSinceMonday = (now.weekday - DateTime.monday) % 7;
          startDate = now.subtract(Duration(days: daysSinceMonday));
          endDate = startDate.add(const Duration(days: 6));
          break;
        case 'monthly':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'yearly':
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year, 12, 31);
          break;
        case 'daily':
        default:
          startDate = now.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
          endDate = startDate;
          break;
      }

      final completions = await _taskCompletionsService.getTaskCompletions(
        task.id,
        startDate,
        endDate,
        400,
      );

      bool isCompleted;
      switch (task.recurrenceInterval?.toLowerCase()) {
        case 'weekly':
          isCompleted = completions.any((completion) =>
              completion.isAfter(startDate.subtract(const Duration(days: 1))) &&
              completion.isBefore(endDate.add(const Duration(days: 1))));
          break;
        case 'monthly':
          isCompleted =
              completions.any((completion) => completion.year == startDate.year && completion.month == startDate.month);
          break;
        case 'yearly':
          isCompleted = completions.any((completion) => completion.year == startDate.year);
          break;
        case 'daily':
        default:
          isCompleted = completions.any((completion) =>
              completion.year == startDate.year &&
              completion.month == startDate.month &&
              completion.day == startDate.day);
          break;
      }

      completionStatus[task.id] = isCompleted;
    }

    return completionStatus;
  }

  Future<Map<String, int>> getTodayRecurringTasksStats({int? collectionId}) async {
    final tasks = await getTodayRecurringTasks(collectionId: collectionId);
    final completionStatus = await getTodayCompletionStatuses(tasks);

    return {
      'total': tasks.length,
      'completed': completionStatus.values.where((status) => status).length,
    };
  }
}
