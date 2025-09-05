import 'package:tasks/main.dart';
import 'package:tasks/models/todo.dart';
import 'package:tasks/services/tasks_service.dart';

class DueDateTasksService {
  final _tasksService = locator<TasksService>();

  Future<List<Todo>?> getDueDateTasks({int limit = 100}) async {
    return await _tasksService.getItemsByFilter(
      where: 'due_date IS NOT NULL AND task_type = ?',
      whereArgs: ['regular'],
      orderBy: 'due_date',
      limit: limit,
    );
  }

  Map<String, List<dynamic>> splitTasksByCompletion(List<dynamic>? tasks) {
    if (tasks == null) {
      return {
        'incomplete': [],
        'completed': [],
      };
    }

    final incompleteTasks = tasks.where((task) => !task.isCompleted).toList();
    final completedTasks = tasks.where((task) => task.isCompleted).toList();

    return {
      'incomplete': incompleteTasks,
      'completed': completedTasks,
    };
  }

  /// Получает статистику задач с сроком выполнения
  Future<Map<String, int>> getDueDateTasksStats({int limit = 100}) async {
    final tasks = await getDueDateTasks(limit: limit);
    final splitTasks = splitTasksByCompletion(tasks);

    return {
      'total': tasks?.length ?? 0,
      'completed': splitTasks['completed']!.length,
    };
  }
}
