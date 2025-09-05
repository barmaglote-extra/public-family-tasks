import 'package:flutter/material.dart';
import 'package:tasks/pages/task_items/regular_task_item.dart';
import 'package:tasks/pages/task_items/task_section_base.dart';

class CompletedTasksSection extends TaskSectionBase {
  final Function(bool?, int?) onTaskStateChanged;

  const CompletedTasksSection({
    super.key,
    required super.tasks,
    required super.collections,
    required super.onTaskTap,
    required super.onTaskDelete,
    required super.onTaskRestore,
    required this.onTaskStateChanged,
    required super.onCollectionTap,
  }) : super(title: 'Completed tasks');

  @override
  Widget buildTaskContent(BuildContext context, task, collection) {
    return RegularTaskItem(
      task: task,
      collection: collection,
      onTaskStateChanged: onTaskStateChanged,
      onTaskTap: onTaskTap,
      onCollectionTap: onCollectionTap,
    );
  }
}
