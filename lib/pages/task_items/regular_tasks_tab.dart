import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tasks/models/todo.dart';
import 'package:tasks/models/todo_regular.dart';
import 'package:tasks/models/todo_collection.dart';
import 'package:tasks/models/subtodo.dart';
import 'package:tasks/main.dart';
import 'package:tasks/services/sub_tasks_service.dart';
import 'package:tasks/services/update_provider.dart';
import 'package:tasks/services/localization_service.dart';

class RegularTasksTab extends StatefulWidget {
  final List incompleteTasks;
  final List completedTasks;
  final List<ToDoCollection> collections;
  final Function(int) onTaskTap;
  final Function(int) onCollectionTap;
  final Function(bool?, int?) onTaskStateChanged;
  final Function(Todo) onTaskDelete;
  final Function(dynamic) onTaskRestore;
  final bool isEmpty;

  const RegularTasksTab({
    super.key,
    required this.incompleteTasks,
    required this.completedTasks,
    required this.collections,
    required this.onTaskTap,
    required this.onTaskStateChanged,
    required this.onTaskDelete,
    required this.onTaskRestore,
    required this.onCollectionTap,
    required this.isEmpty,
  });

  @override
  State<RegularTasksTab> createState() => _RegularTasksTabState();
}

class _RegularTasksTabState extends State<RegularTasksTab> {
  final _subTasksService = locator<SubTasksService>();
  final _updateProvider = locator<UpdateProvider>();
  final Map<int, bool> _expandedTasks = {};
  Map<int, List<SubTodo>> _taskSubTasks = {};

  @override
  void initState() {
    super.initState();
    _loadSubTasksForAllTasks();
    _updateProvider.addListener(_loadSubTasksForAllTasks);
  }

  @override
  void dispose() {
    _updateProvider.removeListener(_loadSubTasksForAllTasks);
    super.dispose();
  }

  Future<void> _loadSubTasksForAllTasks() async {
    final allTasks = [...widget.incompleteTasks, ...widget.completedTasks];
    final Map<int, List<SubTodo>> newTaskSubTasks = {};

    for (final task in allTasks) {
      if (task is TodoRegular) {
        final subTasks = await _subTasksService.getItemsByField<SubTodo>({'task_id': task.id});
        newTaskSubTasks[task.id] = subTasks ?? [];
      }
    }

    if (mounted) {
      setState(() {
        _taskSubTasks = newTaskSubTasks;
      });
    }
  }

  Future<void> _updateSubTaskState(int subTaskId, bool isCompleted) async {
    await _subTasksService.updateItemById(subTaskId, {
      'is_completed': isCompleted ? 1 : 0,
    });
    _updateProvider.notifyListeners();
    await _loadSubTasksForAllTasks();
  }

