import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/subtodo.dart';
import 'package:tasks/models/todo_regular.dart';
import 'package:tasks/models/todo_recurrent.dart';
import 'package:tasks/services/sub_tasks_service.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:intl/intl.dart';

class ShareService {
  final _tasksService = locator<TasksService>();
  final _subTasksService = locator<SubTasksService>();

  /// Share a task as JSON file
  Future<void> shareTask(int taskId) async {
    try {
      final taskData = await _exportTaskToJson(taskId);
      final file = await _createShareFile(taskData, taskId);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Shared task: ${taskData['name']}',
        subject: 'Task shared from Tasks App',
      );
    } catch (e) {
      throw Exception('Failed to share task: $e');
    }
  }

  /// Export task data to JSON format
  Future<Map<String, dynamic>> _exportTaskToJson(int taskId) async {
    final task = await _tasksService.getItemById(taskId);
    if (task == null) {
      throw Exception('Task not found');
    }

    List<Map<String, dynamic>> subtasks = [];

    // Get subtasks for regular tasks only
    if (task.taskType == 'regular') {
      final subTasksList = await _subTasksService.getItemsByField<SubTodo>({'task_id': taskId});
      if (subTasksList != null) {
        subtasks = subTasksList
            .map((subtask) => {
                  'id': subtask.id,
                  'name': subtask.name,
                  'description': subtask.description,
                  'isCompleted': subtask.isCompleted,
                  'urgency': subtask.urgency,
                  'dueDate': subtask.dueDate?.millisecondsSinceEpoch,
                  'orderIndex': subtask.orderIndex,
                })
            .toList();
      }
    }

    return {
      'fileType': 'TASK_SHARE', // Type identifier for future expansion
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'task': {
        'name': task.name,
        'description': task.description,
        'urgency': task.urgency,
        'isCompleted': task.isCompleted,
        'taskType': task.taskType,
        'dueDate': task.taskType == 'regular' ? (task as TodoRegular).dueDate?.millisecondsSinceEpoch : null,
        'recurrenceInterval': task.taskType == 'recurrent' ? (task as TodoRecurrent).recurrenceInterval : null,
      },
      'subtasks': subtasks,
      'subtaskCount': subtasks.length,
    };
  }

  /// Create temporary file for sharing
  Future<File> _createShareFile(Map<String, dynamic> taskData, int taskId) async {
    final directory = await getTemporaryDirectory();
    final fileName = 'task_${taskId}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.tasks';
    final file = File('${directory.path}/$fileName');

    final jsonString = const JsonEncoder.withIndent('  ').convert(taskData);
    await file.writeAsString(jsonString);

    return file;
  }

  /// Import task from JSON data
  Future<Map<String, dynamic>?> importTaskFromJson(String jsonString) async {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);

      // Validate file type
      if (data['fileType'] != 'TASK_SHARE') {
        throw Exception('Invalid file type. Expected TASK_SHARE.');
      }

      // Validate version compatibility
      final version = data['version'] as String?;
      if (version != '1.0') {
        throw Exception('Unsupported file version: $version');
      }

      return data;
    } catch (e) {
      throw Exception('Failed to import task: $e');
    }
  }

  /// Parse imported task data for NewTaskPage
  Map<String, dynamic> parseImportedTaskForForm(Map<String, dynamic> importedData) {
    final taskData = importedData['task'] as Map<String, dynamic>;
    final subtasks = importedData['subtasks'] as List<dynamic>? ?? [];

    return {
      'name': taskData['name'] as String? ?? '',
      'description': taskData['description'] as String? ?? '',
      'urgency': taskData['urgency'] as int? ?? 0,
      'taskType': taskData['taskType'] as String? ?? 'regular',
      'dueDate': taskData['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(taskData['dueDate'] as int) : null,
      'recurrenceInterval': taskData['recurrenceInterval'] as String?,
      'subtasks': subtasks
          .map((subtask) => {
                'name': subtask['name'] as String? ?? '',
                'description': subtask['description'] as String? ?? '',
                'urgency': subtask['urgency'] as int? ?? 0,
                'dueDate':
                    subtask['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(subtask['dueDate'] as int) : null,
              })
          .toList(),
      'isImported': true, // Flag to indicate this is imported data
      'originalExportDate': importedData['exportDate'] as String?,
    };
  }
}
