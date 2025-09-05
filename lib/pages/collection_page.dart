import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/mixins/navigation_mixin.dart';
import 'package:tasks/models/todo.dart';
import 'package:tasks/models/todo_collection.dart';
import 'package:tasks/models/todo_fields.dart';
import 'package:tasks/models/todo_recurrent.dart';
import 'package:tasks/models/todo_regular.dart';
import 'package:tasks/pages/edit_collection_page.dart';
import 'package:tasks/pages/new_collection_page.dart';
import 'package:tasks/pages/new_task_page.dart';
import 'package:tasks/pages/task_items/regular_tasks_tab.dart';
import 'package:tasks/pages/task_items/recurrent_tasks_tab.dart';
import 'package:tasks/pages/task_page.dart';
import 'package:tasks/services/collections_service.dart';
import 'package:tasks/services/due_date_tasks_service.dart';
import 'package:tasks/services/localization_service.dart';
import 'package:tasks/services/recurring_tasks_service.dart';
import 'package:tasks/services/task_completions_service.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/services/update_provider.dart';
import 'package:tasks/widgets/localized_text.dart';

class CollectionPage extends StatefulWidget {
  final int collectionId;
  final _collectionsService = locator<CollectionsService>();
  final _tasksService = locator<TasksService>();
  final _dueDateTasksService = locator<DueDateTasksService>();
  final _recurringTasksService = locator<RecurringTasksService>();
  final _taskCompletionsService = locator<TaskCompletionsService>();
  final _updateProvider = locator<UpdateProvider>();

