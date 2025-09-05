# Database Backup Feature

## Overview
The Settings page now includes a comprehensive database backup and restore functionality that allows users to create and manage backups of their task database.

## Features

### 1. Create Backup
- **Button**: "Create Backup" / "Update Backup"
- **Icon**: Save icon
- **Functionality**: Creates a copy of the current database
- **Location**: Stored in the application's documents directory as `tasks_backup.db`
- **Timestamp**: Automatically saves the backup creation date and time
- **Overwrite Protection**: Shows confirmation dialog when overwriting existing backup

### 2. Restore from Backup
- **Button**: "Restore"
- **Icon**: Restore icon
- **Functionality**: Atomically restores database from the backup file
- **State Management**: Button is disabled when no backup exists or backup is invalid
- **Confirmation**: Shows warning dialog before restoring
- **Safety**: Warns user that current data will be lost
- **Atomic Operation**: If restore fails, original database is automatically restored
- **Validation**: Backup integrity is checked before restoration attempt
- **Rollback**: Original database is preserved and restored on any error

### 3. Backup Information Display
- **Status Indicator**: Shows whether backup exists and is valid
- **Creation Date**: Displays when the backup was created (formatted as "MMM dd, yyyy at HH:mm")
- **File Size**: Shows backup file size in appropriate units (B, KB, MB)
- **Validation Status**: Shows if backup is valid, invalid, or being checked
- **Visual Feedback**:
  - Green indicator: "Backup Available (Valid)"
  - Red indicator: "Backup Available (Invalid)" with corruption warning
  - Orange indicator: "No backup available"

### 4. Backup Validation
- **Automatic Check**: Validates backup integrity when loading backup info
- **Database Structure**: Verifies all required tables exist (collections, tasks, subtasks, task_completions)
- **SQL Validation**: Tests if backup file can be opened and queried
- **Pre-Restore Check**: Validates backup before attempting restoration
- **Error Prevention**: Prevents restoration of corrupted backups

## Technical Implementation

### Backend Services
- **BackupService**: Handles all backup operations
  - `createBackup()`: Creates database backup
  - `restoreFromBackup()`: Atomically restores from backup with rollback
  - `hasBackup()`: Checks if backup exists
  - `getBackupDate()`: Gets backup creation date
  - `getBackupSize()`: Gets backup file size
  - `deleteBackup()`: Removes backup file
  - `validateBackup()`: Validates backup file integrity

### Database Operations
- **SQLiteDB**: Enhanced with `resetDatabase()` method
- **Backup Location**: Uses `path_provider` to access documents directory
- **Persistence**: Uses `shared_preferences` to store backup metadata

### UI Components
- **Settings Page**: Enhanced with backup section
- **Confirmation Dialogs**: For destructive operations
- **Loading States**: Shows progress during operations
- **Snackbar Notifications**: Success/error feedback
- **Visual Status**: Color-coded backup status indicators

## Dependencies Added
- `path_provider: ^2.0.0` - For accessing application directories

## Files Modified
- `/lib/pages/settings_page.dart` - Added backup UI section
- `/lib/repository/sqllitedb.dart` - Added `resetDatabase()` method
- `/lib/main.dart` - Registered BackupService in DI
- `/pubspec.yaml` - Added path_provider dependency

## Files Created
- `/lib/services/backup_service.dart` - Backup functionality service
- `/BACKUP_FEATURES.md` - This documentation

## User Experience

### Creating a Backup
1. Navigate to Settings page
2. Locate "Database Backup" section
3. Click "Create Backup" button
4. If backup exists, confirm overwrite
5. Success message appears
6. Backup info updates with new timestamp

### Restoring a Backup
1. Navigate to Settings page
2. Ensure backup exists and is valid (button will be enabled)
3. Click "Restore" button
4. Confirm destructive action in dialog
5. Backup is validated before restoration
6. Original database is temporarily preserved
7. If restoration succeeds: Success message appears
8. If restoration fails: Original database is automatically restored
9. User receives feedback about rollback

### Error Handling
- **Backup Validation**: Invalid backups are detected and marked
- **Atomic Operations**: Failed restores automatically rollback to original state
- **Network/permission issues**: Show error messages with rollback confirmation
- **Corrupted backups**: Prevented from being used for restoration
- **Database connection issues**: Managed automatically with rollback
- **File operations**: All operations are atomic with proper cleanup

## Security Considerations
- Backups are stored locally only
- No sensitive data exposure risk
- File operations use Flutter's secure path providers
- Confirmation dialogs prevent accidental data loss

## Future Enhancements
- Multiple backup slots
- Automatic backup scheduling
- Cloud backup integration
- Backup encryption
- Export/import functionality