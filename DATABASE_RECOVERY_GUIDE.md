# Database Recovery Guide

## The Problem
After fixing the database filename inconsistency from `test.db` to `tasks.db`, your existing tasks are stored in the old `test.db` file while the app now looks for `tasks.db`.

## Solution Options

### Option 1: Automatic Migration (Recommended)
The app now includes automatic migration functionality:

1. **Launch the app**
2. **Go to Settings** (if migration dialog doesn't appear automatically)
3. **Look for migration dialog** that shows your old data counts
4. **Click "Migrate Data"** to transfer your tasks

### Option 2: Manual File Copy (If automatic fails)
If you're comfortable with file operations:

1. **Find your database files** (usually in app's databases folder)
2. **Locate `test.db`** (contains your old tasks)
3. **Copy `test.db` to `tasks.db`** (overwrites new empty database)
4. **Restart the app**

### Option 3: Support via Settings
In the Settings page, you'll see:
- Migration status information
- Option to trigger manual migration
- Backup functionality to protect your data

## What the Migration Does
- **Scans** for old `test.db` file
- **Counts** your existing data (tasks, collections, subtasks)
- **Copies** old database to new location
- **Preserves** all your tasks and data
- **Creates backup** of current state before migration

## Database File Locations
- **Old database**: `test.db`
- **New database**: `tasks.db`
- **Backup location**: Documents directory (`tasks_backup.db`)

## After Migration
- Your tasks should reappear
- All collections, subtasks, and completions are preserved
- Old `test.db` file remains as backup
- New database follows proper naming convention

## Troubleshooting
If migration fails:
1. Check Settings page for migration options
2. Create a backup before attempting recovery
3. Restart the app after migration
4. Check app logs for error messages

## Prevention
This issue was caused by database filename inconsistency. The fix ensures:
- Single source of truth for database filename
- Consistent database path across all operations
- Automatic migration for existing users
- Proper backup functionality