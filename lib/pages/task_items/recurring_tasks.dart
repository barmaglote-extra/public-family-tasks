import 'package:flutter/material.dart';
import 'package:tasks/widgets/recurring_tasks_widget.dart';

class RecurringTasks extends StatefulWidget {
  final int? collectionId;
  final Function(int) onTaskTap;
  final Function(dynamic) onTaskRestore;

  const RecurringTasks({
    super.key,
    this.collectionId,
    required this.onTaskTap,
    required this.onTaskRestore,
  });

  @override
  State<RecurringTasks> createState() => _RecurringTasksPageState();
}

class _RecurringTasksPageState extends State<RecurringTasks> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecurringTasksWidget(
            title: 'Daily',
            recurrenceType: 'daily',
            collectionId: widget.collectionId,
            onTaskTap: widget.onTaskTap,
          ),
          RecurringTasksWidget(
            title: 'Weekly',
            recurrenceType: 'weekly',
            collectionId: widget.collectionId,
            onTaskTap: widget.onTaskTap,
          ),
          RecurringTasksWidget(
            title: 'Monthly',
            recurrenceType: 'monthly',
            collectionId: widget.collectionId,
            onTaskTap: widget.onTaskTap,
          ),
          RecurringTasksWidget(
            title: 'Yearly',
            recurrenceType: 'yearly',
            collectionId: widget.collectionId,
            onTaskTap: widget.onTaskTap,
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}
