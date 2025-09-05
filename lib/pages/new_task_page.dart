import 'package:flutter/material.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/subtodo_data.dart';
import 'package:tasks/models/todo_collection.dart';
import 'package:tasks/models/todo_data.dart';
import 'package:tasks/services/collections_service.dart';
import 'package:tasks/services/sub_tasks_service.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/services/templates_service.dart';
import 'package:tasks/services/update_provider.dart';
import 'package:tasks/widgets/date_picker_field.dart';
import 'package:tasks/widgets/repeat_period_dropdown.dart';
import 'package:tasks/widgets/task_description_field.dart';
import 'package:tasks/widgets/task_name_field.dart';
import 'package:tasks/widgets/task_type_dropdown.dart';
import 'package:tasks/widgets/urgency_dropdown.dart';

import '../widgets/collection_dropdown.dart';

class NewTaskPage extends StatefulWidget {
  final int? collectionId;
  final Map<String, dynamic>? importedTaskData; // Added for import functionality
  final int? templateId; // Add this field for template support
  final _tasksService = locator<TasksService>();
  final _collectionsService = locator<CollectionsService>();
  final _subTasksService = locator<SubTasksService>();
  final _templatesService = locator<TemplatesService>(); // Add this service
  final _updateProvider = locator<UpdateProvider>();

  NewTaskPage({
    super.key,
    required this.title,
    this.collectionId,
    this.importedTaskData, // Added import parameter
    this.templateId, // Add template parameter
  });

  final String title;

  @override
  State<NewTaskPage> createState() => _NewTasksPageState();
}

