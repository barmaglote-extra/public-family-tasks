import 'package:flutter/material.dart';
import 'package:tasks/pages/task_items/recurring_tasks.dart';

class RecurrentTasksTab extends StatelessWidget {
  final List recurrentTasks;
  final int collectionId;
  final Function(int) onTaskTap;
  final Function(dynamic) onTaskRestore;
  final bool isEmpty;

  const RecurrentTasksTab({
    super.key,
    required this.collectionId,
    required this.recurrentTasks,
    required this.onTaskTap,
    required this.onTaskRestore,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    if (recurrentTasks.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No recurring tasks',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first recurring task to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
      child: RecurringTasks(
        collectionId: collectionId,
        onTaskTap: onTaskTap,
        onTaskRestore: onTaskRestore,
      ),
    );
  }
}
