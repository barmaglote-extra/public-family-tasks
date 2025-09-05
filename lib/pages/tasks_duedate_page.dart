import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/mixins/navigation_mixin.dart';
import 'package:tasks/mixins/back_button_mixin.dart';
import 'package:tasks/models/todo.dart';
import 'package:tasks/models/todo_regular.dart';
import 'package:tasks/models/todo_collection.dart';
import 'package:tasks/models/subtodo.dart';
import 'package:tasks/pages/collection_page.dart';
import 'package:tasks/pages/new_collection_page.dart';
import 'package:tasks/pages/new_task_page.dart';
import 'package:tasks/pages/task_page.dart';
import 'package:tasks/services/collections_service.dart';
import 'package:tasks/services/due_date_tasks_service.dart';
import 'package:tasks/services/recurring_tasks_service.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/services/sub_tasks_service.dart';
import 'package:tasks/services/update_provider.dart';
import 'package:tasks/widgets/localized_text.dart';
import 'package:intl/intl.dart';

class TasksDueDatePage extends StatefulWidget {
  final _dueDateTasksService = locator<DueDateTasksService>();
  final _collectionsService = locator<CollectionsService>();
  final _tasksService = locator<TasksService>();

  TasksDueDatePage({super.key});

  @override
  State<TasksDueDatePage> createState() => _TasksDueDatePageState();
}

class _TasksDueDatePageState extends State<TasksDueDatePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, NavigationMixin, BackButtonMixin {
  List? tasks;
  List incompleteTasks = [];
  List completedTasks = [];
  bool isLoading = false;
  List<ToDoCollection>? collections;
  final _updateProvider = locator<UpdateProvider>();
  late Future<Map<String, int>> _dueDateTasksStatsFuture;
  late Future<Map<String, int>> _recurringTasksStatsFuture;
  late Future<int> _todayTasksCountFuture;
  final _dueDateTasksService = locator<DueDateTasksService>();
  final _recurringTasksService = locator<RecurringTasksService>();
  final _subTasksService = locator<SubTasksService>();
  bool _showTaskGridMode = false;
  static const String _gridModeKey = 'due_date_tasks_grid_mode';
  late AnimationController _animationController;