class _NewTasksPageState extends State<NewTaskPage> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ToDoCollection? collection;
  List<ToDoCollection> allCollections = [];
  ToDoCollection? selectedCollection;

  String taskType = 'regular';
  String? repeatPeriod;
  int? urgency = 0;

  List<Map<String, dynamic>> subTasks = [];
  bool _isImportedTask = false; // Flag to track if this is imported

  void _addTask() async {
    if (taskType == 'recurrent' && (repeatPeriod == null || repeatPeriod == '')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Frequency is missing"),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red[300],
        ),
      );
      return;
    }

    if (_textController.text == '') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Title is missing"),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red[300],
        ),
      );
      return;
    }

    if ((widget.collectionId == null || widget.collectionId == -1) && selectedCollection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please select a collection"),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red[300],
        ),
      );
      return;
    }

    final todoData = TodoData(
      name: _textController.text,
      collectionId:
          (widget.collectionId != null && widget.collectionId != -1) ? widget.collectionId! : selectedCollection!.id,
      taskType: taskType,
      recurrenceRule: repeatPeriod ?? '',
      isCompleted: 0,
      description: _descriptionController.text,
      urgency: urgency ?? 0,
      dueDate: DateTime.tryParse(_dueDateController.value.text)?.millisecondsSinceEpoch,
    );

    await widget._tasksService.addItem(todoData);

    final addedTask = await widget._tasksService.getItemsByFilter(
      where: 'name = ? AND collection_id = ?',
      whereArgs: [
        _textController.text,
        (widget.collectionId != null && widget.collectionId != -1) ? widget.collectionId! : selectedCollection!.id
      ],
    );

    if (addedTask != null && addedTask.isNotEmpty) {
      final taskId = addedTask.first.id;

      for (int i = 0; i < subTasks.length; i++) {
        final subTask = subTasks[i];
        final subTaskData = SubTodoData(
          name: subTask['name']!.text,
          taskId: taskId,
          isCompleted: 0,
          dueDate: DateTime.tryParse(subTask['dueDate']!.text)?.millisecondsSinceEpoch,
          description: '',
          urgency: null,
          orderIndex: i,
        );
        await widget._subTasksService.addItem(subTaskData);
      }
    }

    if (mounted) {
      Navigator.pop(context, true);
      widget._updateProvider.notifyListeners();
    }
  }

  void _addSubTask() {
    setState(() {
      subTasks.add({
        'uid': UniqueKey().toString(),
        'name': TextEditingController(),
        'dueDate': TextEditingController(),
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeSubTask(int index) {
    setState(() {
      (subTasks[index]['name'] as TextEditingController?)?.dispose();
      (subTasks[index]['dueDate'] as TextEditingController?)?.dispose();
      subTasks.removeAt(index);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = subTasks.removeAt(oldIndex);
      subTasks.insert(newIndex, item);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData().then((_) {
      _loadImportedData(); // Load imported data after collections are loaded
      _loadTemplateData(); // Load template data after collections are loaded
    });
  }

  Future<void> _loadData() async {
    if (widget.collectionId != null && widget.collectionId != -1) {
      final data = await widget._collectionsService.getItemById(widget.collectionId!);
      setState(() {
        collection = data;
      });
    } else {
      final data = await widget._collectionsService.getItems();
      setState(() {
        allCollections = data;
      });
    }
  }

  Future<void> _loadImportedData() async {
    if (widget.importedTaskData != null) {
      setState(() {
        _isImportedTask = true;

        // Fill form fields with imported data
        _textController.text = widget.importedTaskData!['name'] ?? '';
        _descriptionController.text = widget.importedTaskData!['description'] ?? '';
        urgency = widget.importedTaskData!['urgency'] ?? 0;
        taskType = widget.importedTaskData!['taskType'] ?? 'regular';

        // Handle due date
        final importedDueDate = widget.importedTaskData!['dueDate'] as DateTime?;
        if (importedDueDate != null) {
          _dueDateController.text = importedDueDate.toString().split(' ')[0]; // YYYY-MM-DD format
        }

        // Handle recurrence
        if (taskType == 'recurrent') {
          repeatPeriod = widget.importedTaskData!['recurrenceInterval'];
        }

        // Handle subtasks
        final importedSubtasks = widget.importedTaskData!['subtasks'] as List<dynamic>? ?? [];
        subTasks = importedSubtasks.map((subtask) {
          final dueDateController = TextEditingController();
          final subtaskDueDate = subtask['dueDate'] as DateTime?;
          if (subtaskDueDate != null) {
            dueDateController.text = subtaskDueDate.toString().split(' ')[0];
          }

          return {
            'uid': UniqueKey().toString(),
            'name': TextEditingController(text: subtask['name'] ?? ''),
            'dueDate': dueDateController,
          };
        }).toList();
      });

      // Show import notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Task imported successfully! Original export date: ${widget.importedTaskData!['originalExportDate'] ?? 'Unknown'}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Add this method to load template data
  Future<void> _loadTemplateData() async {
    if (widget.templateId != null) {
      try {
        final template = await widget._templatesService.getTemplateById(widget.templateId!);
        if (template != null) {
          setState(() {
            // Fill form fields with template data
            _textController.text = template.name;
            _descriptionController.text = template.description ?? '';

            // Handle subtasks
            subTasks = template.subtasks.map((subtask) {
              return {
                'uid': UniqueKey().toString(),
                'name': TextEditingController(text: subtask.name),
                'dueDate': TextEditingController(),
              };
            }).toList();
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Template loaded successfully'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load template: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
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
  void dispose() {
    _textController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    for (var subTask in subTasks) {
      (subTask['name'] as TextEditingController?)?.dispose();
      (subTask['dueDate'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          _isImportedTask
              ? "Import Task"
              : widget.collectionId != null
                  ? (collection?.name ?? "Loading...")
                  : "New Task",
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_circle_left_outlined),
            disabledColor: Colors.black38,
            onPressed: _onBack,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            disabledColor: Colors.black38,
            onPressed: _addTask,
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (widget.collectionId == null || widget.collectionId == -1) ...[
                const Text(
                  "Collection",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
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
                const SizedBox(height: 20),
              ],
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                Expanded(
                  child: Text(
                    _isImportedTask ? 'Import Task' : 'New Task',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 18),
                    textAlign: TextAlign.start,
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: TaskTypeDropdown(
                    currentType: taskType,
                    onChanged: (newType) {
                      setState(() {
                        taskType = newType!;
                        if (taskType == 'regular') {
                          repeatPeriod = null;
                        } else {
                          for (var subTask in subTasks) {
                            (subTask['name'] as TextEditingController?)?.dispose();
                            (subTask['dueDate'] as TextEditingController?)?.dispose();
                          }
                          subTasks.clear();
                        }
                      });
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              const Text("Title", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              TaskNameField(controller: _textController),
              const SizedBox(height: 20),
              const Text("Description",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              TaskDescriptionField(controller: _descriptionController),
              const SizedBox(height: 20),
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
              if (taskType == 'regular') ...[
                const SizedBox(height: 20),
                const Text("Due Date",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                DatePickerField(label: '', controller: _dueDateController),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Subtasks",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addSubTask,
                    ),
                  ],
                ),
                ReorderableListView.builder(
                  key: const PageStorageKey('new_task_subtasks_list'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: subTasks.length,
                  onReorder: _onReorder,
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final subTask = subTasks[index];
                    return Dismissible(
                      key: ValueKey(subTask['uid'] as String),
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
                    );
                  },
                ),
              ],
              if (taskType == 'recurrent') ...[
                const SizedBox(height: 20),
                const Text("Frequency",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                RepeatPeriodDropdown(
                  selectedPeriod: repeatPeriod,
                  onChanged: (newPeriod) {
                    setState(() {
                      repeatPeriod = newPeriod;
                    });
                  },
                ),
              ],
              SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
            ],
          ),
        ),
      ),
    );
  }
}
