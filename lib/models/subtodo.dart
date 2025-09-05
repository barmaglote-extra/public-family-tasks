import 'package:tasks/models/subtask_fields.dart';
import 'package:tasks/models/subtodo_data.dart';
import 'package:tasks/models/todo.dart';

class SubTodo extends Todo {
  final int taskId;
  final DateTime? dueDate;
  final int orderIndex;

  SubTodo(
      {required super.collectionId,
      required super.taskType,
      required this.taskId,
      required this.dueDate,
      this.orderIndex = 0,
      required super.id,
      required super.name,
      required super.isCompleted,
      required super.description,
      required super.urgency});

  @override
  Map<String, dynamic> toMap() {
    return {
      SubtaskFields.id: id,
      SubtaskFields.name: name,
      SubtaskFields.isCompleted: isCompleted,
      SubtaskFields.taskId: taskId,
      SubtaskFields.description: description,
      SubtaskFields.urgency: urgency,
      SubtaskFields.dueDate: dueDate?.millisecondsSinceEpoch,
      SubtaskFields.orderIndex: orderIndex,
    };
  }

  SubTodoData toTodoData() {
    return SubTodoData(
      name: name,
      taskId: taskId,
      isCompleted: isCompleted ? 1 : 0,
      description: description,
      urgency: urgency,
      dueDate: dueDate?.millisecondsSinceEpoch,
      orderIndex: orderIndex,
    );
  }

  factory SubTodo.fromMap(Map<String, dynamic> map) {
    return SubTodo(
      taskId: map[SubtaskFields.taskId],
      id: map[SubtaskFields.id],
      name: map[SubtaskFields.name],
      isCompleted: map[SubtaskFields.isCompleted] == 1,
      description: map[SubtaskFields.description],
      urgency: map[SubtaskFields.urgency],
      dueDate:
          map[SubtaskFields.dueDate] != null ? DateTime.fromMillisecondsSinceEpoch(map[SubtaskFields.dueDate]) : null,
      orderIndex: map[SubtaskFields.orderIndex] ?? 0,
      taskType: 'regular',
      collectionId: -1,
    );
  }
}
