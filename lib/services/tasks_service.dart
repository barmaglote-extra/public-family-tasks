import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/todo.dart';
import 'package:tasks/models/todo_data.dart';
import 'package:tasks/models/todo_recurrent.dart';
import 'package:tasks/models/todo_regular.dart';
import 'package:tasks/repository/sqllitedb.dart';

final String columnTaskType = "task_type";

class TasksService {
  static final String _entity = 'tasks';
  static const String _totalCompletedKey = 'total_completed_tasks';
  late final SQLLiteDB _db;

  TasksService() {
    _db = locator<SQLLiteDB>();
  }

  Future<void> addItem(TodoData todoData) async {
    await _db.addItem(_entity, todoData.toMap());

    if (kDebugMode) {
      print('Task is added: ${todoData.name}');
    }
  }

  Future<Todo?> getItemById(int id) async {
    var item = await _db.getItemByField(_entity, 'id', id);
    return item != null ? Todo.fromMap(item) : null;
  }

  Future<List<T>?> getItemsByField<T extends Todo>(Map<String, dynamic> conditions) async {
    var result = await _db.getItemsByFields(_entity, conditions);

    return result?.map<T>((map) => Todo.fromMap(map) as T).toList();
  }

  Future<void> updateItemById(int id, Map<String, dynamic> data) async {
    await _db.updateItemById(_entity, id, data);
  }

  Future<void> deleteItemById(int id) async {
    await _db.deleteItemById(_entity, id);
  }

  Future<Map<String, int>> getTaskStats(int collectionId) async {
    final totalTasks = await _countTasks(collectionId);
    final completedTasks = await _countTasks(collectionId, isCompleted: true);

    return {
      'total': totalTasks,
      'completed': completedTasks,
    };
  }

  Future<Map<String, int>> getTaskCompletionStats() async {
    final completedCount = await _db.countRecords(
      'tasks',
      where: "is_completed = ? and task_type = 'regular'",
      whereArgs: [1],
    );

    final incompleteCount = await _db.countRecords(
      'tasks',
      where: "is_completed = ? and task_type = 'regular'",
      whereArgs: [0],
    );

    return {
      'completed': completedCount,
      'incomplete': incompleteCount,
    };
  }

  Future<Map<String, int>> getRegularTaskStats() async {
    final total = await _db.countRecords('tasks', where: 'task_type = ?', whereArgs: ['regular']);
    final completed =
        await _db.countRecords('tasks', where: 'task_type = ? AND is_completed = 1', whereArgs: ['regular']);
    final incomplete = total - completed;
    return {
      'completed': completed,
      'incomplete': incomplete,
    };
  }

  Future<Map<String, int>> getRecurrentTaskStats() async {
    final daily = await _db
        .countRecords('tasks', where: 'task_type = ? AND recurrence_rule = ?', whereArgs: ['recurrent', 'daily']);
    final weekly = await _db
        .countRecords('tasks', where: 'task_type = ? AND recurrence_rule = ?', whereArgs: ['recurrent', 'weekly']);
    final monthly = await _db
        .countRecords('tasks', where: 'task_type = ? AND recurrence_rule = ?', whereArgs: ['recurrent', 'monthly']);
    final yearly = await _db
        .countRecords('tasks', where: 'task_type = ? AND recurrence_rule = ?', whereArgs: ['recurrent', 'yearly']);
    return {
      'daily': daily,
      'weekly': weekly,
      'monthly': monthly,
      'yearly': yearly,
    };
  }

  Future<List<Todo>> searchTasks(String query) async {
    if (query.isEmpty) return [];
    final results = await getItemsByFilter<Todo>(
      where: 'task_type IN (?, ?) AND (name LIKE ? OR description LIKE ?)',
      whereArgs: ['regular', 'recurrent', '%$query%', '%$query%'],
      limit: 20,
    );
    return results ?? [];
  }

  Future<List<TodoRecurrent>> getTodayRecurrentTasksByInterval(String recurrenceInterval) async {
    final result = await getItemsByFilter<TodoRecurrent>(
      where: 'task_type = ? AND recurrence_rule = ?',
      whereArgs: ['recurrent', recurrenceInterval.toLowerCase()],
      orderBy: 'urgency DESC',
      limit: 1000,
    );
    return result ?? [];
  }

  Future<int> _countTasks(int collectionId, {bool isCompleted = false}) async {
    var where = isCompleted ? 'collection_id = ? AND is_completed = 1' : 'collection_id = ?';
    where += " AND task_type = 'regular'";
    return await _db.countRecords('tasks', where: where, whereArgs: [collectionId]);
  }

  Future<List<T>?> getItemsByFilter<T extends Todo>(
      {String? where, List<dynamic>? whereArgs, String? orderBy = 'id', int limit = 1}) async {
    final result =
        await _db.getItemsByFilter(_entity, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);

    if (result.isEmpty) return null;
    return result.map<T>((map) => Todo.fromMap(map) as T).toList();
  }

  Future<Map<String, int>> getRegularTaskDueDateStats() async {
    return await _db.getRegularTaskDueDateStats();
  }

