import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tasks/main.dart';
import 'package:tasks/repository/sqllitedb.dart';

/// Utility service for migrating data from old database file to new one
class DatabaseMigrationService {
  final _sqliteDb = locator<SQLLiteDB>();
  static const String _migrationCompletedKey = 'migration_completed_test_to_tasks';
  static const String _migrationPromptShownKey = 'migration_prompt_shown_test_to_tasks';

  /// Check if migration has been completed
  Future<bool> isMigrationCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_migrationCompletedKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark migration as completed
  Future<void> markMigrationCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationCompletedKey, true);
      await prefs.setBool(_migrationPromptShownKey, true);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to mark migration completed: $e');
      }
    }
  }

  /// Check if migration prompt has been shown
  Future<bool> isMigrationPromptShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_migrationPromptShownKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark migration prompt as shown
  Future<void> markMigrationPromptShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationPromptShownKey, true);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to mark migration prompt shown: $e');
      }
    }
  }

  /// Migrate data from test.db to tasks.db
  Future<bool> migrateFromTestDb() async {
    try {
      // Get database paths
      final databasesPath = await getDatabasesPath();
      final oldDbPath = join(databasesPath, 'test.db');
      final newDbPath = await _sqliteDb.getDatabasePath();

      final oldDbFile = File(oldDbPath);
      final newDbFile = File(newDbPath);

      // Check if old database exists
      if (!await oldDbFile.exists()) {
        if (kDebugMode) {
          print('No old database file found at $oldDbPath');
        }
        return false;
      }

      final oldSize = await oldDbFile.length();
      if (kDebugMode) {
        print('Found old database file. Size: $oldSize bytes');
      }

      // If new database doesn't exist or is empty, copy the old one
      if (!await newDbFile.exists()) {
        if (kDebugMode) {
          print('New database does not exist. Copying old database...');
        }
        await oldDbFile.copy(newDbPath);
        if (kDebugMode) {
          print('Database copied successfully');
        }
        return true;
      } else {
        // Check if new database is smaller (might be empty)
        final newSize = await newDbFile.length();

        if (kDebugMode) {
          print('Old DB size: $oldSize bytes, New DB size: $newSize bytes');
        }

        // If new database is significantly smaller, it's likely empty
        if (newSize < (oldSize * 0.5)) {
          if (kDebugMode) {
            print('New database appears to be smaller/empty. Migration recommended.');
          }
          return false; // Let user decide
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Migration check failed: $e');
      }
      return false;
    }
  }

  /// Force copy old database to new location (with backup)
  Future<bool> forceMigrateFromTestDb() async {
    try {
      final databasesPath = await getDatabasesPath();
      final oldDbPath = join(databasesPath, 'test.db');
      final newDbPath = await _sqliteDb.getDatabasePath();

      final oldDbFile = File(oldDbPath);
      final newDbFile = File(newDbPath);

      if (!await oldDbFile.exists()) {
        throw Exception('Old database file not found');
      }

      // Create backup of current database if it exists
      if (await newDbFile.exists()) {
        final backupPath = join(databasesPath, 'tasks_backup_before_migration.db');
        await newDbFile.copy(backupPath);
        if (kDebugMode) {
          print('Created backup at: $backupPath');
        }
      }

      // Close current database connection
      _sqliteDb.resetDatabase();

      // Copy old database to new location
      await oldDbFile.copy(newDbPath);
      if (kDebugMode) {
        print('Successfully migrated from test.db to tasks.db');
      }

      // Mark migration as completed
      await markMigrationCompleted();

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Force migration failed: $e');
      }
      return false;
    }
  }

  /// Check if old test.db exists and has data
  Future<Map<String, dynamic>> checkOldDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final oldDbPath = join(databasesPath, 'test.db');
      final oldDbFile = File(oldDbPath);

      if (kDebugMode) {
        print('Checking old database at: $oldDbPath');
      }

      if (!await oldDbFile.exists()) {
        if (kDebugMode) {
          print('Old database file does not exist');
        }
        return {'exists': false};
      }

      final fileSize = await oldDbFile.length();
      if (kDebugMode) {
        print('Old database file exists. Size: $fileSize bytes');
      }

      // Try to open and count records
      final db = await openDatabase(oldDbPath, readOnly: true);

      final tablesResult = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");

      final tables = tablesResult.map((row) => row['name'] as String).toList();
      if (kDebugMode) {
        print('Tables found: $tables');
      }

      final counts = <String, int>{};
      for (final table in tables) {
        if (!table.startsWith('sqlite_')) {
          try {
            final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
            counts[table] = countResult.first['count'] as int;
            if (kDebugMode) {
              print('Table $table has ${counts[table]} records');
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error counting records in table $table: $e');
            }
            counts[table] = 0;
          }
        }
      }

      await db.close();

      final totalRecords = counts.values.fold(0, (sum, count) => sum + count);
      if (kDebugMode) {
        print('Total records in old database: $totalRecords');
      }

      return {
        'exists': true,
        'size': fileSize,
        'tables': tables,
        'counts': counts,
        'totalRecords': totalRecords,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error checking old database: $e');
      }
      return {'exists': false, 'error': e.toString()};
    }
  }

  /// Check if migration should be offered
  /// Returns true only if:
  /// 1. Migration hasn't been completed
  /// 2. Old database exists with data
  /// 3. Migration prompt hasn't been dismissed
  Future<bool> shouldOfferMigration() async {
    try {
      // If migration is already completed, don't offer again
      if (await isMigrationCompleted()) {
        return false;
      }

      // Check if old database has meaningful data
      final oldDbInfo = await checkOldDatabase();
      if (!oldDbInfo['exists'] || (oldDbInfo['totalRecords'] ?? 0) == 0) {
        return false;
      }

      // If prompt was already shown and dismissed, don't show again
      if (await isMigrationPromptShown()) {
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking if migration should be offered: $e');
      }
      return false;
    }
  }
}
