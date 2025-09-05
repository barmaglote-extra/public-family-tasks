import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/template.dart';
import 'package:tasks/services/templates_service.dart';
import 'package:tasks/widgets/localized_text.dart';

class TemplatePage extends StatefulWidget {
  final int templateId;

  const TemplatePage({super.key, required this.templateId});

  @override
  State<TemplatePage> createState() => _TemplatePageState();
}

class _TemplatePageState extends State<TemplatePage> {
  final _templatesService = locator<TemplatesService>();
  Template? _template;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final template = await _templatesService.getTemplateById(widget.templateId);
      setState(() {
        _template = template;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Template', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.pushNamed(
                context,
                'templates/edit',
                arguments: {'templateId': widget.templateId},
              );

              // If the template was updated, reload the data
              if (result == true) {
                _loadTemplate();
              }
            },
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _template == null
              ? const Center(
                  child: Text('Template not found'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Template Details Card
                      Card(
                        color: Colors.white,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border(
                              left: BorderSide(
                                color: Colors.blue,
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
                                    LocalizedText('pages.template_details'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                LocalizedText('tasks.task_name'),
                                const SizedBox(height: 4),
                                Text(
                                  _template!.name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 10),
                                LocalizedText('tasks.task_description'),
                                const SizedBox(height: 4),
                                Text(
                                  _template!.description ?? 'No description',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 10),
                                LocalizedText('common.created_at'),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd.MM.yyyy HH:mm').format(_template!.createdAt),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Subtasks Card
                      if (_template!.subtasks.isNotEmpty) ...[
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
                                    LocalizedText('task_details.subtasks'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Column(
                                  children: _template!.subtasks.map((subtask) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(12.0),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8.0),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Row(
                                          children: [
                                            if (subtask.urgency != null && subtask.urgency! > 0) ...[
                                              Text(
                                                '!',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: subtask.urgency == 2 ? Colors.red : Colors.orange,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Expanded(
                                              child: Text(
                                                subtask.name,
                                                style: const TextStyle(fontSize: 14),
                                              ),
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
                  ),
                ),
    );
  }
}
