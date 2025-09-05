import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/subtask_fields.dart';
import 'package:tasks/models/subtodo.dart';
import 'package:tasks/models/task_notification.dart';
import 'package:tasks/models/todo.dart';
import 'package:tasks/models/todo_collection.dart';
import 'package:tasks/models/todo_fields.dart';
import 'package:tasks/pages/add_notification_page.dart';
import 'package:tasks/services/collections_service.dart';
import 'package:tasks/services/localization_service.dart';
import 'package:tasks/services/notification_service.dart';
import 'package:tasks/services/sub_tasks_service.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/services/update_provider.dart';
import 'package:tasks/widgets/date_picker_field.dart';
import 'package:tasks/widgets/localized_text.dart';
import 'package:tasks/widgets/task_description_field.dart';
import 'package:tasks/widgets/task_name_field.dart';
import 'package:tasks/widgets/urgency_dropdown.dart';

class SubTaskPage extends StatefulWidget {
  final int taskId;
  final _tasksService = locator<TasksService>();
  final _collectionsService = locator<CollectionsService>();
  final _notificationService = locator<NotificationService>();
  final _subTasksService = locator<SubTasksService>();
  final _updateProvider = locator<UpdateProvider>();

  SubTaskPage({super.key, required this.title, required this.taskId});

  final String title;

  @override
  State<SubTaskPage> createState() => _SubTasksPageState();
}

class _SubTasksPageState extends State<SubTaskPage> {
  Todo? task;
  SubTodo? subTask;
  ToDoCollection? collection;
  bool _isEditMode = false;
  int? urgency = 0;
  String? repeatPeriod;
  final TextEditingController _nameFieldController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  var _notifications = List<TaskNotification>.empty();

  @override
  void initState() {
    super.initState();
    _loadSubTask();
  }

  Future<void> _loadSubTask() async {
    final data = await widget._subTasksService.getItemById(widget.taskId);
    setState(() {
      subTask = data;
      if (data != null) {
        urgency = data.urgency;
      }
    });

    _loadTask();
    _loadNotifications();
  }

  Future<void> _loadTask() async {
    if (subTask == null) return;
    final data = await widget._tasksService.getItemById(subTask!.taskId);
    setState(() {
      task = data;
    });

    _loadCollection();
  }

  Future<void> _loadCollection() async {
    if (task == null) return;
    final data = await widget._collectionsService.getItemById(task!.collectionId);
    setState(() {
      collection = data;
    });
  }

  Future<void> _loadNotifications() async {
    if (subTask == null) return;
    final data =
        await widget._notificationService.getNotificationsByTaskId(subTask!.id, true) ?? List<TaskNotification>.empty();
    setState(() {
      _notifications = data;
    });
  }

  _onBack() {
    Navigator.pop(context);
    widget._updateProvider.notifyListeners();
  }

