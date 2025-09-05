import 'package:tasks/models/subtask_fields.dart';

class SubTodoData {
  final String name;
  final int taskId;
  final String? description;
  final int isCompleted;
  final int? urgency;
  final int? dueDate;
  final int orderIndex;

  SubTodoData(
      {required this.name,
      required this.taskId,
      required this.isCompleted,
      required this.description,
      required this.urgency,
      required this.dueDate,
      this.orderIndex = 0});

  Map<String, dynamic> toMap() {
    return {
      SubtaskFields.name: name,
      SubtaskFields.taskId: taskId,
      SubtaskFields.isCompleted: isCompleted,
      SubtaskFields.description: description,
      SubtaskFields.urgency: urgency,
      SubtaskFields.dueDate: dueDate,
      SubtaskFields.orderIndex: orderIndex,
    };
  }
}
