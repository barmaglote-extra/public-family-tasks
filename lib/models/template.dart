import 'package:tasks/models/template_data.dart';

class Template {
  final int id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final List<TemplateSubtask> subtasks;

  Template({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.subtasks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  TemplateData toTemplateData() {
    return TemplateData(
      name: name,
      description: description,
      createdAt: createdAt.millisecondsSinceEpoch,
    );
  }

  factory Template.fromMap(Map<String, dynamic> map, List<TemplateSubtask> subtasks) {
    return Template(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      subtasks: subtasks,
    );
  }
}

class TemplateSubtask {
  final int id;
  final int templateId;
  final String name;
  final String? description;
  final int? urgency;
  final int orderIndex;

  TemplateSubtask({
    required this.id,
    required this.templateId,
    required this.name,
    required this.description,
    required this.urgency,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'template_id': templateId,
      'name': name,
      'description': description,
      'urgency': urgency,
      'order_index': orderIndex,
    };
  }

  factory TemplateSubtask.fromMap(Map<String, dynamic> map) {
    return TemplateSubtask(
      id: map['id'],
      templateId: map['template_id'],
      name: map['name'],
      description: map['description'],
      urgency: map['urgency'],
      orderIndex: map['order_index'] ?? 0,
    );
  }
}