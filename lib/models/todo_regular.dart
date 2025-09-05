import 'package:tasks/models/todo.dart';
import 'package:tasks/models/todo_data.dart';
import 'package:tasks/models/todo_fields.dart';

class TodoRegular extends Todo {
  final DateTime? dueDate;

  TodoRegular({
    required super.id,
    required super.name,
    required super.isCompleted,
    required super.collectionId,
    required super.description,
    required super.taskType,
    required super.urgency,
    required this.dueDate,
  });

  factory TodoRegular.fromMap(Map<String, dynamic> map) {
    return TodoRegular(
      collectionId: map[TodoFields.collectionId],
      id: map[TodoFields.id],
      name: map[TodoFields.name],
      isCompleted: map[TodoFields.isCompleted] == 1,
      description: map[TodoFields.description],
      taskType: map[TodoFields.taskType],
      urgency: map[TodoFields.urgency],
      dueDate: map[TodoFields.dueDate] != null ? DateTime.fromMillisecondsSinceEpoch(map[TodoFields.dueDate]) : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      TodoFields.id: id,
      TodoFields.name: name,
      TodoFields.isCompleted: isCompleted,
      TodoFields.taskType: 'regular',
      TodoFields.collectionId: collectionId,
      TodoFields.description: description,
      TodoFields.urgency: urgency,
      TodoFields.dueDate: dueDate?.millisecondsSinceEpoch,
    };
  }

  TodoData toTodoData() {
    return TodoData(
      name: name,
      collectionId: collectionId,
      taskType: 'regular',
      recurrenceRule: '',
      isCompleted: isCompleted ? 1 : 0,
      description: description,
      urgency: urgency,
      dueDate: dueDate?.millisecondsSinceEpoch,
    );
  }
}