  Future<void> _deleteTask() async {
    if (subTask == null) return;

    showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
              title: const Text('Confirm'),
              content: Text("Delete ${subTask!.name}?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => _confirmDelete(context),
                  child: const Text('Confirm'),
                ),
              ],
            ));
  }

  Future<void> _confirmDelete(context) async {
    await widget._subTasksService.deleteItemById(subTask!.id);
    widget._updateProvider.notifyListeners();
    Navigator.of(context).pop();
    _onBack();
  }

  Future<void> _removeNotification(int notificationId) async {
    await widget._notificationService.cancelNotification(notificationId);
    await _loadNotifications();
  }

  _onEditSave() {
    if (_isEditMode) {
      if (_nameFieldController.text == '') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Title is missing"),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      widget._subTasksService.updateItemById(subTask!.id, {
        TodoFields.name: _nameFieldController.text,
        TodoFields.description: _descriptionController.text,
        TodoFields.urgency: urgency,
        TodoFields.dueDate: DateTime.tryParse(_dueDateController.value.text)?.millisecondsSinceEpoch
      });
      widget._updateProvider.notifyListeners();
      setState(() {
        _isEditMode = false;
      });
      _loadSubTask();
    } else {
      setState(() {
        _nameFieldController.text = subTask!.name;
        _descriptionController.text = subTask!.description ?? '';
        _dueDateController.text = subTask!.dueDate != null ? DateFormat('dd.MM.yyyy').format(subTask!.dueDate!) : '';
        _isEditMode = true;
      });
    }
  }

  Future<void> _addNotification() async {
    if (subTask == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddNotificationPage(task: subTask!, isSubTask: true),
      ),
    );

    if (result == true) {
      await _loadNotifications();
    }
  }

  Future<void> _updateTaskState() async {
    if (subTask?.id == null) return;
    await widget._subTasksService
        .updateItemById(subTask!.id, {SubtaskFields.isCompleted: subTask!.isCompleted == true ? 0 : 1});
    _loadSubTask();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Sub Task', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (!_isEditMode)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteTask,
              ),
            if (!_isEditMode)
              IconButton(
                icon: subTask != null
                    ? subTask!.isCompleted
                        ? const Icon(Icons.update)
                        : const Icon(Icons.task_alt)
                    : const Icon(Icons.error),
                onPressed: _updateTaskState,
              ),
            if (!_isEditMode)
              IconButton(
                icon: const Icon(Icons.notification_add),
                onPressed: _addNotification,
              ),
            IconButton(
              icon: const Icon(Icons.arrow_circle_left_outlined),
              onPressed: _onBack,
            ),
            IconButton(
              icon: _isEditMode ? const Icon(Icons.save) : const Icon(Icons.edit),
              onPressed: _onEditSave,
            ),
          ],
        ),
        drawer: AppDrawer(),
        body: subTask != null
            ? SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16.0,
                  16.0,
                  16.0,
                  16.0 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEditMode) ...[
                      // Edit Mode Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.edit, size: 24, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Subtask Details',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text("Title",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              TaskNameField(controller: _nameFieldController),
                              const SizedBox(height: 10),
                              const Text("Description",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              TaskDescriptionField(controller: _descriptionController),
                              const SizedBox(height: 10),
                              const Text("Importance",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              UrgencyDropdown(
                                selectedUrgency: urgency,
                                onChanged: (newUrgency) {
                                  setState(() {
                                    urgency = newUrgency;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              const Text("Due Date",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              DatePickerField(controller: _dueDateController, label: ''),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // View Mode Cards
                      Card(
                        color: Colors.white,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border(
                              left: BorderSide(
                                color: _getDueDateBorderColor(subTask?.dueDate, subTask?.isCompleted ?? false),
                                width: 4.0,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 24, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Subtask Information',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text("Collection",
                                    style:
                                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                Text(collection?.name ?? 'Unknown',
                                    style: const TextStyle(fontSize: 14),
                                    softWrap: true,
                                    overflow: TextOverflow.visible),
                                const SizedBox(height: 10),
                                Consumer<LocalizationService>(
                                  builder: (context, localizationService, child) {
                                    return Text(
                                      localizationService.translate('subtasks.parent_task'),
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                    );
                                  },
                                ),
                                Text(task?.name ?? context.tr('common.no_data'),
                                    style: const TextStyle(fontSize: 14),
                                    softWrap: true,
                                    overflow: TextOverflow.visible),
                                const SizedBox(height: 10),
                                Consumer<LocalizationService>(
                                  builder: (context, localizationService, child) {
                                    return Text(
                                      localizationService.translate('subtasks.subtask_title'),
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                    );
                                  },
                                ),
                                Text(subTask?.name ?? context.tr('common.no_data'),
                                    style: const TextStyle(fontSize: 14),
                                    softWrap: true,
                                    overflow: TextOverflow.visible),
                                const SizedBox(height: 10),
                                Consumer<LocalizationService>(
                                  builder: (context, localizationService, child) {
                                    return Text(
                                      localizationService.translate('task_details.description'),
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                    );
                                  },
                                ),
                                Text(subTask?.description ?? context.tr('common.no_data'),
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(height: 10),
                                Consumer<LocalizationService>(
                                  builder: (context, localizationService, child) {
                                    return Text(
                                      localizationService.translate('task_details.importance'),
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                    );
                                  },
                                ),
                                Row(
                                  children: [
                                    if (subTask?.urgency != 0) ...[
                                      Text(
                                        '!',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: subTask?.urgency == 2 ? Colors.red : Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                    ],
                                    Text(
                                      (subTask?.urgency == 0
                                          ? context.tr('tasks.normal')
                                          : subTask?.urgency == 1
                                              ? context.tr('tasks.urgent')
                                              : context.tr('tasks.extra_urgent')),
                                      style: TextStyle(
                                        fontWeight: subTask?.urgency == 0 ? FontWeight.normal : FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Consumer<LocalizationService>(
                                  builder: (context, localizationService, child) {
                                    return Text(
                                      localizationService.translate('task_details.due_date'),
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                    );
                                  },
                                ),
                                Text(subTask!.dueDate != null
                                    ? DateFormat('dd.MM.yyyy').format(subTask!.dueDate!)
                                    : context.tr('tasks.no_set')),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Reminders Card (only if reminders exist)
                      if (!_isEditMode && subTask != null && _notifications.isNotEmpty) ...[
                        Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.notifications, size: 24, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Reminders',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (_notifications.isEmpty)
                                  const Text("No reminders set", style: TextStyle(fontSize: 14))
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _notifications.map((notification) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Container(
                                          padding: const EdgeInsets.all(8.0),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.blueGrey, width: 1.0),
                                            borderRadius: BorderRadius.circular(8.0),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      notification.request.title ?? 'No title',
                                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      notification.request.body ?? 'No body',
                                                      style: const TextStyle(fontSize: 14),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      "Scheduled: ${notification.scheduledDate.toString()}",
                                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 20, color: Colors.red),
                                                onPressed: () {
                                                  _removeNotification(notification.request.id);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                ),
              )
            : Center(child: CircularProgressIndicator()));
  }
}
