import 'package:tasks/models/template.dart';
import 'package:tasks/repository/sqllitedb.dart';

class TemplatesService {
  final SQLLiteDB _db = SQLLiteDB();

  Future<List<Template>> getAllTemplates() async {
    final templatesData = await _db.getItems('templates');
    final List<Template> templates = [];

    for (var templateData in templatesData) {
      final subtasksData = await _db.getItemsByFilter(
        'template_subtasks',
        where: 'template_id = ?',
        whereArgs: [templateData['id']],
        orderBy: 'order_index, id',
      );

      final subtasks = subtasksData.map((data) => TemplateSubtask.fromMap(data)).toList();
      templates.add(Template.fromMap(templateData, subtasks));
    }

    return templates;
  }

  Future<Template?> getTemplateById(int id) async {
    final templateData = await _db.getItemByField('templates', 'id', id);
    if (templateData == null) return null;

    final subtasksData = await _db.getItemsByFilter(
      'template_subtasks',
      where: 'template_id = ?',
      whereArgs: [id],
      orderBy: 'order_index, id',
    );

    final subtasks = subtasksData.map((data) => TemplateSubtask.fromMap(data)).toList();
    return Template.fromMap(templateData, subtasks);
  }

  Future<int> createTemplate(Map<String, dynamic> templateData) async {
    final id = await _db.addItem('templates', templateData);
    return id;
  }

  Future<void> updateTemplate(int id, Map<String, dynamic> templateData) async {
    await _db.updateItemById('templates', id, templateData);
  }

  Future<void> deleteTemplate(int id) async {
    await _db.deleteItemById('templates', id);
  }

  Future<int> createTemplateSubtask(Map<String, dynamic> subtaskData) async {
    final id = await _db.addItem('template_subtasks', subtaskData);
    return id;
  }

  Future<void> updateTemplateSubtask(int id, Map<String, dynamic> data) async {
    await _db.updateItemById('template_subtasks', id, data);
  }

  Future<void> deleteTemplateSubtask(int id) async {
    await _db.deleteItemById('template_subtasks', id);
  }

  Future<void> deleteTemplateSubtasks(int templateId) async {
    await _db.deleteRecords('template_subtasks', 'template_id = ?', [templateId]);
  }
}
