import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/mixins/navigation_mixin.dart';
import 'package:tasks/mixins/back_button_mixin.dart';
import 'package:tasks/models/todo_collection.dart';
import 'package:tasks/models/todo_recurrent.dart';
import 'package:tasks/pages/new_collection_page.dart';
import 'package:tasks/pages/new_task_page.dart';
import 'package:tasks/pages/task_page.dart';
import 'package:tasks/services/collections_service.dart';
import 'package:tasks/services/due_date_tasks_service.dart';
import 'package:tasks/services/recurring_tasks_service.dart';
import 'package:tasks/services/task_completions_service.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/widgets/localized_text.dart';

class TodayRecurrentTasksPage extends StatefulWidget {
  final String? recurrenceInterval;
  final _recurringTasksService = locator<RecurringTasksService>();
  final _collectionsService = locator<CollectionsService>();
  final _taskCompletionsService = locator<TaskCompletionsService>();

  TodayRecurrentTasksPage({super.key, this.recurrenceInterval});

  @override
  State<TodayRecurrentTasksPage> createState() => _TodayRecurrentTasksPageState();
}

class _TodayRecurrentTasksPageState extends State<TodayRecurrentTasksPage>
    with NavigationMixin, BackButtonMixin, TickerProviderStateMixin {
  Future<List<TodoRecurrent>> _tasksFuture = Future.value([]);
  Map<int, bool> _completionStatus = {};
  List<ToDoCollection>? collections;
  late Future<Map<String, int>> _dueDateTasksStatsFuture;
  late Future<Map<String, int>> _recurringTasksStatsFuture;
  late Future<int> _todayTasksCountFuture;
  final _dueDateTasksService = locator<DueDateTasksService>();
  final _recurringTasksService = locator<RecurringTasksService>();
  final _tasksService = locator<TasksService>();
  bool _showTaskGridMode = false;
  static const String _gridModeKey = 'recurrent_tasks_grid_mode';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadGridModePreference();
    _loadCollection();
    _loadTasks();
    _dueDateTasksStatsFuture = _dueDateTasksService.getDueDateTasksStats();
    _recurringTasksStatsFuture = _recurringTasksService.getTodayRecurringTasksStats();
    _todayTasksCountFuture = _tasksService.getTodayTasksCount();
  }

  Future<void> _loadGridModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showTaskGridMode = prefs.getBool(_gridModeKey) ?? false;
    });
  }

  Future<void> _saveGridModePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gridModeKey, value);
  }

  Future<void> _toggleGridMode() async {
    final newValue = !_showTaskGridMode;
    setState(() {
      _showTaskGridMode = newValue;
    });
    await _saveGridModePreference(newValue);
  }

  Future<void> _loadTasks() async {
    setState(() {
      _tasksFuture = Future.value([]);
    });

    _tasksFuture = widget.recurrenceInterval != null
        ? _tasksService.getTodayRecurrentTasksByInterval(widget.recurrenceInterval!)
        : _recurringTasksService.getTodayRecurringTasks();
    final tasks = await _tasksFuture;
    _completionStatus = await widget._recurringTasksService.getTodayCompletionStatuses(tasks);
    setState(() {});
  }

  Future<void> _loadCollection() async {
    final data = await widget._collectionsService.getItems();
    collections = data;
  }

  ToDoCollection? getCollection(int id) {
    if (collections == null) return null;
    return collections!.isNotEmpty
        ? collections!.firstWhere(
            (c) => c.id == id,
            orElse: () => ToDoCollection(id: 0, name: 'Unknown', description: ''),
          )
        : null;
  }

  Future<void> _toggleTaskCompletion(TodoRecurrent task) async {
    DateTime completionDate;

    switch (task.recurrenceInterval?.toLowerCase()) {
      case 'weekly':
        final now = DateTime.now();
        final daysSinceMonday = (now.weekday - DateTime.monday) % 7;
        completionDate = now
            .subtract(Duration(days: daysSinceMonday))
            .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
        break;
      case 'monthly':
        final now = DateTime.now();
        completionDate = DateTime(now.year, now.month, 1);
        break;
      case 'daily':
      default:
        final now = DateTime.now();
        completionDate = DateTime(now.year, now.month, now.day);
        break;
    }

    final currentStatus = _completionStatus[task.id] ?? false;
    final newStatus = !currentStatus;

    setState(() {
      _completionStatus[task.id] = newStatus;
    });

    if (newStatus) {
      await widget._taskCompletionsService.markTaskAsCompleted(task.id, completionDate);
    } else {
      await widget._taskCompletionsService.markTaskAsNotCompleted(task.id, completionDate);
    }

    final tasks = await _tasksFuture;
    _completionStatus = await widget._recurringTasksService.getTodayCompletionStatuses(tasks);
    _recurringTasksStatsFuture = _recurringTasksService.getTodayRecurringTasksStats();
    setState(() {});
  }

  void _navigateToTaskPage(int taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskPage(title: "Task", taskId: taskId)),
    ).then((_) {
      _loadTasks();
    });
  }

  void _navigateToNewTaskPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewTaskPage(title: "New Task", collectionId: -1)),
    );

    if (result == true) {
      _loadTasks();
    }
  }

  void _navigateToNewCollectionPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewCollectionPage(title: "New Collection")),
    );

    if (result == true) {
      _loadCollection();
    }
  }

  String _formatRecurrence(String? recurrenceRule) {
    if (recurrenceRule == null) return context.tr('recurrence.no_recurrence');
    switch (recurrenceRule.toLowerCase()) {
      case 'daily':
        return context.tr('recurrence.daily');
      case 'weekly':
        return context.tr('recurrence.weekly');
      case 'monthly':
        return context.tr('recurrence.monthly');
      case 'yearly':
        return context.tr('recurrence.yearly');
      default:
        return recurrenceRule;
    }
  }

  _onBack() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushNamed(context, "/");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          await handleBackButton();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.recurrenceInterval != null
                ? '${_formatRecurrence(widget.recurrenceInterval)} ${context.tr('tasks.recurring_tasks')}'
                : context.tr('tasks.recurring_tasks'),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(
                _showTaskGridMode ? Icons.view_list : Icons.grid_view,
                color: Colors.white,
              ),
              onPressed: _toggleGridMode,
              tooltip: _showTaskGridMode
                  ? context.tr('common.switch_to_list_view')
                  : context.tr('common.switch_to_grid_view'),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_circle_left_outlined),
              onPressed: _onBack,
            ),
          ],
        ),
        drawer: AppDrawer(),
        body: FutureBuilder<List<TodoRecurrent>>(
          future: _tasksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Card(
                  margin: const EdgeInsets.all(16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('common.error_loading_tasks'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Card(
                  margin: const EdgeInsets.all(16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.repeat_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('tasks.no_recurrent_tasks'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.recurrenceInterval != null
                              ? context.tr('tasks.no_interval_tasks',
                                  params: {'interval': _formatRecurrence(widget.recurrenceInterval).toLowerCase()})
                              : context.tr('tasks.create_first_recurring_task'),
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

            final tasks = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _showTaskGridMode ? _buildGridMode(tasks) : _buildListMode(tasks),
            );
          },
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_animationController.isAnimating || !_animationController.isDismissed)
                  Transform.scale(
                    scale: _animationController.value,
                    child: FloatingActionButton(
                      heroTag: 'newTaskButton',
                      onPressed: () {
                        _animationController.reverse();
                        _navigateToNewTaskPage();
                      },
                      backgroundColor: Colors.redAccent,
                      child: const Icon(Icons.add_task, color: Colors.white, size: 26),
                    ),
                  ),
                SizedBox(height: _animationController.value * 10),
                if (_animationController.isAnimating || !_animationController.isDismissed)
                  Transform.scale(
                    scale: _animationController.value,
                    child: FloatingActionButton(
                      heroTag: 'newCollectionButton',
                      onPressed: () {
                        _animationController.reverse();
                        _navigateToNewCollectionPage();
                      },
                      backgroundColor: Colors.redAccent,
                      child: const Icon(Icons.list_alt_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                SizedBox(height: _animationController.value * 10),
                FloatingActionButton(
                  heroTag: 'mainButton',
                  onPressed: () {
                    if (_animationController.isDismissed) {
                      _animationController.forward();
                    } else {
                      _animationController.reverse();
                    }
                  },
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  child: AnimatedIcon(
                    icon: AnimatedIcons.menu_close,
                    progress: _animationController,
                    color: Colors.white,
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: FutureBuilder(
          future: Future.wait([_dueDateTasksStatsFuture, _recurringTasksStatsFuture, _todayTasksCountFuture]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            int dueDatePending = 0;
            int recurringPending = 0;
            int todayTasks = 0;

            if (snapshot.hasData) {
              final dueDateStats = snapshot.data![0] as Map<String, int>;
              final recurringStats = snapshot.data![1] as Map<String, int>;
              final todayTasksCount = snapshot.data![2] as int;

              dueDatePending = (dueDateStats['total'] ?? 0) - (dueDateStats['completed'] ?? 0);
              recurringPending = (recurringStats['total'] ?? 0) - (recurringStats['completed'] ?? 0);
              todayTasks = todayTasksCount;
            }

            return buildBottomNavigationBar(dueDatePending, recurringPending, todayTasks: todayTasks);
          },
        ),
      ),
    );
  }

  Widget _buildListMode(List<TodoRecurrent> tasks) {
    return Column(
      children: tasks.map((task) {
        final isCompleted = _completionStatus[task.id] ?? false;
        final collection = getCollection(task.collectionId);

        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                border: Border(
                  left: BorderSide(
                    color: _getUrgencyColor(task.urgency),
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
                      onTap: () => _toggleTaskCompletion(task),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green.shade600 : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isCompleted ? Colors.green.shade600 : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isCompleted
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
                  task.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? Colors.grey.shade600 : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.repeat,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatRecurrence(task.recurrenceInterval),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (collection != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.folder,
                            size: 14,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            collection.name,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: task.urgency != null && task.urgency! > 0
                    ? Icon(
                        Icons.priority_high,
                        color: _getUrgencyColor(task.urgency),
                        size: 20,
                      )
                    : null,
                onTap: () => _navigateToTaskPage(task.id),
              ),
            ),
          ),
        );
      }).toList(),
    );
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

  Widget _buildGridMode(List<TodoRecurrent> tasks) {
    final groupedTasks = <String, List<TodoRecurrent>>{
      context.tr('recurrence.daily'): [],
      context.tr('recurrence.weekly'): [],
      context.tr('recurrence.monthly'): [],
      context.tr('recurrence.yearly'): [],
    };

    for (var task in tasks) {
      final type = _formatRecurrence(task.recurrenceInterval);
      if (groupedTasks.containsKey(type)) {
        groupedTasks[type]!.add(task);
      }
    }

    final displayGroups = widget.recurrenceInterval != null
        ? {
            _formatRecurrence(widget.recurrenceInterval): groupedTasks[_formatRecurrence(widget.recurrenceInterval)]!,
          }
        : {
            context.tr('recurrence.daily'): groupedTasks[context.tr('recurrence.daily')]!,
            context.tr('recurrence.weekly'): groupedTasks[context.tr('recurrence.weekly')]!,
            context.tr('recurrence.monthly'): groupedTasks[context.tr('recurrence.monthly')]!,
            context.tr('recurrence.yearly'): groupedTasks[context.tr('recurrence.yearly')]!,
          };

    return Column(
      children: displayGroups.entries.where((entry) => entry.value.isNotEmpty).map((entry) {
        final type = entry.key;
        final groupTasks = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getRecurrenceIcon(type),
                        size: 20,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${groupTasks.where((t) => _completionStatus[t.id] ?? false).length}/${groupTasks.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                    ),
                    itemCount: groupTasks.length,
                    itemBuilder: (context, taskIndex) {
                      final task = groupTasks[taskIndex];
                      final isCompleted = _completionStatus[task.id] ?? false;
                      return GestureDetector(
                        onTap: () async {
                          await _toggleTaskCompletion(task);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCompleted ? Colors.green.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: isCompleted ? Colors.green.shade200 : _getUrgencyColor(task.urgency),
                              width: isCompleted ? 1 : 2,
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (isCompleted)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade600,
                                    size: 16,
                                  ),
                                ),
                              if (task.urgency != null && task.urgency! > 0 && !isCompleted)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(
                                    Icons.priority_high,
                                    color: _getUrgencyColor(task.urgency),
                                    size: 14,
                                  ),
                                ),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    task.name,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCompleted ? Colors.grey.shade600 : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getRecurrenceIcon(String type) {
    // Use the same icon for all categories (same as Daily)
    return Icons.today;
  }
}
