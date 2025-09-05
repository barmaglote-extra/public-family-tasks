import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/mixins/navigation_mixin.dart';
import 'package:tasks/mixins/back_button_mixin.dart';
import 'package:tasks/models/todo_collection.dart';
import 'package:tasks/models/todo_regular.dart';
import 'package:tasks/pages/new_collection_page.dart';
import 'package:tasks/services/collections_service.dart';
import 'package:tasks/services/due_date_tasks_service.dart';
import 'package:tasks/services/recurring_tasks_service.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/models/todo_fields.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> with NavigationMixin, BackButtonMixin {
  final _collectionsService = locator<CollectionsService>();
  final _tasksService = locator<TasksService>();
  bool isLoading = false;
  late Future<Map<String, int>> _dueDateTasksStatsFuture;
  late Future<Map<String, int>> _recurringTasksStatsFuture;
  late Future<int> _todayTasksCountFuture;
  final _dueDateTasksService = locator<DueDateTasksService>();
  final _recurringTasksService = locator<RecurringTasksService>();

  List<ToDoCollection> collections = [];
  Map<int, Map<String, int>> taskStats = {};
  Map<int, List<TodoRegular>> regularTasksByCollection = {};

  bool _showTaskGridMode = false;
  static const String _gridModeKey = 'collections_grid_mode';

  @override
  void initState() {
    super.initState();
    _loadGridModePreference();
    _loadData();
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

  void _navigateToNewCollectionPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewCollectionPage(title: "New Collection")),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final collectionsData = await _collectionsService.getItems();
    final stats = <int, Map<String, int>>{};
    final regularTasksMap = <int, List<TodoRegular>>{};

    for (var collection in collectionsData) {
      stats[collection.id] = await _tasksService.getTaskStats(collection.id);
      final regularTasks = await _tasksService.getItemsByField<TodoRegular>({
        TodoFields.collectionId: collection.id,
        TodoFields.taskType: 'regular',
      });
      regularTasksMap[collection.id] = regularTasks ?? [];
    }

    setState(() {
      collections = collectionsData;
      taskStats = stats;
      regularTasksByCollection = regularTasksMap;
      isLoading = false;
    });
  }

  Future<void> _toggleTaskCompletion(TodoRegular task) async {
    // Update the task in the database
    final newCompletionStatus = task.isCompleted ? 0 : 1;
    await _tasksService.updateItemById(task.id, {
      TodoFields.isCompleted: newCompletionStatus,
    });

    // Update local state efficiently without reloading everything
    setState(() {
      // Update the task in the local collection
      final collectionTasks = regularTasksByCollection[task.collectionId];
      if (collectionTasks != null) {
        final taskIndex = collectionTasks.indexWhere((t) => t.id == task.id);
        if (taskIndex != -1) {
          // Create updated task with new completion status
          final updatedTask = TodoRegular(
            id: task.id,
            name: task.name,
            description: task.description,
            isCompleted: newCompletionStatus == 1,
            dueDate: task.dueDate,
            urgency: task.urgency,
            taskType: task.taskType,
            collectionId: task.collectionId,
          );

          // Replace the task in the list
          collectionTasks[taskIndex] = updatedTask;

          // Update the task stats for this collection
          final currentStats = taskStats[task.collectionId] ?? {'total': 0, 'completed': 0};
          final totalTasks = currentStats['total'] ?? 0;
          int completedTasks = currentStats['completed'] ?? 0;

          // Adjust completed count based on the change
          if (newCompletionStatus == 1) {
            completedTasks++; // Task was marked as completed
          } else {
            completedTasks--; // Task was marked as incomplete
          }

          // Update stats
          taskStats[task.collectionId] = {
            'total': totalTasks,
            'completed': completedTasks,
          };
        }
      }
    });
  }

  Future<void> _deleteCollection(int collectionId) async {
    await _collectionsService.deleteCollection(collectionId);
    _loadData();
  }

  _onBack() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushNamed(context, "/");
    }
  }

  Widget _buildTaskGridView() {
    return Column(
      children: collections.where((collection) {
        final tasks = regularTasksByCollection[collection.id] ?? [];
        return tasks.isNotEmpty;
      }).map((collection) {
        final tasks = regularTasksByCollection[collection.id] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  'tasks',
                  arguments: {'collectionId': collection.id},
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Icon(
                        Icons.folder,
                        size: 16,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        collection.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${tasks.where((t) => t.isCompleted).length}/${tasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
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
                itemCount: tasks.length,
                itemBuilder: (context, taskIndex) {
                  final task = tasks[taskIndex];
                  return GestureDetector(
                    onTap: () async {
                      await _toggleTaskCompletion(task);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: task.isCompleted ? Colors.green.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: task.isCompleted ? Colors.green.shade200 : Colors.grey.shade300,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (task.isCompleted)
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
                                // Removed text strikethrough - green background and checkmark are sufficient
                                color: task.isCompleted ? Colors.grey.shade600 : null,
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
        );
      }).toList(),
    );
  }

  Widget _buildCollectionsList() {
    return Column(
      children: collections.map((collection) {
        final stats = taskStats[collection.id] ?? {'total': 0, 'completed': 0};
        final completedTasks = stats['completed'] ?? 0;
        final totalTasks = stats['total'] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: Dismissible(
            key: Key(collection.id.toString()),
            direction: DismissDirection.horizontal,
            dismissThresholds: const {
              DismissDirection.startToEnd: 0.7,
              DismissDirection.endToStart: 0.8,
            },
            movementDuration: const Duration(milliseconds: 300),
            background: Container(
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(8.0),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Row(
                children: [
                  Icon(Icons.delete, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            secondaryBackground: Container(
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(8.0),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
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
                    title: const Text('Delete collection?'),
                    content: Text(
                      'This will permanently delete "${collection.name}" and all $totalTasks task${totalTasks != 1 ? 's' : ''} in this collection.',
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Delete'),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  );
                },
              );
            },
            onDismissed: (direction) async {
              await _deleteCollection(collection.id);
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
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                leading: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Icon(
                    Icons.folder,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                ),
                title: Text(
                  collection.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                subtitle: collection.description?.isNotEmpty == true
                    ? Text(
                        collection.description!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: totalTasks == 0
                            ? Colors.grey.shade100
                            : completedTasks == totalTasks
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        '$completedTasks / $totalTasks',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: totalTasks == 0
                              ? Colors.grey.shade600
                              : completedTasks == totalTasks
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'tasks',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                onTap: () => Navigator.pushNamed(
                  context,
                  'tasks',
                  arguments: {'collectionId': collection.id},
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
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
          title: const Text('Collections', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(
                _showTaskGridMode ? Icons.view_list : Icons.grid_view,
                color: Colors.white,
              ),
              onPressed: _toggleGridMode,
              tooltip: _showTaskGridMode ? 'Switch to List View' : 'Switch to Grid View',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_circle_left_outlined),
              onPressed: _onBack,
            ),
          ],
        ),
        drawer: AppDrawer(),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : collections.isEmpty
                ? Center(
                    child: Card(
                      margin: const EdgeInsets.all(16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_open_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No collections yet',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first collection to organize your tasks',
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
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Collections Content
                        _showTaskGridMode ? _buildTaskGridView() : _buildCollectionsList(),
                      ],
                    ),
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
        floatingActionButton: FloatingActionButton(
          onPressed: _navigateToNewCollectionPage,
          tooltip: 'Add New Collection',
          backgroundColor: Colors.red,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
