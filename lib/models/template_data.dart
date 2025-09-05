class TemplateData {
  final String name;
  final String? description;
  final int createdAt;

  TemplateData({
    required this.name,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'created_at': createdAt,
    };
  }

  factory TemplateData.fromMap(Map<String, dynamic> map) {
    return TemplateData(
      name: map['name'],
      description: map['description'],
      createdAt: map['created_at'],
    );
  }
}

class TemplateSubtaskData {
  final int templateId;
  final String name;
  final String? description;
  final int? urgency;
  final int orderIndex;

  TemplateSubtaskData({
    required this.templateId,
    required this.name,
    required this.description,
    required this.urgency,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'template_id': templateId,
      'name': name,
      'description': description,
      'urgency': urgency,
      'order_index': orderIndex,
    };
  }

  factory TemplateSubtaskData.fromMap(Map<String, dynamic> map) {
    return TemplateSubtaskData(
      templateId: map['template_id'],
      name: map['name'],
      description: map['description'],
      urgency: map['urgency'],
      orderIndex: map['order_index'] ?? 0,
    );
  }
}