  void _toggleTaskExpansion(int taskId) {
    setState(() {
      _expandedTasks[taskId] = !(_expandedTasks[taskId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.incompleteTasks.isEmpty && widget.completedTasks.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.task_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Consumer<LocalizationService>(
                  builder: (context, localizationService, child) {
                    return Text(
                      localizationService.translate('tasks.no_one_time_tasks'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Consumer<LocalizationService>(
                  builder: (context, localizationService, child) {
                    return Text(
                      localizationService.translate('tasks.create_first_task'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.incompleteTasks.isNotEmpty)
            _buildTaskSection(
              title: context.read<LocalizationService>().translate('tasks.pending_tasks'),
              tasks: widget.incompleteTasks,
              icon: Icons.pending_actions,
              color: Colors.orange,
              isCompleted: false,
            ),
          if (widget.incompleteTasks.isNotEmpty && widget.completedTasks.isNotEmpty) const SizedBox(height: 16),
          if (widget.completedTasks.isNotEmpty)
            _buildTaskSection(
              title: context.read<LocalizationService>().translate('tasks.completed_tasks'),
              tasks: widget.completedTasks,
              icon: Icons.check_circle_outline,
              color: Colors.green,
              isCompleted: true,
            ),
        ],
      ),
    );
  }

  Widget _buildTaskSection({
    required String title,
    required List tasks,
    required IconData icon,
    required Color color,
    required bool isCompleted,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${tasks.length} task${tasks.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildListView(tasks, isCompleted),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List tasks, bool isCompleted) {
    return Column(
      children: tasks.map<Widget>((task) {
        final TodoRegular todo = task as TodoRegular;
        final isExpanded = _expandedTasks[todo.id] ?? false;
        final subTasks = _taskSubTasks[todo.id] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            children: [
              // Main task
              Dismissible(
                key: Key(todo.id.toString()),
                direction: DismissDirection.endToStart, // Only left swipe for delete on CollectionPage
                dismissThresholds: const {
                  DismissDirection.endToStart: 0.8, // Left swipe (delete)
                },
                movementDuration: const Duration(milliseconds: 300),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Row(
                    children: [
                      Icon(Icons.delete, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Delete',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.delete, color: Colors.white),
                    ],
                  ),
                ),
                confirmDismiss: (direction) async {
                  // Only delete action on CollectionPage
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
                onDismissed: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    // Delete task
                    await widget.onTaskDelete(todo);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${todo.name} deleted'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () => widget.onTaskRestore(todo),
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border(
                        left: BorderSide(
                          color: _getDueDateBorderColor(todo.dueDate, todo.isCompleted),
                          width: 4.0,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => widget.onTaskStateChanged(!todo.isCompleted, todo.id),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: todo.isCompleted ? Colors.green.shade600 : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: todo.isCompleted ? Colors.green.shade600 : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: todo.isCompleted
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        todo.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: todo.isCompleted ? Colors.grey.shade600 : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (todo.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              todo.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (todo.dueDate != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: _getDueDateColor(todo.dueDate!),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDueDate(todo.dueDate!),
                                  style: TextStyle(
                                    color: _getDueDateColor(todo.dueDate!),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: (todo.urgency != null && todo.urgency! > 0)
                          ? Container(
                              margin: const EdgeInsets.only(left: 8.0),
                              child: Icon(
                                Icons.priority_high,
                                color: _getUrgencyColor(todo.urgency),
                                size: 20,
                              ),
                            )
                          : null,
                      onTap: () => widget.onTaskTap(todo.id),
                    ),
                  ),
                ),
              ),
              // Subtask expansion strip
              if (subTasks.isNotEmpty)
                Container(
                  width: double.infinity,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _toggleTaskExpansion(todo.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.list_alt,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${subTasks.length} subtask${subTasks.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Expanded subtasks
              if (isExpanded && subTasks.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer<LocalizationService>(
                          builder: (context, localizationService, child) {
                            return Text(
                              localizationService.translate('subtasks.subtasks'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        ...subTasks.map((subTask) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                // Subtask checkbox - always first for alignment
                                GestureDetector(
                                  onTap: () => _updateSubTaskState(subTask.id, !subTask.isCompleted),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: subTask.isCompleted ? Colors.green.shade600 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: subTask.isCompleted ? Colors.green.shade600 : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    child: subTask.isCompleted
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Urgency indicator - now after checkbox for better alignment
                                if (subTask.urgency != null && subTask.urgency! > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6.0),
                                    child: Text(
                                      '!',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _getUrgencyColor(subTask.urgency),
                                      ),
                                    ),
                                  ),
                                // Subtask name
                                Expanded(
                                  child: Text(
                                    subTask.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: subTask.isCompleted ? Colors.grey.shade600 : null,
                                    ),
                                  ),
                                ),
                                // Subtask due date
                                if (subTask.dueDate != null)
                                  Text(
                                    DateFormat('dd.MM.yyyy').format(subTask.dueDate!),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        // Collapse button
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: TextButton.icon(
                              onPressed: () => _toggleTaskExpansion(todo.id),
                              icon: const Icon(Icons.expand_less, size: 18),
                              label: Consumer<LocalizationService>(
                                builder: (context, localizationService, child) {
                                  return Text(
                                    localizationService.translate('subtasks.collapse'),
                                  );
                                },
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade600,
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getDueDateBorderColor(DateTime? dueDate, bool isCompleted) {
    if (dueDate == null || isCompleted) return Colors.grey.shade300;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) {
      return Colors.red; // Overdue
    } else if (due.isAtSameMomentAs(today)) {
      return Colors.yellow; // Due today
    } else {
      return Colors.grey.shade300; // Future
    }
  }

  Color _getUrgencyColor(int? urgency) {
    if (urgency == null || urgency == 0) return Colors.grey.shade300;
    switch (urgency) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.red;
      default:
        return Colors.grey.shade300;
    }
  }

  Color _getDueDateColor(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) {
      return Colors.red; // Overdue
    } else if (due.isAtSameMomentAs(today)) {
      return Colors.orange; // Due today
    } else {
      return Colors.blue; // Future due date
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) {
      final difference = today.difference(due).inDays;
      return 'Overdue by $difference day${difference != 1 ? 's' : ''}';
    } else if (due.isAtSameMomentAs(today)) {
      return 'Due today';
    } else if (due.isAtSameMomentAs(tomorrow)) {
      return 'Due tomorrow';
    } else {
      return 'Due ${DateFormat('MMM dd').format(dueDate)}';
    }
  }
}
