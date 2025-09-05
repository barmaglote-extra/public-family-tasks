import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/subtodo.dart';
import 'package:tasks/models/subtodo_data.dart';
import 'package:tasks/models/task_notification.dart';
import 'package:tasks/models/todo.dart';
import 'package:tasks/models/todo_collection.dart';
import 'package:tasks/models/todo_fields.dart';
import 'package:tasks/models/todo_recurrent.dart';
import 'package:tasks/models/todo_regular.dart';
import 'package:tasks/pages/add_notification_page.dart';
import 'package:tasks/pages/sub_task_page.dart';
import 'package:tasks/pages/task_items/regular_subtask_item.dart';
import 'package:tasks/services/collections_service.dart';
import 'package:tasks/services/notification_service.dart';
import 'package:tasks/services/share_service.dart';
import 'package:tasks/services/sub_tasks_service.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/services/templates_service.dart';
import 'package:tasks/services/update_provider.dart';
import 'package:tasks/widgets/collection_dropdown.dart';
import 'package:tasks/widgets/date_picker_field.dart';
import 'package:tasks/widgets/recurrent_task_info_widget.dart';
import 'package:tasks/widgets/repeat_period_dropdown.dart';
import 'package:tasks/widgets/task_description_field.dart';
import 'package:tasks/widgets/task_name_field.dart';
import 'package:tasks/widgets/urgency_dropdown.dart';
import 'package:provider/provider.dart';
import 'package:tasks/services/localization_service.dart';
import 'package:tasks/widgets/localized_text.dart';

class TaskPage extends StatefulWidget {
  final int taskId;
  final _tasksService = locator<TasksService>();
  final _collectionsService = locator<CollectionsService>();
  final _notificationService = locator<NotificationService>();
  final _subTasksService = locator<SubTasksService>();
  final _updateProvider = locator<UpdateProvider>();

  TaskPage({super.key, required this.title, required this.taskId});

  final String title;