  CollectionPage({super.key, required this.collectionId});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> with TickerProviderStateMixin, NavigationMixin {
  List? tasks;
  List incompleteTasks = [];
  List completedTasks = [];
  List recurrentTasks = [];
  bool isLoading = false;
  ToDoCollection? collection;
  late TabController _tabController;
  late AnimationController _animationController;

  // Grid mode settings for each tab
  bool _regularTasksGridMode = false;
  bool _recurrentTasksGridMode = false;
  static const String _regularGridModeKey = 'collection_regular_grid_mode';
  static const String _recurrentGridModeKey = 'collection_recurrent_grid_mode';

  late Future<int> _todayTasksCountFuture;
  late Future<Map<String, int>> _dueDateTasksStatsFuture;
  late Future<Map<String, int>> _recurringTasksStatsFuture;

  // Recurrent tasks completion status
  Map<int, bool> _recurrentTasksCompletionStatus = {};

  // Local completion status override for immediate UI feedback
  final Map<int, bool> _localTaskCompletionOverride = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update grid mode icon for current tab
    });
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadGridModePreferences();
    _loadCollection();
    _loadTasks();
    _todayTasksCountFuture = widget._tasksService.getTodayTasksCount();
    _dueDateTasksStatsFuture = widget._dueDateTasksService.getDueDateTasksStats();
    _recurringTasksStatsFuture = widget._recurringTasksService.getTodayRecurringTasksStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadGridModePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _regularTasksGridMode = prefs.getBool(_regularGridModeKey) ?? false;
      _recurrentTasksGridMode = prefs.getBool(_recurrentGridModeKey) ?? false;
    });
  }

  Future<void> _saveGridModePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _toggleRegularTasksGridMode() async {
    final newValue = !_regularTasksGridMode;
    setState(() {
      _regularTasksGridMode = newValue;
    });
    await _saveGridModePreference(_regularGridModeKey, newValue);
  }

  Future<void> _toggleRecurrentTasksGridMode() async {
    final newValue = !_recurrentTasksGridMode;
    setState(() {
      _recurrentTasksGridMode = newValue;
    });
    await _saveGridModePreference(_recurrentGridModeKey, newValue);
  }

  Future<void> _toggleCurrentTabGridMode() async {
    if (_tabController.index == 0) {
      await _toggleRegularTasksGridMode();
    } else {
      await _toggleRecurrentTasksGridMode();
    }
  }

  bool _getCurrentTabGridMode() {
    return _tabController.index == 0 ? _regularTasksGridMode : _recurrentTasksGridMode;
  }

  /// Get effective completion status considering local overrides for immediate UI feedback
  bool _getEffectiveCompletionStatus(Todo task) {
    return _localTaskCompletionOverride.containsKey(task.id)
        ? _localTaskCompletionOverride[task.id]!
        : task.isCompleted;
  }

  Future<void> _loadTasks() async {
    setState(() {
      isLoading = true;
      _localTaskCompletionOverride.clear(); // Clear any local overrides
    });

    final regular = await widget._tasksService
        .getItemsByField({TodoFields.collectionId: widget.collectionId, TodoFields.taskType: 'regular'});

    final recurrent = await widget._tasksService
        .getItemsByField({TodoFields.collectionId: widget.collectionId, TodoFields.taskType: 'recurrent'});

    // Load completion status for recurrent tasks
    if (recurrent != null && recurrent.isNotEmpty) {
      _recurrentTasksCompletionStatus =
          await widget._recurringTasksService.getTodayCompletionStatuses(recurrent.cast<TodoRecurrent>());
    }

    setState(() {
      tasks = regular;
      recurrentTasks = recurrent ?? [];
      isLoading = false;
      _updateTasks();
    });
  }

  Future<void> _loadCollection() async {
    final data = await widget._collectionsService.getItemById(widget.collectionId);
    setState(() {
      collection = data;
    });
  }

  void _updateTasks() {
    if (tasks != null) {
      incompleteTasks = tasks!.where((task) => !task.isCompleted).toList();
      completedTasks = tasks!.where((task) => task.isCompleted).toList();
    } else {
      incompleteTasks = [];
      completedTasks = [];
    }
  }

  Future<void> _deleteTask(Todo task) async {
    await widget._tasksService.deleteItemById(task.id);
    widget._updateProvider.notifyListeners();
    _loadTasks();
  }

  void _navigateToTaskPage(int taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskPage(title: "Task", taskId: taskId)),
    ).then((_) {
      _loadCollection();
      _loadTasks();
      widget._updateProvider.notifyListeners();
    });
  }

  void _navigateToCollectionPage(int collectionId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionPage(collectionId: collectionId),
      ),
    ).then((_) {
      _loadCollection();
      _loadTasks();
      widget._updateProvider.notifyListeners();
    });
  }

  void _navigateToNewTaskPage() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewTaskPage(title: "New Task", collectionId: widget.collectionId)),
    ).then((_) {
      _loadCollection();
      _loadTasks();
      widget._updateProvider.notifyListeners();
    });
  }

  void _navigateToNewCollectionPage() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewCollectionPage(title: "Collections")),
    ).then((_) {
      _loadCollection();
      _loadTasks();
      widget._updateProvider.notifyListeners();
    });
  }

  Future<void> _updateTaskState(bool? value, int? id) async {
    if (id == null) return;

    // Immediate UI update for visual feedback
    setState(() {
      _localTaskCompletionOverride[id] = value ?? false;
    });

    try {
      // Perform database update
      await (value == true
          ? widget._tasksService.markTaskAsCompleted(id)
          : widget._tasksService.markTaskAsNotCompleted(id));

      // Remove override after successful database update and reload tasks
      setState(() {
        _localTaskCompletionOverride.remove(id);
      });

      // Reload tasks from database to get updated state
      await _loadTasks();

      // Notify listeners
      widget._updateProvider.notifyListeners();
    } catch (e) {
      // If database update fails, revert the local override
      setState(() {
        _localTaskCompletionOverride.remove(id);
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update task status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleTaskRestoration(dynamic deletedTask) {
    widget._tasksService.addItem(deletedTask.toTodoData());
    _loadTasks();
  }

  Future<void> _toggleRecurrentTaskCompletion(TodoRecurrent task) async {
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

    final currentStatus = _recurrentTasksCompletionStatus[task.id] ?? false;
    final newStatus = !currentStatus;

    setState(() {
      _recurrentTasksCompletionStatus[task.id] = newStatus;
    });

    if (newStatus) {
      await widget._taskCompletionsService.markTaskAsCompleted(task.id, completionDate);
    } else {
      await widget._taskCompletionsService.markTaskAsNotCompleted(task.id, completionDate);
    }

    // Refresh completion status
    if (recurrentTasks.isNotEmpty) {
      _recurrentTasksCompletionStatus =
          await widget._recurringTasksService.getTodayCompletionStatuses(recurrentTasks.cast<TodoRecurrent>());
    }
    setState(() {});
  }

  void _navigateToEditCollectionPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCollectionPage(
          collectionId: widget.collectionId,
          initialName: collection!.name,
          description: collection!.description,
        ),
      ),
    );

    if (result == true) {
      await _loadCollection();
    }
  }

  void showPopupMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.bottomRight(Offset.zero + const Offset(0, 0)), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero + const Offset(0, 0)), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(
          value: 'new_task',
          child: Row(
            children: [
              Icon(Icons.add_task),
              SizedBox(width: 16),
              Text('New Task'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'new_collection',
          child: Row(
            children: [
              Icon(Icons.list_alt_rounded),
              SizedBox(width: 16),
              Text('New Collection'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'new_task') {
        _navigateToNewTaskPage();
      } else if (value == 'new_collection') {
        _navigateToNewCollectionPage();
      }
    });
  }

  Widget _buildRegularTasksGridView() {
    // Maintain original database order instead of grouping by completion status
    final allTasks = tasks ?? [];

    if (allTasks.isEmpty) {
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
                Text(
                  context.tr('tasks.no_one_time_tasks'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('tasks.create_first_task'),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.0,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: allTasks.length,
        itemBuilder: (context, index) {
          final task = allTasks[index] as TodoRegular;
          final effectiveIsCompleted = _getEffectiveCompletionStatus(task);
          return GestureDetector(
            onTap: () async {
              await _updateTaskState(!effectiveIsCompleted, task.id);
            },
            onLongPress: () => _navigateToTaskPage(task.id),
            child: Container(
              decoration: BoxDecoration(
                color: effectiveIsCompleted ? Colors.green.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: effectiveIsCompleted ? Colors.green.shade200 : Colors.grey.shade300,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (effectiveIsCompleted)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 16,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      task.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: effectiveIsCompleted ? Colors.grey.shade600 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecurrentTasksGridView() {
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
                  context.tr('tasks.no_recurring_tasks'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('tasks.create_first_recurring_task'),
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

    final groupedTasks = <String, List<TodoRecurrent>>{
      context.tr('recurrence.daily'): [],
      context.tr('recurrence.weekly'): [],
      context.tr('recurrence.monthly'): [],
      context.tr('recurrence.yearly'): [],
    };

    for (var task in recurrentTasks.cast<TodoRecurrent>()) {
      final type = _formatRecurrence(task.recurrenceInterval);
      if (groupedTasks.containsKey(type)) {
        groupedTasks[type]!.add(task);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: groupedTasks.entries.where((entry) => entry.value.isNotEmpty).map((entry) {
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
                          Icons.today, // Use same icon for all categories
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
                          '${groupTasks.where((t) => _recurrentTasksCompletionStatus[t.id] ?? false).length}/${groupTasks.length}',
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
                        final isCompleted = _recurrentTasksCompletionStatus[task.id] ?? false;
                        return GestureDetector(
                          onTap: () async {
                            await _toggleRecurrentTaskCompletion(task);
                          },
                          onLongPress: () => _navigateToTaskPage(task.id),
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
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(collection?.name.toString() ?? 'Loading...', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.check_box),
              child: Consumer<LocalizationService>(
                builder: (context, localizationService, child) {
                  return Text(localizationService.translate('tasks.one_time_tasks'));
                },
              ),
            ),
            Tab(
              icon: const Icon(Icons.refresh),
              child: Consumer<LocalizationService>(
                builder: (context, localizationService, child) {
                  return Text(localizationService.translate('tasks.recurring_tasks'));
                },
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _getCurrentTabGridMode() ? Icons.view_list : Icons.grid_view,
              color: Colors.white,
            ),
            onPressed: _toggleCurrentTabGridMode,
            tooltip: _getCurrentTabGridMode()
                ? context.tr('common.switch_to_list_view')
                : context.tr('common.switch_to_grid_view'),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: collection != null ? _navigateToEditCollectionPage : null,
            tooltip: context.tr('collections.edit_collection'),
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: _buildBody(),
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
    );
  }

  Widget _buildBody() {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return TabBarView(
      controller: _tabController,
      children: [
        // Regular Tasks Tab
        _regularTasksGridMode
            ? _buildRegularTasksGridView()
            : RegularTasksTab(
                collections: [],
                incompleteTasks: incompleteTasks,
                completedTasks: completedTasks,
                onTaskTap: _navigateToTaskPage,
                onTaskStateChanged: _updateTaskState,
                onCollectionTap: _navigateToCollectionPage,
                onTaskDelete: _deleteTask,
                onTaskRestore: (item) => {},
                isEmpty: tasks == null || tasks!.isEmpty && recurrentTasks.isEmpty,
              ),
        // Recurrent Tasks Tab
        _recurrentTasksGridMode
            ? _buildRecurrentTasksGridView()
            : RecurrentTasksTab(
                collectionId: widget.collectionId,
                recurrentTasks: recurrentTasks,
                onTaskTap: _navigateToTaskPage,
                onTaskRestore: _handleTaskRestoration,
                isEmpty: recurrentTasks.isEmpty,
              ),
      ],
    );
  }
}
