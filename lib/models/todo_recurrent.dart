import 'package:tasks/models/todo.dart';
import 'package:tasks/models/todo_data.dart';
import 'package:tasks/models/todo_fields.dart';

class TodoRecurrent extends Todo {
  final String? recurrenceInterval;

  TodoRecurrent(
      {required super.id,
      required super.name,
      required super.isCompleted,
      required this.recurrenceInterval,
      required super.collectionId,
      required super.description,
      required super.taskType,
      required super.urgency});

  factory TodoRecurrent.fromMap(Map<String, dynamic> map) {
    return TodoRecurrent(
        id: map[TodoFields.id],
        name: map[TodoFields.name],
        isCompleted: false,
        recurrenceInterval: map[TodoFields.recurrenceRule],
        collectionId: map[TodoFields.collectionId],
        description: map[TodoFields.description],
        taskType: map[TodoFields.taskType],
        urgency: map[TodoFields.urgency] ?? 0);
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      TodoFields.id: id,
      TodoFields.name: name,
      TodoFields.isCompleted: isCompleted,
      TodoFields.recurrenceRule: recurrenceInterval,
      TodoFields.taskType: 'recurrent',
      TodoFields.collectionId: collectionId,
      TodoFields.description: description,
      TodoFields.urgency: urgency
    };
  }

  TodoData toTodoData() {
    return TodoData(
        name: name,
        collectionId: collectionId,
        taskType: 'recurrent',
        recurrenceRule: recurrenceInterval ?? '',
        isCompleted: isCompleted ? 1 : 0,
        description: description,
        urgency: urgency,
        dueDate: null);
  }
}
