# Manual Data Recovery Steps

## If your tasks are still missing after app restart:

### Step 1: Check the Settings Page
1. Open the app
2. Go to **Settings** (from the app drawer menu)
3. Look for a **"Data Migration"** section
4. If you see it, click **"Migrate Data Now"**

### Step 2: Check App Logs
When you open the app, look for these messages in the debug console:
```
Migration check:
- Old database path: [path]/test.db
- New database path: [path]/tasks.db
- Old DB exists: true/false
- New DB exists: true/false
```

### Step 3: Force Migration via Settings
If the automatic migration didn't work:
1. Open **Settings**
2. Look for **"Data Migration"** section
3. If it shows records found, click **"Migrate Data Now"**
4. Restart the app after migration

### What the Fix Does:

#### UI Overflow Fixed:
- ✅ Increased chart container height from 120px to 150px
- ✅ Made main page scrollable to prevent overflow
- ✅ Added extra spacing for floating action button

#### Migration Enhanced:
- ✅ Better logging for debugging
- ✅ Manual migration button in Settings
- ✅ Detailed record counts display
- ✅ Migration status feedback

### Expected Logs:
```
I/flutter: Checking old database at: [path]/test.db
I/flutter: Old database file exists. Size: [size] bytes
I/flutter: Tables found: [collections, tasks, subtasks, task_completions]
I/flutter: Table collections has X records
I/flutter: Table tasks has Y records
I/flutter: Table subtasks has Z records
I/flutter: Total records in old database: [total]
```

### If Migration Still Fails:
1. The old `test.db` file might not contain your tasks
2. Tasks might be in a different location
3. Database corruption might have occurred

### Quick Test:
1. Open the app
2. Check if charts no longer show "Bottom overflowed"
3. Go to Settings and look for migration section
4. Check debug logs for migration messages

The app should now:
- ✅ Display charts without overflow errors
- ✅ Show migration dialog or option in Settings
- ✅ Have detailed logging for troubleshooting
- ✅ Provide manual migration button if needed