import 'package:flutter/material.dart';
import 'package:tasks/pages/task_items/recurrent_task_item.dart';
import 'package:tasks/pages/task_items/task_section_base.dart';

class RecurrentTasksSection extends TaskSectionBase {
  const RecurrentTasksSection({
    super.key,
    required super.tasks,
    required super.collections,
    required super.onTaskTap,
    required super.onTaskDelete,
    required super.onTaskRestore,
    required super.onCollectionTap,
  }) : super(title: 'All Recurrent Tasks');

  @override
  Widget buildTaskContent(BuildContext context, task, collection) {
    return RecurrentTaskItem(task: task, collection: collection, onTaskTap: onTaskTap);
  }
}
