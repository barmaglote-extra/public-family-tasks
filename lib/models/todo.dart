import 'package:tasks/models/todo_fields.dart';
import 'package:tasks/models/todo_recurrent.dart';
import 'package:tasks/models/todo_regular.dart';

abstract class Todo {
  final int id;
  final String name;
  final bool isCompleted;
  final int collectionId;
  final String? description;
  final String? taskType;
  final int? urgency;

  Todo(
      {required this.id,
      required this.name,
      required this.isCompleted,
      required this.collectionId,
      required this.description,
      required this.taskType,
      required this.urgency});

  Map<String, dynamic> toMap();

  static Todo fromMap(Map<String, dynamic> map) {
    if (map[TodoFields.taskType] == 'recurrent') {
      return TodoRecurrent.fromMap(map);
    } else {
      return TodoRegular.fromMap(map);
    }
  }
}
