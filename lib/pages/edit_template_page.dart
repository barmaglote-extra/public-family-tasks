import 'package:flutter/material.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/mixins/back_button_mixin.dart';
import 'package:tasks/models/template.dart';
import 'package:tasks/services/templates_service.dart';
import 'package:tasks/services/update_provider.dart';
import 'package:tasks/widgets/localized_text.dart';
import 'package:tasks/widgets/task_description_field.dart';
import 'package:tasks/widgets/task_name_field.dart';

class EditTemplatePage extends StatefulWidget {
  final int? templateId;

  const EditTemplatePage({super.key, this.templateId});

  @override
  State<EditTemplatePage> createState() => _EditTemplatePageState();
}

class _EditTemplatePageState extends State<EditTemplatePage> with BackButtonMixin {
  final _templatesService = locator<TemplatesService>();
  final _updateProvider = locator<UpdateProvider>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _subTasks = <Map<String, dynamic>>[];
  bool _isLoading = true;
  Template? _template;

  @override
  void initState() {
    super.initState();
    if (widget.templateId != null) {
      _loadTemplate();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTemplate() async {
    try {
      final template = await _templatesService.getTemplateById(widget.templateId!);
      if (template != null) {
        setState(() {
          _template = template;
          _nameController.text = template.name;
          _descriptionController.text = template.description ?? '';
          _subTasks = template.subtasks.map((subtask) {
            return <String, dynamic>{
              'id': subtask.id,
              'uid': UniqueKey().toString(),
              'name': TextEditingController(text: subtask.name),
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveTemplate() async {
    if (_nameController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LocalizedText('tasks.task_name_required'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      if (widget.templateId != null && _template != null) {
        // Update existing template
        final templateData = {
          'name': _nameController.text,
          'description': _descriptionController.text,
          'created_at': _template!.createdAt.millisecondsSinceEpoch,
        };
        await _templatesService.updateTemplate(widget.templateId!, templateData);

        // Delete existing subtasks
        await _templatesService.deleteTemplateSubtasks(widget.templateId!);

        // Add updated subtasks
        for (int i = 0; i < _subTasks.length; i++) {
          final subTaskController = _subTasks[i]['name'] as TextEditingController;
          if (subTaskController.text.isNotEmpty) {
            final subtaskData = {
              'template_id': widget.templateId!,
              'name': subTaskController.text,
              'description': '',
              'urgency': 0,
              'order_index': i,
            };
            await _templatesService.createTemplateSubtask(subtaskData);
          }
        }
      } else {
        // Create new template
        final templateData = {
          'name': _nameController.text,
          'description': _descriptionController.text,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        };
        final templateId = await _templatesService.createTemplate(templateData);

        // Add subtasks
        for (int i = 0; i < _subTasks.length; i++) {
          final subTaskController = _subTasks[i]['name'] as TextEditingController;
          if (subTaskController.text.isNotEmpty) {
            final subtaskData = {
              'template_id': templateId,
              'name': subTaskController.text,
              'description': '',
              'urgency': 0,
              'order_index': i,
            };
            await _templatesService.createTemplateSubtask(subtaskData);
          }
        }
      }

      _updateProvider.notifyListeners();
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.templateId != null
                ? context.tr('templates.template_updated')
                : context.tr('templates.template_created')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addSubTask() {
    setState(() {
      _subTasks.add(<String, dynamic>{
        'uid': UniqueKey().toString(),
        'name': TextEditingController(),
      });
    });
  }

  void _removeSubTask(int index) {
    setState(() {
      (_subTasks[index]['name'] as TextEditingController?)?.dispose();
      _subTasks.removeAt(index);
    });
  }

  void _onReorderSubtasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;

      final item = _subTasks.removeAt(oldIndex);
      _subTasks.insert(newIndex, item);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (var subTask in _subTasks) {
      (subTask['name'] as TextEditingController?)?.dispose();
    }
    super.dispose();
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
            title: Text(
              widget.templateId != null ? context.tr('pages.edit_template') : context.tr('pages.new_template'),
              style: const TextStyle(color: Colors.white),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveTemplate,
              ),
            ],
          ),
          drawer: AppDrawer(),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LocalizedText('templates.template_name'),
                                const SizedBox(height: 8),
                                TaskNameField(controller: _nameController),
                                const SizedBox(height: 16),
                                LocalizedText('templates.template_description'),
                                const SizedBox(height: 8),
                                TaskDescriptionField(controller: _descriptionController),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    LocalizedText('subtasks.subtasks'),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        _addSubTask();
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Column(
                                  key: ValueKey(_subTasks.length),
                                  children: [
                                    if (_subTasks.isEmpty)
                                      Center(
                                        child: Text(context.tr('subtasks.no_subtasks')),
                                      )
                                    else
                                      ReorderableListView.builder(
                                        key: const PageStorageKey('edit_template_subtasks_list'),
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _subTasks.length,
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
                                          final subTask = _subTasks[index];
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
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
                                              child: const Icon(Icons.delete, color: Colors.white),
                                            ),
                                            secondaryBackground: Container(
                                              color: Colors.red,
                                              alignment: Alignment.centerRight,
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ));
  }
}
