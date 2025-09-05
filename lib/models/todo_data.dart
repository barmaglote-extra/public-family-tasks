import 'package:tasks/models/todo_fields.dart';

class TodoData {
  final String name;
  final int collectionId;
  final String taskType;
  final String recurrenceRule;
  final String? description;
  final int isCompleted;
  final int? urgency;
  final int? dueDate;

  TodoData(
      {required this.name,
      required this.collectionId,
      required this.taskType,
      required this.recurrenceRule,
      required this.isCompleted,
      required this.description,
      required this.urgency,
      required this.dueDate});

  Map<String, dynamic> toMap() {
    return {
      TodoFields.name: name,
      TodoFields.collectionId: collectionId,
      TodoFields.taskType: taskType,
      TodoFields.recurrenceRule: recurrenceRule,
      TodoFields.isCompleted: isCompleted,
      TodoFields.description: description,
      TodoFields.urgency: urgency,
      TodoFields.dueDate: dueDate
    };
  }
}