  @override
  State<TaskPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TaskPage> {
  final _shareService = ShareService();
  Todo? task;
  ToDoCollection? collection;
  bool _isEditMode = false;
  bool _hasChanges = false;
  int? urgency = 0;
  String? repeatPeriod;
  final TextEditingController _nameFieldController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  var _notifications = List<TaskNotification>.empty();
  List<SubTodo> _subTasks = [];
  List<Map<String, Object>> subTaskControllers = [];
  List<ToDoCollection> allCollections = [];
  ToDoCollection? selectedCollection;

  @override
  void initState() {
    super.initState();
    _loadData().then((_) {
      _loadTask();
      _loadNotifications();
    });
  }

  Future<void> _loadData() async {
    final data = await widget._collectionsService.getItems();
    setState(() {
      allCollections = data;
    });
  }

  Future<void> _loadTask() async {
    final data = await widget._tasksService.getItemById(widget.taskId);
    setState(() {
      task = data;
      if (data != null) {
        urgency = data.urgency;
        repeatPeriod = data.taskType == 'recurrent' ? (data as TodoRecurrent).recurrenceInterval : null;
        selectedCollection = allCollections.firstWhere(
          (col) => col.id == data.collectionId,
          orElse: () => ToDoCollection(id: data.collectionId, name: 'Unknown', description: 'Unknown'),
        );
        collection = selectedCollection;
      }
    });

    if (task?.taskType == 'regular') {
      _loadSubTasks();
    }
  }

  Future<void> _loadCollection() async {
    if (task == null) return;
    final data = await widget._collectionsService.getItemById(task!.collectionId);
    setState(() {
      collection = data;
    });
  }

  Future<void> _loadNotifications() async {
    final data = await widget._notificationService.getNotificationsByTaskId(widget.taskId, false) ??
        List<TaskNotification>.empty();
    setState(() {
      _notifications = data;
    });
  }

  Future<void> _loadSubTasks() async {
    final subTasks = await widget._subTasksService.getItemsByField<SubTodo>({'task_id': widget.taskId});
    setState(() {
      _subTasks = subTasks ?? [];
      subTaskControllers = _subTasks.map((subTask) {
        return {
          'id': subTask.id as Object,
          'uid': UniqueKey().toString() as Object,
          'name': TextEditingController(text: subTask.name) as Object,
        };
      }).toList();
    });
  }

  _onBack() {
    Navigator.pop(context, _hasChanges ? true : null);
    widget._updateProvider.notifyListeners();
  }

  Future<void> _deleteTask() async {
    if (task == null) return;

    showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
              title: const Text('Confirm'),
              content: Text("Delete ${task!.name}?"),
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
    await widget._tasksService.deleteItemById(task!.id);
    widget._updateProvider.notifyListeners();
    if (!mounted) return;
    Navigator.of(context).pop();
    _onBack();
  }

  Future<void> _removeNotification(int notificationId) async {
    await widget._notificationService.cancelNotification(notificationId);
    await _loadNotifications();
  }

  Future<void> _deleteSubTask(int subTaskId) async {
    await widget._subTasksService.deleteItemById(subTaskId);
    _loadSubTasks();
  }

  Future<void> _shareTask() async {
    if (task == null) return;

    try {
      await _shareService.shareTask(widget.taskId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task shared successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share task: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _addSubTask() {
    setState(() {
      subTaskControllers.add({
        'name': TextEditingController(),
      });
    });
  }

  void _removeSubTask(int index) {
    setState(() {
      (subTaskControllers[index]['name'] as TextEditingController?)?.dispose();
      subTaskControllers.removeAt(index);
    });
  }

  void _onReorderSubtasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;

      final item = subTaskControllers.removeAt(oldIndex);
      subTaskControllers.insert(newIndex, item);

      if (oldIndex < _subTasks.length && newIndex < _subTasks.length) {
        final subTask = _subTasks.removeAt(oldIndex);
        _subTasks.insert(newIndex, subTask);
      }
    });

    _saveSubTasksOrder();
  }

  Future<void> _saveSubTasksOrder() async {
    for (int i = 0; i < subTaskControllers.length; i++) {
      final subTaskId = subTaskControllers[i]['id'] as int?;
      if (subTaskId != null) {
        await widget._subTasksService.updateItemById(subTaskId, {
          'order_index': i,
        });

        final subTaskIndex = _subTasks.indexWhere((st) => st.id == subTaskId);
        if (subTaskIndex != -1 && subTaskIndex < _subTasks.length) {
          _subTasks[subTaskIndex] = SubTodo(
            id: _subTasks[subTaskIndex].id,
            name: _subTasks[subTaskIndex].name,
            taskId: _subTasks[subTaskIndex].taskId,
            isCompleted: _subTasks[subTaskIndex].isCompleted,
            description: _subTasks[subTaskIndex].description,
            urgency: _subTasks[subTaskIndex].urgency,
            dueDate: _subTasks[subTaskIndex].dueDate,
            orderIndex: i,
            taskType: _subTasks[subTaskIndex].taskType,
            collectionId: _subTasks[subTaskIndex].collectionId,
          );
        }
      }
    }

    widget._updateProvider.notifyListeners();
    _hasChanges = true;
  }

  _onEditSave() async {
    if (_isEditMode) {
      if (task != null && task!.taskType == 'recurrent' && (repeatPeriod == null || repeatPeriod == '')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Frequency is missing"),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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

      if (selectedCollection == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please select a collection"),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      int? dueDateMilliseconds;
      if (_dueDateController.text.isNotEmpty) {
        final parsedDate = DateTime.tryParse(_dueDateController.text);
        dueDateMilliseconds = parsedDate?.millisecondsSinceEpoch;
      } else if (task?.taskType == 'regular' && (task as TodoRegular).dueDate != null) {
        dueDateMilliseconds = (task as TodoRegular).dueDate!.millisecondsSinceEpoch;
      }

      await widget._tasksService.updateItemById(task!.id, {
        TodoFields.name: _nameFieldController.text,
        TodoFields.description: _descriptionController.text,
        TodoFields.urgency: urgency,
        TodoFields.recurrenceRule: repeatPeriod,
        TodoFields.collectionId: selectedCollection!.id,
        if (dueDateMilliseconds != null) TodoFields.dueDate: dueDateMilliseconds,
      });

      if (task?.taskType == 'regular') {
        for (var subTask in _subTasks) {
          if (!subTaskControllers.any((controller) => controller['id'] == subTask.id)) {
            await widget._subTasksService.deleteItemById(subTask.id);
          }
        }

        List<Map<String, Object>> updatedSubTaskControllers = [];

        for (int i = 0; i < subTaskControllers.length; i++) {
          final subTaskController = subTaskControllers[i];
          final subTaskName = (subTaskController['name'] as TextEditingController).text;
          final subTaskId = subTaskController['id'] as int?;

          if (subTaskName.isNotEmpty) {
            if (subTaskId == null) {
              final subTodoData = SubTodoData(
                name: subTaskName,
                taskId: task!.id,
                isCompleted: 0,
                dueDate: null,
                description: '',
                urgency: null,
                orderIndex: i,
              );

              await widget._subTasksService.addItem(subTodoData);

              updatedSubTaskControllers.add({
                'name': TextEditingController(text: subTodoData.name),
              });
            } else {
              final updateData = {
                'name': subTaskName,
                'order_index': i,
              };
              await widget._subTasksService.updateItemById(subTaskId, updateData);
              updatedSubTaskControllers.add({
                'id': subTaskId as Object,
                'name': TextEditingController(text: subTaskName) as Object,
              });
            }
          } else {
            // Skip empty subtask names
          }
        }

        setState(() {
          subTaskControllers = updatedSubTaskControllers;
        });

        await _loadSubTasks();
      }

      widget._updateProvider.notifyListeners();
      setState(() {
        _isEditMode = false;
        collection = selectedCollection;
      });
      await _loadData();
      await _loadTask();
      _hasChanges = true;
    } else {
      setState(() {
        _nameFieldController.text = task!.name;
        _descriptionController.text = task!.description ?? '';
        repeatPeriod = task?.taskType == 'recurrent' ? ((task as TodoRecurrent).recurrenceInterval ?? 'weekly') : '';
        if (task?.taskType == 'regular') {
          _dueDateController.text = (task as TodoRegular).dueDate != null
              ? DateFormat('dd.MM.yyyy').format((task as TodoRegular).dueDate!)
              : '';
        }
        selectedCollection = collection;
        _isEditMode = true;
      });
    }
  }

  void _navigateToSubTaskPage(int taskId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SubTaskPage(title: "Sub Task", taskId: taskId)),
    ).then((_) {
      _loadCollection();
      _loadTask();
      _loadNotifications();
    });
  }

  Future<void> _addNotification() async {
    if (task == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddNotificationPage(task: task!, isSubTask: false),
      ),
    );

    if (result == true) {
      await _loadNotifications();
    }
  }

