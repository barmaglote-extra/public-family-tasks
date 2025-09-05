import 'package:tasks/models/collection_fields.dart';

class ToDoCollection {
  final int id;
  final String name;
  final String? description;

  ToDoCollection({required this.id, required this.name, required this.description});

  factory ToDoCollection.fromMap(Map<String, dynamic> map) {
    return ToDoCollection(
      id: map[CollectionFields.id],
      name: map[CollectionFields.name],
      description: map[CollectionFields.description],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      CollectionFields.id: id,
      CollectionFields.name: name,
      CollectionFields.description: description,
    };
  }
}
