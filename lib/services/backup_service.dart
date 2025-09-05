import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tasks/main.dart';
import 'package:tasks/repository/sqllitedb.dart';

/// Service for handling database backup and restore operations
class BackupService {
  static const String _backupFileName = 'tasks_backup.db';
  static const String _backupDateKey = 'backup_date';

  final _sqliteDb = locator<SQLLiteDB>();

  /// Create a backup of the current database
  /// Returns true if backup was successful
  Future<bool> createBackup() async {
    try {
      // Get the current database path from SQLLiteDB
      final dbPath = await _sqliteDb.getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('Database file not found');
      }

      // Get the application documents directory for backup storage
      final appDir = await getApplicationDocumentsDirectory();
      final backupPath = join(appDir.path, _backupFileName);

      // Copy the database file to backup location
      await dbFile.copy(backupPath);

      // Save the backup timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backupDateKey, DateTime.now().toIso8601String());

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Backup failed: $e');
      }
      return false;
    }
  }

  /// Restore database from backup
  /// Returns true if restore was successful
  /// If any error occurs, the original database is restored
  Future<bool> restoreFromBackup() async {
    Database? currentDatabase;
    String? tempBackupPath;

    try {
      // Check if backup exists
      if (!await hasBackup()) {
        throw Exception('No backup file found');
      }

      // Validate backup integrity first
      if (!await validateBackup()) {
        throw Exception('Backup file is corrupted or invalid');
      }

      // Get backup file path
      final appDir = await getApplicationDocumentsDirectory();
      final backupPath = join(appDir.path, _backupFileName);
      final backupFile = File(backupPath);

      // Get current database path from SQLLiteDB
      final dbPath = await _sqliteDb.getDatabasePath();
      final currentDbFile = File(dbPath);

      // Create a temporary backup of the current database for rollback
      tempBackupPath = join(appDir.path, 'temp_current_backup.db');
      if (await currentDbFile.exists()) {
        await currentDbFile.copy(tempBackupPath);
      }

      // Close current database connection
      currentDatabase = await _sqliteDb.database;
      await currentDatabase.close();

      // Attempt to copy backup file to database location
      await backupFile.copy(dbPath);

      // Test if the restored database is valid by trying to open it
      // This will throw an exception if the backup file is corrupted
      final testDb = await openDatabase(dbPath);

      // Perform a simple query to verify database integrity
      await testDb.rawQuery('SELECT COUNT(*) FROM sqlite_master');
      await testDb.close();

      // Reset database instance to force reconnection
      _sqliteDb.resetDatabase();

      // Test the connection with our database class
      final newDb = await _sqliteDb.database;
      await newDb.rawQuery('SELECT COUNT(*) FROM sqlite_master');

      // If we reach here, restoration was successful
      // Clean up temporary backup
      final tempFile = File(tempBackupPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Restore failed: $e');
      }

      // Rollback: restore the original database
      try {
        if (tempBackupPath != null) {
          final tempFile = File(tempBackupPath);
          if (await tempFile.exists()) {
            final dbPath = await _sqliteDb.getDatabasePath();
            await tempFile.copy(dbPath);

            // Reset database instance
            _sqliteDb.resetDatabase();

            // Verify rollback worked
            final rolledBackDb = await _sqliteDb.database;
            await rolledBackDb.rawQuery('SELECT COUNT(*) FROM sqlite_master');

            if (kDebugMode) {
              print('Database successfully rolled back to original state');
            }

            // Clean up temporary file
            await tempFile.delete();
          }
        }
      } catch (rollbackError) {
        if (kDebugMode) {
          print('Critical error: Failed to rollback database: $rollbackError');
        }
        // This is a critical error - the database might be in an inconsistent state
      }

      return false;
    }
  }

  /// Check if a backup exists
  Future<bool> hasBackup() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupPath = join(appDir.path, _backupFileName);
      final backupFile = File(backupPath);
      return await backupFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get the backup creation date
  /// Returns null if no backup exists
  Future<DateTime?> getBackupDate() async {
    try {
      if (!await hasBackup()) return null;

      final prefs = await SharedPreferences.getInstance();
      final dateString = prefs.getString(_backupDateKey);

      if (dateString == null) return null;

      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Get backup file size in bytes
  Future<int?> getBackupSize() async {
    try {
      if (!await hasBackup()) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final backupPath = join(appDir.path, _backupFileName);
      final backupFile = File(backupPath);

      return await backupFile.length();
    } catch (e) {
      return null;
    }
  }

  /// Delete existing backup
  Future<bool> deleteBackup() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupPath = join(appDir.path, _backupFileName);
      final backupFile = File(backupPath);

      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      // Remove backup date from preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_backupDateKey);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Delete backup failed: $e');
      }
      return false;
    }
  }

  /// Get detailed information about backup contents
  /// Returns a map with table names and record counts
  Future<Map<String, dynamic>?> getBackupInfo() async {
    try {
      if (!await hasBackup()) {
        return null;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final backupPath = join(appDir.path, _backupFileName);
      final backupFile = File(backupPath);

      // Get file size
      final fileSize = await backupFile.length();

      // Try to open the backup file as a database
      final testDb = await openDatabase(
        backupPath,
        readOnly: true,
      );

      // Get all tables
      final tablesResult = await testDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");

      final tables = tablesResult.map((row) => row['name'] as String).toList();
      final counts = <String, int>{};

      // Count records in each table
      for (final table in tables) {
        if (!table.startsWith('sqlite_')) {
          try {
            final countResult = await testDb.rawQuery('SELECT COUNT(*) as count FROM $table');
            counts[table] = countResult.first['count'] as int;
          } catch (e) {
            if (kDebugMode) {
              print('Error counting records in table $table: $e');
            }
            counts[table] = 0;
          }
        }
      }

      await testDb.close();

      final totalRecords = counts.values.fold(0, (sum, count) => sum + count);

      return {
        'fileSize': fileSize,
        'tables': tables,
        'counts': counts,
        'totalRecords': totalRecords,
        'isValid': true,
      };
    } catch (e) {
      return {
        'fileSize': 0,
        'tables': [],
        'counts': {},
        'totalRecords': 0,
        'isValid': false,
        'error': e.toString(),
      };
    }
  }

  /// Validate backup file integrity
  /// Returns true if backup file is valid and can be restored
  Future<bool> validateBackup() async {
    try {
      if (!await hasBackup()) {
        return false;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final backupPath = join(appDir.path, _backupFileName);

      // Try to open the backup file as a database
      final testDb = await openDatabase(
        backupPath,
        readOnly: true,
      );

      // Perform basic validation queries
      await testDb.rawQuery('SELECT COUNT(*) FROM sqlite_master');

      // Check if required tables exist
      final tables = await testDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");

      final requiredTables = ['collections', 'tasks', 'subtasks', 'task_completions'];
      final existingTables = tables.map((t) => t['name'] as String).toSet();

      for (final table in requiredTables) {
        if (!existingTables.contains(table)) {
          if (kDebugMode) {
            print('Backup validation failed: Missing table $table');
          }
          await testDb.close();
          return false;
        }
      }

      await testDb.close();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Backup validation failed: $e');
      }
      return false;
    }
  }
}