  Future<void> _updateTaskState() async {
    if (task?.id == null) return;
    await (task!.isCompleted
        ? widget._tasksService.markTaskAsNotCompleted(task!.id)
        : widget._tasksService.markTaskAsCompleted(task!.id));

    _loadTask();
  }

  Future<void> _updateSubTaskState(int subTaskId, bool isCompleted) async {
    await widget._subTasksService.updateItemById(subTaskId, {
      'is_completed': isCompleted ? 1 : 0,
    });
    await _loadSubTasks();
    widget._updateProvider.notifyListeners();
    setState(() {});
    _hasChanges = true;
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

  @override
  void dispose() {
    _nameFieldController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    for (var subTask in subTaskControllers) {
      (subTask['name'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Task', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (!_isEditMode)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteTask,
              ),
            if (task?.taskType == 'regular' && !_isEditMode)
              IconButton(
                icon: task != null
                    ? task!.isCompleted
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
            if (!_isEditMode)
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareTask,
                tooltip: 'Share Task',
              ),
            // Add Save as Template button
            if (!_isEditMode && task?.taskType == 'regular')
              IconButton(
                icon: const Icon(Icons.bookmark_add),
                onPressed: _saveAsTemplate,
                tooltip: context.tr('actions.save_as_template'),
              ),
            IconButton(
              icon: _isEditMode ? const Icon(Icons.save) : const Icon(Icons.edit),
              onPressed: _onEditSave,
            ),
          ],
        ),
        drawer: AppDrawer(),
        body: SingleChildScrollView(
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
                // Edit Mode Cards
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit, size: 24, color: Colors.blue),
                            const SizedBox(width: 8),
                            Consumer<LocalizationService>(
                              builder: (context, localizationService, child) {
                                return Text(
                                  localizationService.translate('task_details.task_details'),
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
                        Consumer<LocalizationService>(
                          builder: (context, localizationService, child) {
                            return Text(
                              localizationService.translate('task_details.collection'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            );
                          },
                        ),
                        SizedBox(
                          width: 230,
                          child: CollectionDropdown(
                            collections: allCollections,
                            selectedCollection: selectedCollection,
                            onChanged: (newCollection) {
                              setState(() {
                                selectedCollection = newCollection;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Consumer<LocalizationService>(
                          builder: (context, localizationService, child) {
                            return Text(
                              localizationService.translate('task_details.title'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            );
                          },
                        ),
                        TaskNameField(controller: _nameFieldController),
                        const SizedBox(height: 10),
                        Consumer<LocalizationService>(
                          builder: (context, localizationService, child) {
                            return Text(
                              localizationService.translate('task_details.description'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            );
                          },
                        ),
                        TaskDescriptionField(controller: _descriptionController),
                        const SizedBox(height: 10),
                        Consumer<LocalizationService>(
                          builder: (context, localizationService, child) {
                            return Text(
                              localizationService.translate('task_details.importance'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            );
                          },
                        ),
                        UrgencyDropdown(
                          selectedUrgency: urgency,
                          onChanged: (newUrgency) {
                            setState(() {
                              urgency = newUrgency;
                            });
                          },
                        ),
                        if (task?.taskType == 'recurrent') ...[
                          const SizedBox(height: 10),
                          Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Text(
                                localizationService.translate('task_details.frequency'),
                                style:
                                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              );
                            },
                          ),
                          RepeatPeriodDropdown(
                            selectedPeriod: repeatPeriod,
                            onChanged: (newPeriod) {
                              setState(() {
                                repeatPeriod = newPeriod;
                              });
                            },
                          ),
                        ],
                        if (task?.taskType == 'regular') ...[
                          const SizedBox(height: 10),
                          Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Text(
                                localizationService.translate('task_details.due_date'),
                                style:
                                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              );
                            },
                          ),
                          DatePickerField(controller: _dueDateController, label: ''),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Subtasks Card (only for regular tasks in edit mode)
                if (task?.taskType == 'regular') ...[
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.list, size: 24, color: Colors.green),
                              const SizedBox(width: 8),
                              Consumer<LocalizationService>(
                                builder: (context, localizationService, child) {
                                  return Text(
                                    localizationService.translate('task_details.subtasks'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: _addSubTask,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ReorderableListView.builder(
                            key: const PageStorageKey('edit_task_subtasks_list'),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: subTaskControllers.length,
                            onReorder: _onReorderSubtasks,
                            buildDefaultDragHandles: false,
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                color: Colors.transparent,
                                elevation: 0,
                                child: child,
                              );
                            },
                            itemBuilder: (context, index) {
                              final subTask = subTaskControllers[index];
                              final keyValue = (subTask['uid'] ?? subTask['id'] ?? index).toString();
                              return Dismissible(
                                key: ValueKey(keyValue),
                                direction: DismissDirection.horizontal,
                                dismissThresholds: const {
                                  DismissDirection.startToEnd: 0.8,
                                  DismissDirection.endToStart: 0.8,
                                },
                                movementDuration: const Duration(milliseconds: 300),
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                secondaryBackground: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Delete subtask?'),
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
                                onDismissed: (_) => _removeSubTask(index),
                                child: Container(
                                  color: Colors.transparent,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          ReorderableDragStartListener(
                                            index: index,
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                                              child: Icon(Icons.drag_handle),
                                            ),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: subTask['name'] as TextEditingController,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
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
                ],
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
                          color: task?.taskType == 'regular'
                              ? _getDueDateBorderColor((task as TodoRegular?)?.dueDate, task?.isCompleted ?? false)
                              : _getUrgencyColor(task?.urgency),
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
                              Consumer<LocalizationService>(
                                builder: (context, localizationService, child) {
                                  return Text(
                                    localizationService.translate('task_details.task_details'),
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
                          Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Text(
                                localizationService.translate('task_details.collection'),
                                style:
                                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              );
                            },
                          ),
                          Text(collection?.name ?? 'Unknown',
                              style: const TextStyle(fontSize: 14), softWrap: true, overflow: TextOverflow.visible),
                          const SizedBox(height: 10),
                          Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Text(
                                localizationService.translate('task_details.title'),
                                style:
                                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              );
                            },
                          ),
                          Text(task?.name ?? 'Missing',
                              style: const TextStyle(fontSize: 14), softWrap: true, overflow: TextOverflow.visible),
                          const SizedBox(height: 10),
                          Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Text(
                                localizationService.translate('task_details.description'),
                                style:
                                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              );
                            },
                          ),
                          Text(task?.description ?? 'Missing', style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 10),
                          Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Text(
                                localizationService.translate('task_details.type'),
                                style:
                                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              );
                            },
                          ),
                          Text(
                              task?.taskType != null
                                  ? (task?.taskType == 'regular'
                                      ? context.tr('tasks.one_time_tasks')
                                      : context.tr('tasks.recurring_tasks'))
                                  : context.tr('common.no_data'),
                              style: const TextStyle(fontSize: 14),
                              softWrap: true,
                              overflow: TextOverflow.visible),
                          const SizedBox(height: 10),
                          Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Text(
                                localizationService.translate('task_details.importance'),
                                style:
                                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              );
                            },
                          ),
                          Row(
                            children: [
                              if (task?.urgency != 0) ...[
                                Text(
                                  '!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: task?.urgency == 2 ? Colors.red : Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 2),
                              ],
                              Text(
                                (task?.urgency == 0
                                    ? context.tr('tasks.normal')
                                    : task?.urgency == 1
                                        ? context.tr('tasks.urgent')
                                        : context.tr('tasks.extra_urgent')),
                                style: TextStyle(
                                  fontWeight: task?.urgency == 0 ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          if (task?.taskType == 'regular') ...[
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
                            Text((task as TodoRegular).dueDate != null
                                ? DateFormat('dd.MM.yyyy').format((task as TodoRegular).dueDate!)
                                : 'No set'),
                          ],
                          if (task?.taskType == 'recurrent') ...[
                            const SizedBox(height: 10),
                            Consumer<LocalizationService>(
                              builder: (context, localizationService, child) {
                                return Text(
                                  localizationService.translate('task_details.frequency'),
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                );
                              },
                            ),
                            Text((task as TodoRecurrent).recurrenceInterval ?? ''),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Completion Status Card (only for regular tasks in view mode)
                if (task?.taskType == 'regular' && !_isEditMode) ...[
                  Card(
                    color: Colors.white,
                    child: Container(
                      decoration: BoxDecoration(
                        color: task?.isCompleted == true ? Colors.green.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: task?.isCompleted == true ? Colors.green.shade200 : Colors.grey.shade300,
                          width: 1.0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  task?.isCompleted == true ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 24,
                                  color: task?.isCompleted == true ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Consumer<LocalizationService>(
                                  builder: (context, localizationService, child) {
                                    return Text(
                                      localizationService.translate('task_details.completion_status'),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: task?.isCompleted == true ? Colors.green.shade700 : Colors.black,
                                      ),
                                    );
                                  },
                                ),
                                const Spacer(),
                                if (task?.isCompleted == true)
                                  Icon(
                                    Icons.check_circle,
                                    size: 48,
                                    color: Colors.green.shade600,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              task?.isCompleted == true
                                  ? context.tr('tasks.task_completed')
                                  : context.tr('tasks.task_not_completed'),
                              style: TextStyle(
                                fontSize: 14,
                                color: task?.isCompleted == true ? Colors.green.shade700 : Colors.grey.shade600,
                                fontWeight: task?.isCompleted == true ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Reminders Card (only if reminders exist)
                if (!_isEditMode && task != null && _notifications.isNotEmpty) ...[
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

                // Subtasks Card (only for regular tasks in view mode)
                if (task?.taskType == 'regular') ...[
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.list, size: 24, color: Colors.green),
                              const SizedBox(width: 8),
                              Consumer<LocalizationService>(
                                builder: (context, localizationService, child) {
                                  return Text(
                                    localizationService.translate('task_details.subtasks'),
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
                          if (_subTasks.isEmpty)
                            Text(context.tr('subtasks.no_subtasks'), style: const TextStyle(fontSize: 14))
                          else
                            Column(
                              children: _subTasks.map((subTask) {
                                return Dismissible(
                                    key: Key(subTask.id.toString()),
                                    direction: DismissDirection.horizontal,
                                    dismissThresholds: const {
                                      DismissDirection.startToEnd: 0.8,
                                      DismissDirection.endToStart: 0.8,
                                    },
                                    movementDuration: const Duration(milliseconds: 300),
                                    background: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 20),
                                      child: const Icon(Icons.delete, color: Colors.white),
                                    ),
                                    secondaryBackground: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(Icons.delete, color: Colors.white),
                                    ),
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('Delete subtask?'),
                                            content: Text('Delete ${subTask.name}?'),
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
                                      final messenger = ScaffoldMessenger.of(context);
                                      await _deleteSubTask(subTask.id);
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('${subTask.name} deleted')),
                                      );
                                    },
                                    child: RegularSubTaskItem(
                                      task: subTask,
                                      collection: null,
                                      onTaskStateChanged: (isCompleted, taskId) =>
                                          _updateSubTaskState(subTask.id, isCompleted ?? subTask.isCompleted),
                                      onTaskTap: (taskId) => _navigateToSubTaskPage(subTask.id),
                                    ));
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Recurrent Task Results Card (only for recurrent tasks in view mode)
                if (task is TodoRecurrent && !_isEditMode) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.analytics, size: 24, color: Colors.purple),
                              const SizedBox(width: 8),
                              const Text(
                                'Results',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SingleChildScrollView(
                            child: RecurrentTaskInfoWidget(
                              taskId: task!.id,
                              recurrenceRule: (task as TodoRecurrent).recurrenceInterval,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ));
  }

  // Add this method to save task as template
  Future<void> _saveAsTemplate() async {
    if (task == null) return;

    // Ensure subtasks are loaded
    if (_subTasks.isEmpty && task!.taskType == 'regular') {
      await _loadSubTasks();
    }

    try {
      // Create template data
      final templateService = locator<TemplatesService>();
      final templateData = {
        'name': task!.name,
        'description': task!.description,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      // Save template
      final templateId = await templateService.createTemplate(templateData);

      // Save subtasks as template subtasks
      for (var subTask in _subTasks) {
        final subtaskData = {
          'template_id': templateId,
          'name': subTask.name,
          'description': subTask.description,
          'urgency': subTask.urgency,
          'order_index': subTask.orderIndex,
        };
        await templateService.createTemplateSubtask(subtaskData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('templates.template_saved')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save as template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
