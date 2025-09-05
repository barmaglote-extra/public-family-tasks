import 'package:flutter/foundation.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/collection_fields.dart';
import 'package:tasks/repository/sqllitedb.dart';
import 'package:tasks/models/todo_collection.dart';

class CollectionsService {
  static final String _entity = 'collections';
  late final SQLLiteDB _db;

  CollectionsService() {
    _db = locator<SQLLiteDB>();
  }

  Future<List<ToDoCollection>> getItems() async {
    final List<Map<String, dynamic>> result = await _db.getItems(_entity);
    return result.map((map) => ToDoCollection.fromMap(map)).toList();
  }

  Future<void> addItem(String name, String description) async {
    await _db.addItem(_entity, {CollectionFields.name: name, CollectionFields.description: description});
    if (kDebugMode) {
      print('Collection is added: $name');
    }
  }

  Future<void> updateItemById(int id, Map<String, dynamic> data) async {
    await _db.updateItemById(_entity, id, data);
  }

  Future<ToDoCollection?> getItemById(int id) async {
    var item = await _db.getItemByField(_entity, 'id', id);
    return item != null ? ToDoCollection.fromMap(item) : null;
  }

  Future<void> deleteCollection(int collectionId) async {
    final operations = [
      (txn) => _db.deleteItems(txn, 'collections', 'id = ?', [collectionId]),
      (txn) => _db.deleteItems(txn, 'tasks', 'collection_id = ?', [collectionId]),
    ];
    await _db.executeInTransaction(operations);
  }
}
