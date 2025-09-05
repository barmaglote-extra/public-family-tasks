# Database Path Consistency Fix

## Issue Fixed
The backup service was using hardcoded database filenames instead of referencing the actual database filename from the `SQLLiteDB` class.

## Changes Made

### 1. SQLLiteDB Class Enhancement
- **Fixed Inconsistency**: Changed `_initDatabase()` to use `dbFileName` instead of hardcoded `'test.db'`
- **Added Method**: `getDatabasePath()` - Returns the full database file path
- **Consistency**: Now all database operations use the same filename from `SQLLiteDB.dbFileName`

### 2. BackupService Updates
- **Database Path**: Now uses `_sqliteDb.getDatabasePath()` instead of hardcoded paths
- **Consistency**: Ensures backup operations always use the correct database file
- **Reliability**: Eliminates risk of backing up wrong database file

## Code Changes

### SQLLiteDB.dart
```dart
// Fixed filename consistency
var path = join(await getDatabasesPath(), dbFileName); // Was: 'test.db'

// Added new method
Future<String> getDatabasePath() async {
  return join(await getDatabasesPath(), dbFileName);
}
```

### BackupService.dart
```dart
// Updated to use SQLLiteDB path
final dbPath = await _sqliteDb.getDatabasePath(); // Was: hardcoded path
```

## Benefits
1. **Consistency**: All database operations use the same filename
2. **Maintainability**: Single source of truth for database filename
3. **Reliability**: No risk of backup/restore using wrong database
4. **Future-proof**: Easy to change database filename in one place

## Database Filename
- **Current**: `tasks.db` (defined in `SQLLiteDB.dbFileName`)
- **Location**: Application's databases directory
- **Backup**: Stored as `tasks_backup.db` in documents directory