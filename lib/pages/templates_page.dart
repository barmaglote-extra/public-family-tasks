import 'package:flutter/material.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/mixins/back_button_mixin.dart';
import 'package:tasks/models/template.dart';
import 'package:tasks/pages/template_page.dart';
import 'package:tasks/services/templates_service.dart';
import 'package:tasks/services/update_provider.dart';
import 'package:tasks/widgets/localized_text.dart';

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> with BackButtonMixin {
  final _templatesService = locator<TemplatesService>();
  final _updateProvider = locator<UpdateProvider>();
  List<Template> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final templates = await _templatesService.getAllTemplates();
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load templates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTemplate(int templateId, String templateName) async {
    try {
      await _templatesService.deleteTemplate(templateId);
      await _loadTemplates();
      _updateProvider.notifyListeners();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('templates.template_deleted').replaceAll('{templateName}', templateName)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToTemplatePage(int templateId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplatePage(templateId: templateId),
      ),
    ).then((_) => _loadTemplates());
  }

  void _useTemplate(int templateId) {
    // Navigate to new task page with template data
    Navigator.pushNamed(context, 'tasks/new', arguments: {'templateId': templateId});
  }

  void _editTemplate(int templateId) {
    // Navigate to edit template page
    Navigator.pushNamed(context, 'templates/edit', arguments: {'templateId': templateId});
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
          title: const Text('Templates', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        drawer: AppDrawer(),
        body: Column(
          children: [
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_templates.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      LocalizedText('templates.no_templates'),
                      const SizedBox(height: 16),
                      LocalizedText('templates.create_first_template'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: Dismissible(
                        key: Key(template.id.toString()),
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
                                title: LocalizedText('templates.delete_template'),
                                content: LocalizedText('templates.delete_template_confirmation'),
                                actions: <Widget>[
                                  TextButton(
                                    child: LocalizedText('actions.cancel'),
                                    onPressed: () => Navigator.of(context).pop(false),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: LocalizedText('actions.delete'),
                                    onPressed: () => Navigator.of(context).pop(true),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) async {
                          await _deleteTemplate(template.id, template.name);
                        },
                        child: Card(
                          color: Colors.white,
                          child: InkWell(
                            onTap: () => _navigateToTemplatePage(template.id),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          template.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (template.description != null && template.description!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      template.description!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _useTemplate(template.id),
                                        icon: const Icon(Icons.add_task, size: 16),
                                        label: LocalizedText('actions.use_template'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => _editTemplate(template.id),
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: LocalizedText('actions.edit'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
