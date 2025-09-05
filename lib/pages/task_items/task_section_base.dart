import 'package:flutter/material.dart';
import 'package:tasks/models/todo.dart';
import 'package:tasks/models/todo_collection.dart';

abstract class TaskSectionBase extends StatelessWidget {
  final String title;
  final List tasks;
  final List<ToDoCollection> collections;
  final Function(int) onTaskTap;
  final Function(Todo) onTaskDelete;
  final Function(dynamic) onTaskRestore;
  final Function(int) onCollectionTap;

  const TaskSectionBase({
    super.key,
    required this.title,
    required this.tasks,
    required this.collections,
    required this.onTaskTap,
    required this.onTaskDelete,
    required this.onTaskRestore,
    required this.onCollectionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 1),
          ListView.builder(
            cacheExtent: 1000,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              ToDoCollection? collection = collections.isNotEmpty
                  ? collections.firstWhere(
                      (c) => c.id == task.collectionId,
                      orElse: () => ToDoCollection(id: 0, name: 'Unknown', description: ''),
                    )
                  : null;
              return _buildTaskItem(context, task, collection);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, dynamic task, ToDoCollection? collection) {
    return Dismissible(
      key: Key(task.id.toString()),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.8,
        DismissDirection.endToStart: 0.8,
      },
      movementDuration: const Duration(milliseconds: 300),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete task?'),
              content: const Text('This action cannot be undone.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('Delete'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        );
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        onTaskDelete(task);
      },
      child: buildTaskContent(context, task, collection),
    );
  }

  Widget buildTaskContent(BuildContext context, dynamic task, ToDoCollection? collection);
}
