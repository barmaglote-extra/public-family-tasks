import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/mixins/navigation_mixin.dart';
import 'package:tasks/mixins/back_button_mixin.dart';
import 'package:tasks/models/todo.dart';
import 'package:tasks/models/todo_regular.dart';
import 'package:tasks/pages/new_collection_page.dart';
import 'package:tasks/pages/new_task_page.dart';
import 'package:tasks/pages/task_page.dart';
import 'package:tasks/services/due_date_tasks_service.dart';
import 'package:tasks/services/recurring_tasks_service.dart';
import 'package:tasks/services/tasks_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with NavigationMixin, BackButtonMixin, TickerProviderStateMixin {
  final _tasksService = locator<TasksService>();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Future<List<Todo>> _tasksFuture;
  late Future<Map<DateTime, int>> _taskCountFuture;
  late Future<Map<String, int>> _dueDateTasksStatsFuture;
  late Future<Map<String, int>> _recurringTasksStatsFuture;
  final _dueDateTasksService = locator<DueDateTasksService>();
  final _recurringTasksService = locator<RecurringTasksService>();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _selectedDay = _focusedDay;
    _tasksFuture = _tasksService.getRegularTasksByDate(_focusedDay);
    _dueDateTasksStatsFuture = _dueDateTasksService.getDueDateTasksStats();
    _recurringTasksStatsFuture = _recurringTasksService.getTodayRecurringTasksStats();
    _updateTaskCountFuture(_focusedDay);
  }

  void _navigateToNewTaskPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewTaskPage(title: "New Task", collectionId: -1)),
    );

    if (result == true) {
      setState(() {
        _updateTasksFuture(_selectedDay!);
        _updateTaskCountFuture(_focusedDay);
      });
    }
  }

  void _navigateToNewCollectionPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewCollectionPage(title: "New Collection")),
    );

    if (result == true) {
      // Refresh if needed
    }
  }

  void _updateTaskCountFuture(DateTime focusedDay) {
    final firstDayOfMonth = DateTime(focusedDay.year, focusedDay.month, 1);
    final lastDayOfMonth = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    _taskCountFuture = _tasksService.getRegularTasksCountByDateRange(firstDayOfMonth, lastDayOfMonth);
  }

  void _updateTasksFuture(DateTime selectedDay) {
    _tasksFuture = _tasksService.getRegularTasksByDate(selectedDay);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _updateTasksFuture(selectedDay);
      _updateTaskCountFuture(focusedDay);
    });
  }

  void _onPageChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      if (_selectedDay == null || _selectedDay!.month != focusedDay.month || _selectedDay!.year != focusedDay.year) {
        _selectedDay = DateTime(focusedDay.year, focusedDay.month, 1);
      }
      _updateTasksFuture(_selectedDay!);
      _updateTaskCountFuture(focusedDay);
    });
  }

  void _navigateToTaskPage(int taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskPage(title: "Task", taskId: taskId)),
    ).then((_) {
      setState(() {
        _updateTasksFuture(_selectedDay!);
        _updateTaskCountFuture(_focusedDay);
      });
    });
  }

  void _onTaskStateChanged(bool? value, int? taskId) {
    if (taskId != null && value != null) {
      _tasksService.updateItemById(taskId, {'is_completed': value ? 1 : 0}).then((_) {
        setState(() {
          _updateTasksFuture(_selectedDay!);
          _updateTaskCountFuture(_focusedDay);
        });
      });
    }
  }

  Widget _buildDayContent(DateTime day, int taskCount, {bool isToday = false, bool isSelected = false}) {
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? const Color.fromARGB(255, 255, 158, 158) // Выбранный день
            : isToday
                ? Colors.redAccent // Текущий день
                : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 16,
                color: isToday || isSelected
                    ? Colors.white // Белый для текущего и выбранного дня
                    : isWeekend
                        ? Colors.red // Красный для выходных
                        : Colors.black, // Чёрный для будних
              ),
            ),
          ),
          if (taskCount > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.pink,
                  shape: BoxShape.rectangle,
                ),
                child: Center(
                  child: Text(
                    '$taskCount',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
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
                  onTap: () => _onTaskStateChanged(!todo.isCompleted, todo.id),
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
                subtitle: todo.description != null && todo.description!.isNotEmpty
                    ? Text(
                        todo.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      )
                    : null,
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
                  ],
                ),
                onTap: () => _navigateToTaskPage(todo.id),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getDueDateBorderColor(DateTime? dueDate, bool isCompleted) {
    if (isCompleted) return Colors.green.shade300;
    if (dueDate == null) return Colors.grey.shade300;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (taskDate.isBefore(today)) {
      return Colors.red; // Overdue
    } else if (taskDate.isAtSameMomentAs(today)) {
      return Colors.orange; // Due today
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
          title: const Text('Calendar', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        drawer: AppDrawer(),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              FutureBuilder<Map<DateTime, int>>(
                future: _taskCountFuture,
                builder: (context, snapshot) {
                  Map<DateTime, int> taskCountMap = snapshot.data ?? {};
                  return TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: _onDaySelected,
                    onPageChanged: _onPageChanged,
                    calendarFormat: CalendarFormat.month,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final taskCount = taskCountMap[DateTime(day.year, day.month, day.day)] ?? 0;
                        return _buildDayContent(day, taskCount);
                      },
                      todayBuilder: (context, day, focusedDay) {
                        final taskCount = taskCountMap[DateTime(day.year, day.month, day.day)] ?? 0;
                        return _buildDayContent(day, taskCount, isToday: true);
                      },
                      selectedBuilder: (context, day, focusedDay) {
                        final taskCount = taskCountMap[DateTime(day.year, day.month, day.day)] ?? 0;
                        return _buildDayContent(day, taskCount, isSelected: true);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Todo>>(
                  future: _tasksFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
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
                                  'Error loading tasks',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please try again later',
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
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                                  'No tasks for this day',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add a new task or select a different date',
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
                    final incompleteTasks = tasks.where((task) => !task.isCompleted).toList();
                    final completedTasks = tasks.where((task) => task.isCompleted).toList();

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (incompleteTasks.isNotEmpty)
                            _buildTaskSection(
                              title: 'Pending Tasks',
                              tasks: incompleteTasks,
                              icon: Icons.pending_actions,
                              color: Colors.orange,
                              isCompleted: false,
                            ),
                          if (incompleteTasks.isNotEmpty && completedTasks.isNotEmpty) const SizedBox(height: 16),
                          if (completedTasks.isNotEmpty)
                            _buildTaskSection(
                              title: 'Completed Tasks',
                              tasks: completedTasks,
                              icon: Icons.check_circle_outline,
                              color: Colors.green,
                              isCompleted: true,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
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
          future: Future.wait([_dueDateTasksStatsFuture, _recurringTasksStatsFuture, _tasksFuture]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            int dueDatePending = 0;
            int recurringPending = 0;
            int todayTasks = 0;

            if (snapshot.hasData) {
              final dueDateStats = snapshot.data![0] as Map<String, int>;
              final recurringStats = snapshot.data![1] as Map<String, int>;
              final todayTasksList = snapshot.data![2] as List<Todo>;

              dueDatePending = (dueDateStats['total'] ?? 0) - (dueDateStats['completed'] ?? 0);
              recurringPending = (recurringStats['total'] ?? 0) - (recurringStats['completed'] ?? 0);
              todayTasks = todayTasksList.where((t) => !t.isCompleted).length;
            }

            return buildBottomNavigationBar(dueDatePending, recurringPending, todayTasks: todayTasks);
          },
        ),
      ),
    );
  }
}
