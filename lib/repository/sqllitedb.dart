import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SQLLiteDB {
  static final String dbFileName = 'tasks.db';
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  /// Reset the database instance (used for backup restoration)
  void resetDatabase() {
    _database = null;
  }

  /// Get the database file path
  Future<String> getDatabasePath() async {
    return join(await getDatabasesPath(), dbFileName);
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    var path = join(await getDatabasesPath(), dbFileName);

    if (kDebugMode) {
      print("Full path: $path");
    }

    return await openDatabase(
      path,
      version: 12,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute(
      '''
      CREATE TABLE collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT
      )
      ''',
    );

    await db.execute(
      '''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection_id INTEGER,
        is_completed INTEGER DEFAULT 0,
        description TEXT,
        urgency INTERGER DEFAULT 0,
        due_date INTEGER,
        name TEXT,
        task_type TEXT NOT NULL DEFAULT 'regular',
        recurrence_rule TEXT,
        FOREIGN KEY (collection_id) REFERENCES collections (id) ON DELETE CASCADE
      )
      ''',
    );

    await db.execute('''
      CREATE TABLE task_completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        completion_date TEXT NOT NULL,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_task_completion ON task_completions (task_id, completion_date)
    ''');

    // Create subtasks table in the initial creation as well
    await db.execute('''
      CREATE TABLE subtasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER,
        is_completed INTEGER DEFAULT 0,
        description TEXT,
        urgency INTERGER DEFAULT 0,
        due_date INTEGER,
        name TEXT,
        order_index INTEGER DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    // Create templates table
    await db.execute('''
      CREATE TABLE templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create template_subtasks table for template subtasks
    await db.execute('''
      CREATE TABLE template_subtasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        urgency INTEGER DEFAULT 0,
        order_index INTEGER DEFAULT 0,
        FOREIGN KEY (template_id) REFERENCES templates (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE collections ADD COLUMN description TEXT');
      } catch (e) {
        // Column may already exist, ignore error
        if (kDebugMode) {
          print('description column already exists in collections table, skipping...');
        }
      }
    }

    if (oldVersion < 9) {
      try {
        await db.execute('''
          CREATE TABLE subtasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER,
            is_completed INTEGER DEFAULT 0,
            description TEXT,
            urgency INTERGER DEFAULT 0,
            due_date INTEGER,
            name TEXT,
            order_index INTEGER DEFAULT 0,
            FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        // Table might already exist, ignore error
        if (kDebugMode) {
          print('subtasks table already exists, skipping creation: $e');
        }
      }
    }

    // Check if order_index column exists before adding it
    if (oldVersion < 10) {
      // Only add order_index if the table was created before version 9
      // (version 9 already includes order_index)
      if (oldVersion < 9) {
        // Table was created in version 9 with order_index, no need to add
      } else {
        try {
          await db.execute('ALTER TABLE subtasks ADD COLUMN order_index INTEGER DEFAULT 0');
        } catch (e) {
          // Column may already exist, ignore error
          if (kDebugMode) {
            print('order_index column already exists, skipping...');
          }
        }
      }

      // Update order_index values for existing records
      try {
        await db.execute('''
          UPDATE subtasks
          SET order_index = (
            SELECT COUNT(*)
            FROM subtasks s2
            WHERE s2.task_id = subtasks.task_id
            AND s2.id < subtasks.id
          )
          WHERE order_index IS NULL OR order_index = 0
        ''');
      } catch (e) {
        if (kDebugMode) {
          print('Failed to update order_index values: $e');
        }
      }
    }

    if (oldVersion < 11) {
      // Ensure order_index column exists and update values
      try {
        // Check if column exists by trying to query it
        await db.rawQuery('SELECT order_index FROM subtasks LIMIT 1');
      } catch (e) {
        // Column doesn't exist, add it
        try {
          await db.execute('ALTER TABLE subtasks ADD COLUMN order_index INTEGER DEFAULT 0');
        } catch (addError) {
          if (kDebugMode) {
            print('Failed to add order_index column: $addError');
          }
        }
      }

      // Update order_index values
      try {
        await db.execute('''
          UPDATE subtasks
          SET order_index = (
            SELECT COUNT(*)
            FROM subtasks s2
            WHERE s2.task_id = subtasks.task_id
            AND s2.id < subtasks.id
          )
          WHERE order_index IS NULL OR order_index = 0
        ''');
      } catch (e) {
        if (kDebugMode) {
          print('Failed to update order_index values in version 11 upgrade: $e');
        }
      }
    }

    // Add templates tables for version 12
    if (oldVersion < 12) {
      try {
        await db.execute('''
          CREATE TABLE templates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
      } catch (e) {
        if (kDebugMode) {
          print('templates table already exists, skipping creation: $e');
        }
      }

      try {
        await db.execute('''
          CREATE TABLE template_subtasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            template_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            urgency INTEGER DEFAULT 0,
            order_index INTEGER DEFAULT 0,
            FOREIGN KEY (template_id) REFERENCES templates (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        if (kDebugMode) {
          print('template_subtasks table already exists, skipping creation: $e');
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> getItems(String collection) async {
    Database db = await database;
    return await db.query(collection, orderBy: 'id DESC');
  }

  Future<int> addItem(String collection, Map<String, dynamic> data) async {
    final db = await database;

    try {
      final id = await db.insert(collection, data);
      return id;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getItemByField(String collection, String field, dynamic value) async {
    final db = await database;

    final List<Map<String, dynamic>> result = await db.query(
      collection,
      where: '$field = ?',
      whereArgs: [value],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getItemsByFilter(String collection,
      {String? where, List<dynamic>? whereArgs, String? orderBy = 'id', int limit = 0}) async {
    final db = await database;

    // If limit is 0, don't apply limit (return all results)
    if (limit == 0) {
      return await db.query(
        collection,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
      );
    } else {
      return await db.query(
        collection,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
      );
    }
  }

  Future<List<Map<String, dynamic>>?> getItemsByFields(String collection, Map<String, dynamic> conditions) async {
    final db = await database;

    if (conditions.isEmpty) return null;

    final whereClause = conditions.keys.map((key) => '$key = ?').join(' AND ');
    final whereArgs = conditions.values.toList();

    final orderBy = collection == 'subtasks' ? 'order_index, id' : 'id';

    final List<Map<String, dynamic>> result = await db.query(
      collection,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: 1000,
    );

    return result.isNotEmpty ? result : null;
  }

  Future<void> updateItemById(String collection, int id, Map<String, dynamic> data) async {
    final db = await database;

    await db.update(
      collection,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItemById(String collection, int id) async {
    final db = await database;
    await db.delete(
      collection,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countRecords(String tableName, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    final query = 'SELECT COUNT(*) FROM $tableName ${where != null ? 'WHERE $where' : ''}';
    final result = await db.rawQuery(query, whereArgs ?? []);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteRecords(String table, String whereClause, List<dynamic> whereArgs) async {
    final db = await database;
    await db.delete(table, where: whereClause, whereArgs: whereArgs);
  }

  Future<void> deleteItems(Transaction txn, String table, String where, List<dynamic> whereArgs) async {
    await txn.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> executeInTransaction(List<Future<void> Function(Transaction)> operations) async {
    final db = await database;

    await db.transaction((txn) async {
      for (var operation in operations) {
        await operation(txn);
      }
    });
  }

  Future<Map<String, int>> getRegularTaskDueDateStats() async {
    final db = await database;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59).millisecondsSinceEpoch;

    final overdueCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM tasks WHERE task_type = ? AND due_date IS NOT NULL AND due_date < ?',
          ['regular', todayStart],
        )) ??
        0;

    final todayCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM tasks WHERE task_type = ? AND due_date >= ? AND due_date <= ?',
          ['regular', todayStart, todayEnd],
        )) ??
        0;

    final futureCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM tasks WHERE task_type = ? AND due_date IS NOT NULL AND due_date > ?',
          ['regular', todayEnd],
        )) ??
        0;

    final noDueDateCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM tasks WHERE task_type = ? AND due_date IS NULL',
          ['regular'],
        )) ??
        0;

    return {
      'overdue': overdueCount,
      'today': todayCount,
      'future': futureCount,
      'noDueDate': noDueDateCount,
    };
  }
}
