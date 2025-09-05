import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:tasks/main.dart';
import 'package:tasks/repository/sqllitedb.dart';

class TaskCompletionsService {
  static final String _entity = 'task_completions';
  late final SQLLiteDB _db;

  TaskCompletionsService() {
    _db = locator<SQLLiteDB>();
  }

  Future<void> markTaskAsNotCompleted(int taskId, DateTime date, {String? recurrenceRule}) async {
    if (recurrenceRule == 'yearly') {
      final yearStart = DateFormat('yyyy-MM-dd').format(DateTime(date.year, 1, 1));
      final yearEnd = DateFormat('yyyy-MM-dd').format(DateTime(date.year, 12, 31));
      await _db.deleteRecords(
        _entity,
        'task_id = ? AND completion_date BETWEEN ? AND ?',
        [taskId, yearStart, yearEnd],
      );
      if (kDebugMode) {
        print("Deleted all yearly completions for task $taskId in ${date.year}");
      }
    } else {
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);
      await _db.deleteRecords(_entity, 'task_id = ? AND completion_date = ?', [taskId, formattedDate]);
      if (kDebugMode) {
        print("Deleted completion for task $taskId on $formattedDate");
      }
    }
  }

  Future<bool> isTaskCompletedOnDate(int taskId, DateTime date) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    Map<String, dynamic> conditions = {'task_id': taskId, 'completion_date': formattedDate};

    final result = await _db.getItemsByFields(_entity, conditions);
    return result?.isNotEmpty ?? false;
  }

  Future<List<DateTime>> getTaskCompletions(int taskId, DateTime startDate, DateTime endDate, int limit) async {
    final result = await _db.getItemsByFilter(
      _entity,
      where: 'task_id = ? AND completion_date BETWEEN ? AND ?',
      whereArgs: [
        taskId,
        DateFormat('yyyy-MM-dd').format(startDate),
        DateFormat('yyyy-MM-dd').format(endDate),
      ],
      limit: limit,
    );

    return result.map((map) {
      final parsedDate = DateTime.parse(map['completion_date'] as String);
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    }).toList();
  }

  Future<void> markTaskAsCompleted(int taskId, DateTime date) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final existing = await _db
        .getItemsByFilter(_entity, where: 'task_id = ? AND completion_date = ?', whereArgs: [taskId, formattedDate]);

    if (existing.isEmpty) {
      await _db.addItem(_entity, {'task_id': taskId, 'completion_date': formattedDate});
    }
  }
}