  // Track subtask expansion state and subtasks for each task
  final Map<int, bool> _expandedTasks = {};
  Map<int, List<SubTodo>> _taskSubTasks = {};

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
    _todayTasksCountFuture = widget._tasksService.getTodayTasksCount();
    WidgetsBinding.instance.addObserver(this);
    _updateProvider.addListener(_loadTasks);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateProvider.removeListener(_loadTasks);
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      isLoading = true;
    });

    final loadedTasks = await widget._dueDateTasksService.getDueDateTasks();
    final splitTasks = widget._dueDateTasksService.splitTasksByCompletion(loadedTasks);
    _dueDateTasksStatsFuture = _dueDateTasksService.getDueDateTasksStats();
    _recurringTasksStatsFuture = _recurringTasksService.getTodayRecurringTasksStats();

    // Load subtasks for all tasks
    await _loadSubTasksForAllTasks(loadedTasks);

    setState(() {
      tasks = loadedTasks;
      incompleteTasks = splitTasks['incomplete']!;
      completedTasks = splitTasks['completed']!;
      isLoading = false;
    });
  }

  Future<void> _loadCollection() async {
    final data = await widget._collectionsService.getItems();
    setState(() {
      collections = data;
    });
  }

  Future<void> _deleteTask(Todo task) async {
    await widget._tasksService.deleteItemById(task.id);
    _loadTasks();
  }

  void _navigateToTaskPage(int taskId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskPage(title: "Task", taskId: taskId)),
    );

    if (result == true) {
      _loadCollection();
      _loadTasks();
    }
  }

  void _navigateToCollectionPage(int collectionId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CollectionPage(collectionId: collectionId)),
    );

    if (result == true) {
      _loadCollection();
      _loadTasks();
    }
  }

  Future<void> _updateTaskState(bool? value, int? id) async {
    if (id == null) return;
    await (value == true
        ? widget._tasksService.markTaskAsCompleted(id)
        : widget._tasksService.markTaskAsNotCompleted(id));
    _loadTasks();
  }

  Future<void> _loadSubTasksForAllTasks(List<Todo>? tasks) async {
    if (tasks == null) return;

    final Map<int, List<SubTodo>> newTaskSubTasks = {};

    for (final task in tasks) {
      if (task is TodoRegular) {
        final subTasks = await _subTasksService.getItemsByField<SubTodo>({'task_id': task.id});
        newTaskSubTasks[task.id] = subTasks ?? [];
      }
    }

    setState(() {
      _taskSubTasks = newTaskSubTasks;
    });
  }

  Future<void> _updateSubTaskState(int subTaskId, bool isCompleted) async {
    await _subTasksService.updateItemById(subTaskId, {
      'is_completed': isCompleted ? 1 : 0,
    });
    _updateProvider.notifyListeners();
    await _loadTasks();
  }

  void _toggleTaskExpansion(int taskId) {
    setState(() {
      _expandedTasks[taskId] = !(_expandedTasks[taskId] ?? false);
    });
  }

  void _handleTaskRestoration(dynamic deletedTask) {
    widget._tasksService.addItem(deletedTask.toTodoData());
    _loadTasks();
  }

  _onBack() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushNamed(context, "/");
    }
  }

  void _navigateToNewTaskPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewTaskPage(title: "New Task", collectionId: -1)),
    );

    if (result == true) {
      _loadCollection();
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
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(context.tr('pages.due_date_tasks'), style: const TextStyle(color: Colors.white)),
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
      ),
    );
  }

  Widget _buildBody() {
    if (tasks == null) {
      return isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Card(
                margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('tasks.no_tasks'),
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

    if (tasks!.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('tasks.no_tasks'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('tasks.no_one_time_tasks'),
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
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (incompleteTasks.isNotEmpty)
            _buildTaskSection(
              title: context.tr('tasks.pending_tasks'),
              tasks: incompleteTasks,
              icon: Icons.pending_actions,
              color: Colors.orange,
              isCompleted: false,
            ),
          if (incompleteTasks.isNotEmpty && completedTasks.isNotEmpty) const SizedBox(height: 16),
          if (completedTasks.isNotEmpty)
            _buildTaskSection(
              title: context.tr('tasks.completed_tasks'),
              tasks: completedTasks,
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
            _showTaskGridMode ? _buildGridView(tasks, isCompleted) : _buildListView(tasks, isCompleted),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List tasks, bool isCompleted) {
    return Column(
      children: tasks.map<Widget>((task) {
        final TodoRegular todo = task as TodoRegular;
        final collection = _getCollection(todo.collectionId);
        final isExpanded = _expandedTasks[todo.id] ?? false;
        final subTasks = _taskSubTasks[todo.id] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            children: [
              // Main task
              Dismissible(
                key: Key(todo.id.toString()),
                direction: DismissDirection.horizontal,
                dismissThresholds: const {
                  DismissDirection.startToEnd: 0.7, // Right swipe (collection)
                  DismissDirection.endToStart: 0.8, // Left swipe (delete)
                },
                movementDuration: const Duration(milliseconds: 300),
                background: Container(
                  color: Colors.blue,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Row(
                    children: [
                      Icon(Icons.folder, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Collection',
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
                  if (direction == DismissDirection.startToEnd) {
                    // Swipe right: Navigate to collection
                    if (collection != null) {
                      _navigateToCollectionPage(collection.id);
                    }
                    return false; // Don't dismiss
                  } else {
                    // Swipe left: Delete task
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
                  }
                },
                onDismissed: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    // Delete task
                    await _deleteTask(todo);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${todo.name} deleted'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () => _handleTaskRestoration(todo),
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
                      leading: GestureDetector(
                        onTap: () => _updateTaskState(!todo.isCompleted, todo.id),
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
                          if (collection != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.folder, // Always folder icon, not checkmark
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
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (todo.urgency != null && todo.urgency! > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                Icons.priority_high,
                                color: _getUrgencyColor(todo.urgency),
                                size: 20,
                              ),
                            ),
                          // Removed subtask expansion button from trailing area
                        ],
                      ),
                      onTap: () => _navigateToTaskPage(todo.id),
                    ),
                  ),
                ),
              ),
              // Subtask expansion strip
              if (subTasks.isNotEmpty)
                Container(
                  width: double.infinity,
                  child: Material(
                    color: Colors.grey.shade100,
                    child: InkWell(
                      onTap: () => _toggleTaskExpansion(todo.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Subtasks list (expandable)
              if (isExpanded && subTasks.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subtasks (${subTasks.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
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
                            label: const Text('Collapse'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGridView(List tasks, bool isCompleted) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final TodoRegular todo = tasks[index] as TodoRegular;
        final collection = _getCollection(todo.collectionId);

        return Dismissible(
          key: Key(todo.id.toString()),
          direction: DismissDirection.horizontal,
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.8, // Right swipe (collection)
            DismissDirection.endToStart: 0.8, // Left swipe (delete)
          },
          movementDuration: const Duration(milliseconds: 300),
          background: Container(
            color: Colors.blue,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder, color: Colors.white, size: 24),
                SizedBox(height: 4),
                Text(
                  'Collection',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 24),
                SizedBox(height: 4),
                Text(
                  'Delete',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                ),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Swipe right: Navigate to collection
              if (collection != null) {
                _navigateToCollectionPage(collection.id);
              }
              return false; // Don't dismiss
            } else {
              // Swipe left: Delete task
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
            }
          },
          onDismissed: (direction) async {
            if (direction == DismissDirection.endToStart) {
              // Delete task
              await _deleteTask(todo);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${todo.name} deleted'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => _handleTaskRestoration(todo),
                  ),
                ),
              );
            }
          },
          child: GestureDetector(
            onTap: () => _navigateToTaskPage(todo.id),
            child: Container(
              decoration: BoxDecoration(
                color: todo.isCompleted ? Colors.green.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color:
                      todo.isCompleted ? Colors.green.shade200 : _getDueDateBorderColor(todo.dueDate, todo.isCompleted),
                  width: todo.isCompleted ? 1 : 2,
                ),
              ),
              child: Stack(
                children: [
                  if (todo.isCompleted)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                    ),
                  if (todo.urgency != null && todo.urgency! > 0 && !todo.isCompleted)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.priority_high,
                        color: _getUrgencyColor(todo.urgency),
                        size: 18,
                      ),
                    ),
                  // Bottom-left toggle button (only show for incomplete tasks)
                  if (!todo.isCompleted)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: GestureDetector(
                        onTap: () => _updateTaskState(!todo.isCompleted, todo.id),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: null,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todo.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: todo.isCompleted ? Colors.grey.shade600 : null,
                          ),
                        ),
                        const Spacer(),
                        if (todo.dueDate != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: _getDueDateColor(todo.dueDate!),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatDueDate(todo.dueDate!),
                                  style: TextStyle(
                                    color: _getDueDateColor(todo.dueDate!),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (collection != null)
                          Row(
                            children: [
                              Icon(
                                Icons.folder,
                                size: 12,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  collection.name,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  ToDoCollection? _getCollection(int collectionId) {
    return collections?.firstWhere(
      (c) => c.id == collectionId,
      orElse: () => ToDoCollection(id: 0, name: 'Unknown', description: ''),
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
      return Colors.yellow; // Due today (changed from orange to yellow as per original)
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
      return Colors.orange; // Due today (using orange for better visibility in UI)
    } else {
      return Colors.blue; // Future due date
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final BuildContext context = navigatorKey.currentContext!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) {
      final difference = today.difference(due).inDays;
      return context
          .tr('tasks.overdue_by', params: {'days': difference.toString(), 'plural': difference != 1 ? 's' : ''});
    } else if (due.isAtSameMomentAs(today)) {
      return context.tr('tasks.due_today');
    } else if (due.isAtSameMomentAs(tomorrow)) {
      return context.tr('tasks.due_tomorrow');
    } else {
      return '${context.tr('tasks.due')} ${DateFormat('MMM dd').format(dueDate)}';
    }
  }
}