  Future<List<T>> getTodayRecurrentTasks<T extends TodoRecurrent>() async {
    final result = await getItemsByFilter<T>(
      where: 'task_type = ?',
      whereArgs: ['recurrent'],
      orderBy: 'urgency DESC',
      limit: 1000,
    );

    return result ?? [];
  }

  Future<List<Todo>> getUrgentOverdueTasks() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;

    final result = await getItemsByFilter<Todo>(
      where: 'is_completed = ? AND urgency = ? AND task_type = ? AND due_date IS NOT NULL AND due_date <= ?',
      whereArgs: [0, 2, 'regular', todayStart],
      orderBy: 'due_date ASC',
      limit: 100,
    );

    return result ?? [];
  }

  Future<List<Todo>> getRegularTasksByDate(DateTime date) async {
    final dateString = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch.toString();

    final result = await getItemsByFilter<Todo>(
      where: 'task_type = ? AND due_date = ?',
      whereArgs: ['regular', dateString],
      orderBy: 'urgency DESC, id ASC',
      limit: 1000,
    );

    return result ?? [];
  }

  Future<int> getTodayTasksCount() async {
    final today = DateTime.now();
    final todayString = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch.toString();

    final result = await getItemsByFilter<Todo>(
      where: 'task_type = ? AND due_date = ? AND is_completed = ?',
      whereArgs: ['regular', todayString, 0],
      limit: 1000,
    );

    return result?.length ?? 0;
  }

  Future<Map<DateTime, int>> getRegularTasksCountByDateRange(DateTime start, DateTime end) async {
    final startString = DateTime(start.year, start.month, start.day).millisecondsSinceEpoch.toString();
    final endString = DateTime(end.year, end.month, end.day).millisecondsSinceEpoch.toString();

    final result = await getItemsByFilter<Todo>(
      where: 'task_type = ? AND due_date >= ? AND due_date <= ?',
      whereArgs: ['regular', startString, endString],
      orderBy: 'due_date ASC',
      limit: 10000,
    );

    final tasks = result ?? [];
    final taskCountMap = <DateTime, int>{};

    for (var task in tasks) {
      final dueDate = (task as TodoRegular).dueDate;
      if (dueDate != null) {
        final normalizedDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
        taskCountMap[normalizedDate] = (taskCountMap[normalizedDate] ?? 0) + 1;
      }
    }

    return taskCountMap;
  }

  Future<void> markTaskAsCompleted(int taskId) async {
    final existing = await _db.getItemByField(_entity, 'id', taskId);

    if (existing == null) {
      return;
    }
    await _db.updateItemById(_entity, taskId, {'is_completed': 1});
    await _updateTotalCompletedCounter(taskId, 1);
  }

  Future<void> markTaskAsNotCompleted(int taskId) async {
    final existing = await _db.getItemByField(_entity, 'id', taskId);

    if (existing == null) {
      return;
    }
    await _db.updateItemById(_entity, taskId, {'is_completed': 0});
    await _updateTotalCompletedCounter(taskId, -1);
  }

  Future<void> _updateTotalCompletedCounter(int taskId, int delta) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_totalCompletedKey) ?? 0;

    final task = await _db.getItemByField('tasks', 'id', taskId.toString());
    if (task == null) return;

    final taskType = task['task_type'] as String;
    if (taskType == 'regular' && delta == 0) {
      return;
    }

    int newValue = current + delta;
    if (newValue < 0) newValue = 0;
    await prefs.setInt(_totalCompletedKey, newValue);
  }

  Future<int> _calculateInitialCompletedTasks() async {
    final regularCompleted = await getItemsByFilter<Todo>(where: 'task_type = ?', whereArgs: ['regular'], limit: 1000);

    int regularCount = regularCompleted?.length ?? 0;

    return regularCount;
  }

  Future<void> initTotalCompletedCounter() async {
    final prefs = await SharedPreferences.getInstance();
    int? initialCount = prefs.getInt(_totalCompletedKey);
    int currentCount = await _calculateInitialCompletedTasks();
    if (initialCount == null || initialCount < currentCount) {
      initialCount = currentCount;
      await prefs.setInt(_totalCompletedKey, initialCount);
      if (kDebugMode) {
        print("Initialized total_completed_tasks to $initialCount");
      }
    }
  }

  Future<int> getTotalCompletedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalCompletedKey) ?? 0;
  }

  Future<void> postponeTaskDueDate(int taskId, {int days = 1}) async {
    final existing = await _db.getItemByField(_entity, 'id', taskId);

    if (existing == null) {
      return;
    }

    int? dueTimestamp = existing['due_date'] as int?;
    DateTime baseDate;
    if (dueTimestamp != null) {
      final currentDue = DateTime.fromMillisecondsSinceEpoch(dueTimestamp);
      baseDate = DateTime(currentDue.year, currentDue.month, currentDue.day);
    } else {
      final now = DateTime.now();
      baseDate = DateTime(now.year, now.month, now.day);
    }

    final newDue = baseDate.add(Duration(days: days));
    await _db.updateItemById(_entity, taskId, {'due_date': newDue.millisecondsSinceEpoch});
  }
}
