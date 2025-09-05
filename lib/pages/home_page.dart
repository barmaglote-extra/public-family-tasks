import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/mixins/navigation_mixin.dart';
import 'package:tasks/models/todo.dart';
import 'package:tasks/models/todo_collection.dart';
import 'package:tasks/pages/new_collection_page.dart';
import 'package:tasks/pages/new_task_page.dart';
import 'package:tasks/pages/task_page.dart';
import 'package:tasks/services/collections_service.dart';
import 'package:tasks/services/due_date_tasks_service.dart';
import 'package:tasks/services/localization_service.dart';
import 'package:tasks/services/recurring_tasks_service.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/widgets/task_stats_completions_chart.dart';
import 'package:tasks/widgets/task_stats_due_date_chart.dart';
import 'package:tasks/widgets/localized_text.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with NavigationMixin, TickerProviderStateMixin {
  final _dueDateTasksService = locator<DueDateTasksService>();
  final _recurringTasksService = locator<RecurringTasksService>();
  final _tasksService = locator<TasksService>();
  final _collectionsService = locator<CollectionsService>();
  late Future<Map<String, int>> _dueDateTasksStatsFuture;
  late Future<Map<String, int>> _recurringTasksStatsFuture;
  late Future<int> _todayTasksCountFuture;
  late Future<Map<String, int>> _regularTaskStatsFuture;
  late Future<Map<String, int>> _recurrentTaskStatsFuture;
  late AnimationController _animationController;
  final GlobalKey<TaskStatsDueDateChartState> _dueDateKey = GlobalKey<TaskStatsDueDateChartState>();
  final GlobalKey<TaskCompletionsStatsChartState> _taskCompitaionsKey = GlobalKey<TaskCompletionsStatsChartState>();
  late int _totalCompleted;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Todo> _searchResults = [];
  Map<int, ToDoCollection> _collectionsMap = {};
  OverlayEntry? _searchOverlay;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _dueDateTasksStatsFuture = _dueDateTasksService.getDueDateTasksStats();
    _recurringTasksStatsFuture = _recurringTasksService.getTodayRecurringTasksStats();
    _todayTasksCountFuture = _tasksService.getTodayTasksCount();
    _regularTaskStatsFuture = _tasksService.getRegularTaskStats();
    _recurrentTaskStatsFuture = _tasksService.getRecurrentTaskStats();
    refreshData();
    _loadCollections();
    _searchController.addListener(_onSearchChanged);
  }

  void refreshData() async {
    final value = await _tasksService.getTotalCompletedTasks();
    setState(() {
      _totalCompleted = value;
    });
  }

  Future<void> _loadCollections() async {
    final collections = await _collectionsService.getItems();
    final collectionsMap = <int, ToDoCollection>{};
    for (final collection in collections) {
      collectionsMap[collection.id] = collection;
    }
    setState(() {
      _collectionsMap = collectionsMap;
    });
  }

  Future<void> _searchTasks(String query) async {
    final results = await _tasksService.searchTasks(query);
    setState(() {
      _searchResults = results;
    });
    _updateSearchOverlay();
  }

  void _onSearchChanged() {
    _searchTasks(_searchController.text.trim());
  }

  void _updateSearchOverlay() {
    _searchOverlay?.remove();
    if (_searchResults.isEmpty || !_isSearching) {
      _searchOverlay = null;
      return;
    }

    _searchOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: kToolbarHeight + MediaQuery.of(context).padding.top + 4.0,
        left: 8.0,
        right: 8.0,
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final task = _searchResults[index];
                final collection = _collectionsMap[task.collectionId];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: InkWell(
                    onTap: () {
                      _searchController.clear();
                      _isSearching = false;
                      _searchOverlay?.remove();
                      _searchOverlay = null;
                      _navigateToTaskPage(task.id);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          task.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.description != null && task.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            task.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                        if (collection != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.folder_outlined,
                                size: 12,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  collection.name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (index < _searchResults.length - 1) ...[
                          const SizedBox(height: 4),
                          const Divider(
                            height: 4,
                            thickness: 0.5,
                            color: Colors.grey,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_searchOverlay!);
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchResults = [];
        _searchOverlay?.remove();
        _searchOverlay = null;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchOverlay?.remove();
    super.dispose();
  }

  void _navigateToNewCollectionPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewCollectionPage(title: "New Collection")),
    );

    if (result == true) {
      setState(() {
        _refreshCharts();
      });
    }
  }

  void _navigateToNewTaskPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewTaskPage(title: "New Task")),
    );

    if (result == true) {
      setState(() {
        _refreshCharts();
      });
    }
  }

  void _navigateToTaskPage(int taskId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskPage(title: "Task", taskId: taskId)),
    );

    if (result == true) {
      setState(() {
        _refreshCharts();
      });
    }
  }

  void _navigateToRecurrentTasksPage(String recurrenceInterval) async {
    if (!mounted) return;
    final result = await Navigator.pushNamed(
      context,
      'tasks/recurrent',
      arguments: {'recurrenceInterval': recurrenceInterval},
    );

    if (result == true && mounted) {
      setState(() {
        _refreshCharts();
      });
    }
  }

  void _refreshCharts() {
    _dueDateTasksStatsFuture = _dueDateTasksService.getDueDateTasksStats();
    _recurringTasksStatsFuture = _recurringTasksService.getTodayRecurringTasksStats();
    _todayTasksCountFuture = _tasksService.getTodayTasksCount();
    _regularTaskStatsFuture = _tasksService.getRegularTaskStats();
    _recurrentTaskStatsFuture = _tasksService.getRecurrentTaskStats();
    _dueDateKey.currentState?.refreshData();
    _taskCompitaionsKey.currentState?.refreshData();
    refreshData();
  }

  Widget _buildTaskStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<Map<String, int>>(
          future: _regularTaskStatsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text('Error loading stats', style: TextStyle(color: Colors.red)));
            } else {
              final stats = snapshot.data ?? {'completed': 0, 'incomplete': 0};
              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Completed',
                      count: _totalCompleted,
                      color: Colors.green,
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Incomplete',
                      count: stats['incomplete']!,
                      color: Colors.red,
                      icon: Icons.warning,
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildRecurrentStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<Map<String, int>>(
          future: _recurrentTaskStatsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text('Error loading recurrent stats', style: TextStyle(color: Colors.red)));
            } else {
              final stats = snapshot.data ?? {'daily': 0, 'weekly': 0, 'monthly': 0, 'yearly': 0};
              return Column(
                children: [
                  // Первая строка: Daily и Weekly
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _navigateToRecurrentTasksPage('daily'),
                          child: _buildStatCard(
                            title: context.tr('recurrence.daily'),
                            count: stats['daily']!,
                            color: Colors.blueGrey,
                            icon: Icons.repeat,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _navigateToRecurrentTasksPage('weekly'),
                          child: _buildStatCard(
                            title: context.tr('recurrence.weekly'),
                            count: stats['weekly']!,
                            color: Colors.amber,
                            icon: Icons.repeat,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Вторая строка: Monthly и Yearly
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _navigateToRecurrentTasksPage('monthly'),
                          child: _buildStatCard(
                            title: context.tr('recurrence.monthly'),
                            count: stats['monthly']!,
                            color: Colors.indigo,
                            icon: Icons.repeat,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _navigateToRecurrentTasksPage('yearly'),
                          child: _buildStatCard(
                            title: context.tr('recurrence.yearly'),
                            count: stats['yearly']!,
                            color: Colors.cyan,
                            icon: Icons.repeat,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({required String title, required int count, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
          const SizedBox(height: 4),
          Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {},
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: _isSearching
              ? Consumer<LocalizationService>(
                  builder: (context, localizationService, child) {
                    return TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: localizationService.translate('common.search'),
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 18,
                        ),
                        border: InputBorder.none,
                      ),
                    );
                  },
                )
              : Consumer<LocalizationService>(
                  builder: (context, localizationService, child) {
                    return Text(
                      localizationService.translate('navigation.home'),
                      style: const TextStyle(color: Colors.white),
                    );
                  },
                ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
            ),
          ],
        ),
        drawer: AppDrawer(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task Statistics Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bar_chart, size: 24, color: Colors.blue),
                          const SizedBox(width: 8),
                          Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Text(
                                localizationService.translate('stats.task_statistics_header'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTaskStatsCards(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Due Date Chart Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 24, color: Colors.orange),
                          const SizedBox(width: 8),
                          Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Text(
                                localizationService.translate('stats.due_date_overview'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 150,
                        child: TaskStatsDueDateChart(key: _dueDateKey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Completions Chart Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_up, size: 24, color: Colors.green),
                          const SizedBox(width: 8),
                          Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Text(
                                localizationService.translate('stats.completion_trends'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 150,
                        child: TaskCompletionsStatsChart(key: _taskCompitaionsKey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Recurrent Tasks Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.repeat, size: 24, color: Colors.purple),
                          const SizedBox(width: 8),
                          Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Text(
                                localizationService.translate('stats.recurring_tasks_header'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRecurrentStatsCards(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80), // Extra space for floating action button
            ],
          ),
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
}
