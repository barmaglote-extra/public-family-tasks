import 'package:flutter/foundation.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/subtask_fields.dart';
import 'package:tasks/models/subtodo.dart';
import 'package:tasks/models/subtodo_data.dart';
import 'package:tasks/repository/sqllitedb.dart';

class SubTasksService {
  static final String _entity = 'subtasks';
  late final SQLLiteDB _db;

  SubTasksService() {
    _db = locator<SQLLiteDB>();
  }

  Future<void> addItem(SubTodoData todoData) async {
    try {
      await _db.addItem(_entity, todoData.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<SubTodo?> getItemById(int id) async {
    var item = await _db.getItemByField(_entity, 'id', id);
    return item != null ? SubTodo.fromMap(item) : null;
  }

  Future<SubTodo?> getItemsByTaskId(int taskId) async {
    var item = await _db.getItemByField(_entity, SubtaskFields.taskId, taskId);
    return item != null ? SubTodo.fromMap(item) : null;
  }

  Future<List<T>?> getItemsByField<T extends SubTodo>(Map<String, dynamic> conditions) async {
    var result = await _db.getItemsByFields(_entity, conditions);

    if (result == null || result.isEmpty) {
      return null;
    }

    try {
      final mutableResult = List<Map<String, dynamic>>.from(result);

      mutableResult.sort((a, b) {
        final orderA = a[SubtaskFields.orderIndex] ?? 0;
        final orderB = b[SubtaskFields.orderIndex] ?? 0;
        final comparison = orderA.compareTo(orderB);
        return comparison != 0 ? comparison : (a['id'] as int).compareTo(b['id'] as int);
      });

      final mappedResult = mutableResult.map<T>((map) => SubTodo.fromMap(map) as T).toList();

      return mappedResult;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateItemById(int id, Map<String, dynamic> data) async {
    await _db.updateItemById(_entity, id, data);
  }

  Future<void> deleteItemById(int id) async {
    await _db.deleteItemById(_entity, id);
  }

  Future<void> updateSubTasksOrder(List<SubTodo> subTasks) async {
    for (int i = 0; i < subTasks.length; i++) {
      await updateItemById(subTasks[i].id, {
        SubtaskFields.orderIndex: i,
      });
    }
  }

  Future<int> getNextOrderIndex(int taskId) async {
    final result = await _db.getItemsByFilter(_entity,
        where: '${SubtaskFields.taskId} = ?',
        whereArgs: [taskId],
        orderBy: '${SubtaskFields.orderIndex} DESC',
        limit: 1);

    if (result.isEmpty) return 0;

    final lastOrderIndex = result.first[SubtaskFields.orderIndex] ?? 0;
    return lastOrderIndex + 1;
  }

  Future<List<T>?> getItemsByFilter<T extends SubTodo>(
      {String? where, List<dynamic>? whereArgs, String? orderBy = 'order_index, id', int limit = 1000}) async {
    final result =
        await _db.getItemsByFilter(_entity, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);

    if (result.isEmpty) return null;
    return result.map<T>((map) => SubTodo.fromMap(map) as T).toList();
  }

  Future<void> initializeOrderIndexes() async {
    try {
      final result = await _db.getItemsByFilter(_entity,
          where: 'order_index IS NULL OR order_index = 0', orderBy: 'task_id, id', limit: 1000);

      if (result.isEmpty) {
        return;
      }

      final Map<int, List<Map<String, dynamic>>> taskGroups = {};
      for (final item in result) {
        final taskId = item['task_id'] as int;
        taskGroups.putIfAbsent(taskId, () => []).add(item);
      }

      for (final entry in taskGroups.entries) {
        final subtasks = entry.value;

        for (int i = 0; i < subtasks.length; i++) {
          final subtask = subtasks[i];
          await updateItemById(subtask['id'], {
            SubtaskFields.orderIndex: i,
          });
        }
      }
    } catch (e) {
      // Handle the case where the subtasks table doesn't exist yet
      // This can happen when the app is run for the first time
      if (kDebugMode) {
        print('Subtasks table not yet created, skipping order index initialization: $e');
      }
    }
  }
}
