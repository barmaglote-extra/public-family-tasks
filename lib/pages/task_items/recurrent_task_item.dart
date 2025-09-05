import 'package:flutter/material.dart';
import 'package:tasks/models/todo_collection.dart';

class RecurrentTaskItem extends StatelessWidget {
  final dynamic task;
  final ToDoCollection? collection;
  final Function(int) onTaskTap;

  const RecurrentTaskItem({
    super.key,
    required this.task,
    required this.collection,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white12,
        boxShadow: [
          BoxShadow(
            blurStyle: BlurStyle.outer,
            color: Colors.black12,
            spreadRadius: 0,
            blurRadius: 1,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: ListTile(
        title: Text(task.name),
        subtitle: task.description != null && task.description != ''
            ? Text(
                (task.description ?? ''),
                style: const TextStyle(color: Colors.grey, fontSize: 12, decorationStyle: TextDecorationStyle.wavy),
              )
            : null,
        trailing: Text(task.recurrenceInterval ?? ''),
        leading: const Icon(Icons.refresh),
        onTap: () => onTaskTap(task.id),
      ),
    );
  }
}
