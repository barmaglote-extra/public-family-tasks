import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/todo_fields.dart';
import 'package:tasks/models/todo_recurrent.dart';
import 'package:tasks/services/task_completions_service.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/services/update_provider.dart';
import 'package:tasks/utils/date_utils.dart';

class RecurringTasksWidget extends StatefulWidget {
  final String title;
  final String recurrenceType; // 'daily', 'weekly', 'monthly', 'yearly'
  final int? collectionId;
  final Function(int) onTaskTap;

  const RecurringTasksWidget({
    super.key,
    required this.title,
    required this.recurrenceType,
    required this.onTaskTap,
    this.collectionId,
  });

  @override
  State<RecurringTasksWidget> createState() => _RecurringTasksWidgetState();
}

class _RecurringTasksWidgetState extends State<RecurringTasksWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _tasksService = locator<TasksService>();
  final _taskCompletionsService = locator<TaskCompletionsService>();
  final _updateProvider = locator<UpdateProvider>();
  List<TodoRecurrent>? _tasks = [];
  Map<String, bool> _completionStatus = {};
  List<DateTime> _datesToShow = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    WidgetsBinding.instance.addObserver(this);
    _updateProvider.addListener(_loadTasks);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateProvider.removeListener(_loadTasks);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTasks();
    }
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    final tasks = await _tasksService.getItemsByField<TodoRecurrent>(
        {TodoFields.recurrenceRule: widget.recurrenceType, TodoFields.collectionId: widget.collectionId});
    _generateDatesToShow();

    await _loadCompletionStatuses(tasks);

    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _deleteTask(int id) async {
    await _tasksService.deleteItemById(id);
    _loadTasks();
  }

  void _generateDatesToShow() {
    final now = DateTime.now();
    _datesToShow = [];

    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));

    switch (widget.recurrenceType) {
      case 'daily':
        for (int i = 0; i < 7; i++) {
          _datesToShow.add(currentWeekStart.add(Duration(days: i)));
        }
        break;
      case 'weekly':
        final firstDayOfMonth = DateTime(now.year, now.month, 1);
        final firstMonday = firstDayOfMonth.weekday == DateTime.monday
            ? firstDayOfMonth
            : firstDayOfMonth.add(Duration(days: DateTime.monday - firstDayOfMonth.weekday));
        for (int i = 0; i < 5; i++) {
          final monday = firstMonday.add(Duration(days: i * 7));
          if (monday.month == now.month) {
            _datesToShow.add(monday);
          }
        }
        break;
      case 'monthly':
        final isFirstHalf = now.month <= 6;
        final startMonth = isFirstHalf ? 1 : 7;
        for (int i = 0; i < 6; i++) {
          _datesToShow.add(DateTime(now.year, startMonth + i, 1));
        }
        break;
      case 'yearly':
        _datesToShow.add(DateTime(now.year, 1, 1));
        break;
    }
  }

  Future<void> _loadCompletionStatuses(List<TodoRecurrent>? tasks) async {
    _completionStatus = {};

    if (tasks == null) return;
    if (tasks.isEmpty || _datesToShow.isEmpty) return;

    final startDate = _datesToShow.first;
    final endDate = _datesToShow.last;

    final adjustedEndDate = widget.recurrenceType == 'daily'
        ? endDate
        : widget.recurrenceType == 'weekly'
            ? endDate.add(const Duration(days: 6))
            : widget.recurrenceType == 'monthly'
                ? DateTime(endDate.year, endDate.month + 1, 0)
                : DateTime(endDate.year, 12, 31);

    for (final task in tasks) {
      final completions = await _taskCompletionsService.getTaskCompletions(task.id, startDate, adjustedEndDate, 400);

      for (final date in _datesToShow) {
        String key = _getCompletionKey(task.id, date);

        switch (widget.recurrenceType) {
          case 'daily':
            _completionStatus[key] = completions.any((completion) =>
                completion.year == date.year && completion.month == date.month && completion.day == date.day);
            break;
          case 'weekly':
            final weekStart = date;
            final weekEnd = weekStart.add(const Duration(days: 6));
            _completionStatus[key] = completions.any((completion) =>
                completion.isAfter(weekStart.subtract(const Duration(days: 1))) &&
                completion.isBefore(weekEnd.add(const Duration(days: 1))));
            break;
          case 'monthly':
            _completionStatus[key] =
                completions.any((completion) => completion.year == date.year && completion.month == date.month);
            break;
          case 'yearly':
            _completionStatus[key] = completions.any((completion) => completion.year == date.year);
            break;
        }
      }
    }
  }

  bool _isCurrentPeriod(DateTime date) {
    final now = DateTime.now();
    switch (widget.recurrenceType) {
      case 'daily':
        return date.year == now.year && date.month == now.month && date.day == now.day;
      case 'weekly':
        final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
        final dateWeekStart = date.subtract(Duration(days: date.weekday - 1));
        return currentWeekStart.year == dateWeekStart.year &&
            getISOWeekNumber(currentWeekStart) == getISOWeekNumber(dateWeekStart);
      case 'monthly':
        return date.year == now.year && date.month == now.month;
      case 'yearly':
        return date.year == now.year;
      default:
        return false;
    }
  }

  String _getCompletionKey(int taskId, DateTime date) {
    switch (widget.recurrenceType) {
      case 'daily':
        return '$taskId-${DateFormat('yyyy-MM-dd').format(date)}';
      case 'weekly':
        final weekNumber = getISOWeekNumber(date);
        return '$taskId-${date.year}-W$weekNumber';
      case 'monthly':
        return '$taskId-${DateFormat('yyyy-MM').format(date)}';
      case 'yearly':
        return '$taskId-${DateFormat('yyyy').format(date)}';
      default:
        return '$taskId-${DateFormat('yyyy-MM-dd').format(date)}';
    }
  }

  Future<void> _toggleTaskCompletion(TodoRecurrent task, DateTime date) async {
    final key = _getCompletionKey(task.id, date);
    final isCurrentlyCompleted = _completionStatus[key] ?? false;

    if (isCurrentlyCompleted) {
      await _taskCompletionsService.markTaskAsNotCompleted(task.id, date);
    } else {
      await _taskCompletionsService.markTaskAsCompleted(task.id, date);
    }

    setState(() {
      _completionStatus[key] = !isCurrentlyCompleted;
    });
  }

  String _formatColumnHeader(DateTime date) {
    switch (widget.recurrenceType) {
      case 'daily':
        return DateFormat('E', 'en').format(date);
      case 'weekly':
        int weekNumber = getISOWeekNumber(date);
        return 'W$weekNumber';
      case 'monthly':
        return DateFormat('MMM').format(date);
      case 'yearly':
        return DateFormat('yyyy').format(date);
      default:
        return DateFormat('dd.MM').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _tasks == null || _tasks!.isEmpty
            ? const SizedBox.shrink()
            : _buildTaskList(context);
  }

  Widget _buildTaskList(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Adjust column width based on recurrence type - yearly needs more space for year display
    final dateColumnWidth = widget.recurrenceType == 'yearly' ? 50.0 : 30.0;
    final totalDateColumnsWidth = dateColumnWidth * _datesToShow.length;
    final taskColumnWidth = (screenWidth - totalDateColumnsWidth - 25).clamp(0.0, screenWidth);

    String title = widget.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Simple header without card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(_getRecurrenceIcon(widget.recurrenceType), size: 18, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${_tasks!.length})',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        // Table content without card wrapper
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Table header
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Container(
                      width: taskColumnWidth,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Text(
                        'Task',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    ..._datesToShow.map((date) => Container(
                          width: dateColumnWidth,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Colors.grey.shade300, width: 0.5),
                            ),
                          ),
                          child: Text(
                            _formatColumnHeader(date),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: widget.recurrenceType == 'yearly' ? 10 : 11,
                              color: _isCurrentPeriod(date) ? Colors.red.shade600 : Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.visible,
                            maxLines: 1,
                          ),
                        )),
                  ],
                ),
              ),
              // Task rows
              ..._tasks!.asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final task = entry.value;
                  final isLastItem = index == _tasks!.length - 1;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade300),
                        right: BorderSide(color: Colors.grey.shade300),
                        bottom: BorderSide(
                          color: Colors.grey.shade300,
                          width: isLastItem ? 1.0 : 0.5,
                        ),
                      ),
                    ),
                    child: Dismissible(
                      key: Key(task.id.toString()),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10),
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
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Delete task?'),
                              content: const Text('This action will delete the recurring task.'),
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
                        await _deleteTask(task.id);
                      },
                      child: Row(
                        children: [
                          Container(
                            width: taskColumnWidth,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            child: GestureDetector(
                              onTap: () => widget.onTaskTap(task.id),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (task.urgency != null && task.urgency! > 0) ...[
                                        Icon(
                                          Icons.priority_high,
                                          color: task.urgency == 2 ? Colors.red : Colors.orange,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          task.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (task.description != null && task.description!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        task.description!,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          ..._datesToShow.map((date) {
                            final key = _getCompletionKey(task.id, date);
                            final isCompleted = _completionStatus[key] ?? false;

                            return Container(
                              width: dateColumnWidth,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: Colors.grey.shade300, width: 0.5),
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () => _toggleTaskCompletion(task, date),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isCompleted ? Colors.green.shade600 : Colors.transparent,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: isCompleted ? Colors.green.shade600 : Colors.grey.shade400,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isCompleted
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 12,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16), // Space between sections
      ],
    );
  }

  IconData _getRecurrenceIcon(String recurrenceType) {
    switch (recurrenceType) {
      case 'daily':
        return Icons.today;
      case 'weekly':
        return Icons.today;
      case 'monthly':
        return Icons.today;
      case 'yearly':
        return Icons.today;
      default:
        return Icons.today;
    }
  }
}
