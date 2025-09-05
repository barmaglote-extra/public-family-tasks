import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/mixins/back_button_mixin.dart';
import 'package:tasks/services/backup_service.dart';
import 'package:tasks/services/database_migration_service.dart';
import 'package:tasks/services/localization_service.dart';
import 'package:intl/intl.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with BackButtonMixin {
  final _backupService = locator<BackupService>();
  final _migrationService = locator<DatabaseMigrationService>();
  bool _isLoading = false;
  DateTime? _backupDate;
  int? _backupSize;
  bool _hasBackup = false;
  bool? _isBackupValid;
  Map<String, dynamic>? _backupInfo;
  bool _hasOldDatabase = false;
  Map<String, dynamic>? _oldDatabaseInfo;

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
    _checkForOldDatabase();
  }

  Future<void> _loadBackupInfo() async {
    setState(() => _isLoading = true);

    try {
      final hasBackup = await _backupService.hasBackup();
      final backupDate = await _backupService.getBackupDate();
      final backupSize = await _backupService.getBackupSize();
      bool? isValid;
      Map<String, dynamic>? backupInfo;

      if (hasBackup) {
        isValid = await _backupService.validateBackup();
        backupInfo = await _backupService.getBackupInfo();
      }

      setState(() {
        _hasBackup = hasBackup;
        _backupDate = backupDate;
        _backupSize = backupSize;
        _isBackupValid = isValid;
        _backupInfo = backupInfo;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading backup info: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createBackup() async {
    final localizationService = Provider.of<LocalizationService>(context, listen: false);

    // Show confirmation dialog if backup already exists
    if (_hasBackup) {
      final confirmed = await _showConfirmationDialog(
        localizationService.translate('settings.overwrite_backup'),
        localizationService.translate('settings.overwrite_backup_msg'),
        localizationService.translate('actions.overwrite'),
      );
      if (!confirmed) return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _backupService.createBackup();

      if (success) {
        await _loadBackupInfo();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Consumer<LocalizationService>(
                builder: (context, localizationService, child) {
                  return Text(localizationService.translate('settings.backup_created'));
                },
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Consumer<LocalizationService>(
                builder: (context, localizationService, child) {
                  return Text(localizationService.translate('settings.backup_failed'));
                },
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Consumer<LocalizationService>(
              builder: (context, localizationService, child) {
                return Text('${localizationService.translate('settings.backup_failed')}: $e');
              },
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    final localizationService = Provider.of<LocalizationService>(context, listen: false);

    final confirmed = await _showConfirmationDialog(
      localizationService.translate('settings.restore_database'),
      localizationService.translate('settings.restore_database_msg'),
      localizationService.translate('settings.restore_backup'),
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final success = await _backupService.restoreFromBackup();

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Consumer<LocalizationService>(
                builder: (context, localizationService, child) {
                  return Text(localizationService.translate('settings.restore_success'));
                },
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Consumer<LocalizationService>(
                builder: (context, localizationService, child) {
                  return Text(localizationService.translate('settings.restore_failed'));
                },
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Consumer<LocalizationService>(
              builder: (context, localizationService, child) {
                return Text('${localizationService.translate('settings.restore_failed')}: $e');
              },
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog(
    String title,
    String content,
    String confirmButtonText,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Consumer<LocalizationService>(
              builder: (context, localizationService, child) {
                return Text(localizationService.translate('actions.cancel'));
              },
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text(confirmButtonText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _checkForOldDatabase() async {
    try {
      // Check if migration should be offered
      final shouldOffer = await _migrationService.shouldOfferMigration();

      if (shouldOffer) {
        final oldDbInfo = await _migrationService.checkOldDatabase();
        setState(() {
          _hasOldDatabase = oldDbInfo['exists'] ?? false;
          _oldDatabaseInfo = oldDbInfo;
        });

        // If old database has data, show migration dialog
        if (_hasOldDatabase && oldDbInfo['counts'] != null) {
          final counts = oldDbInfo['counts'] as Map<String, int>;
          final totalRecords = counts.values.fold(0, (sum, count) => sum + count);

          if (totalRecords > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showMigrationDialog(counts);
            });
          }
        }
      } else {
        // Check if there's still an old database for manual migration
        final oldDbInfo = await _migrationService.checkOldDatabase();
        final migrationCompleted = await _migrationService.isMigrationCompleted();

        setState(() {
          _hasOldDatabase = oldDbInfo['exists'] ?? false;
          _oldDatabaseInfo = oldDbInfo;

          // Only show migration section if database exists and migration not completed
          if (migrationCompleted && _hasOldDatabase) {
            _hasOldDatabase = false; // Hide migration section since it's completed
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking old database: $e');
      }
    }
  }

  Future<void> _showMigrationDialog(Map<String, int> counts) async {
    final totalTasks = (counts['tasks'] ?? 0) + (counts['subtasks'] ?? 0);
    final totalCollections = counts['collections'] ?? 0;

    if (totalTasks == 0 && totalCollections == 0) {
      // Mark as shown even if no data to prevent future prompts
      await _migrationService.markMigrationPromptShown();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer<LocalizationService>(
        builder: (context, localizationService, child) => AlertDialog(
          title: Text(localizationService.translate('settings.data_migration_available')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizationService.translate('settings.data_migration_found')),
              const SizedBox(height: 12),
              if (totalCollections > 0)
                Consumer<LocalizationService>(
                  builder: (context, localizationService, child) {
                    return Text('${localizationService.translate('common.list_item_bullet')} ${localizationService.translate('collections.collections')}: $totalCollections');
                  },
                ),
              if (counts['tasks'] != null && counts['tasks']! > 0)
                Consumer<LocalizationService>(
                  builder: (context, localizationService, child) {
                    return Text('${localizationService.translate('common.list_item_bullet')} ${localizationService.translate('tasks.tasks')}: ${counts['tasks']}');
                  },
                ),
              if (counts['subtasks'] != null && counts['subtasks']! > 0)
                Consumer<LocalizationService>(
                  builder: (context, localizationService, child) {
                    return Text('${localizationService.translate('common.list_item_bullet')} ${localizationService.translate('subtasks.subtasks')}: ${counts['subtasks']}');
                  },
                ),
              if (counts['task_completions'] != null && counts['task_completions']! > 0)
                Consumer<LocalizationService>(
                  builder: (context, localizationService, child) {
                    return Text(
                        '${localizationService.translate('common.list_item_bullet')} ${localizationService.translate('tasks.completed_tasks')}: ${counts['task_completions']}');
                  },
                ),
              const SizedBox(height: 12),
              Text(
                localizationService.translate('settings.data_migration_question'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Mark prompt as shown but don't complete migration
                await _migrationService.markMigrationPromptShown();
                Navigator.of(context).pop();
              },
              child: Text(localizationService.translate('settings.data_migration_skip')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performMigration();
              },
              child: Text(localizationService.translate('settings.data_migration_button')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performMigration() async {
    setState(() => _isLoading = true);

    try {
      final success = await _migrationService.forceMigrateFromTestDb();

      if (success) {
        setState(() => _hasOldDatabase = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Consumer<LocalizationService>(
                builder: (context, localizationService, child) {
                  return Text(localizationService.translate('settings.data_migration_completed'));
                },
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Consumer<LocalizationService>(
                builder: (context, localizationService, child) {
                  return Text(localizationService.translate('settings.data_migration_failed'));
                },
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Consumer<LocalizationService>(
              builder: (context, localizationService, child) {
                return Text(localizationService.translate('settings.data_migration_error', params: {'error': '$e'}));
              },
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          await handleBackButton();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<LocalizationService>(
            builder: (context, localizationService, child) {
              return Text(localizationService.translate('settings.settings'), style: TextStyle(color: Colors.white));
            },
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        drawer: AppDrawer(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16.0,
                  16.0,
                  16.0,
                  16.0 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Language Selection Section
                    Consumer<LocalizationService>(
                      builder: (context, localizationService, child) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.language, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      localizationService.translate('settings.language'),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  localizationService.translate('settings.select_language'),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<Locale>(
                                      value: localizationService.currentLocale,
                                      isExpanded: true,
                                      items: LocalizationService.supportedLocales.map((locale) {
                                        final languageKey = '${locale.languageCode}_${locale.countryCode}';
                                        final languageName =
                                            LocalizationService.languageNames[languageKey] ?? languageKey;
                                        return DropdownMenuItem<Locale>(
                                          value: locale,
                                          child: Text(languageName),
                                        );
                                      }).toList(),
                                      onChanged: (Locale? newLocale) async {
                                        if (newLocale != null) {
                                          await localizationService.changeLanguage(newLocale);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Database Backup Section
                    Consumer<LocalizationService>(
                      builder: (context, localizationService, child) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.backup, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      localizationService.translate('settings.backup_restore'),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Consumer<LocalizationService>(
                                  builder: (context, localizationService, child) {
                                    return Text(
                                      localizationService.translate('settings.backup_description'),
                                      style: const TextStyle(color: Colors.grey),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Backup Info
                                if (_hasBackup && _backupDate != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isBackupValid == true ? Colors.green.shade50 : Colors.red.shade50,
                                      border: Border.all(
                                          color: _isBackupValid == true ? Colors.green.shade200 : Colors.red.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _isBackupValid == true ? Icons.check_circle : Icons.error,
                                              color:
                                                  _isBackupValid == true ? Colors.green.shade600 : Colors.red.shade600,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Consumer<LocalizationService>(
                                              builder: (context, localizationService, child) {
                                                return Text(
                                                  _isBackupValid == true
                                                      ? localizationService.translate('settings.backup_available_valid')
                                                      : _isBackupValid == false
                                                          ? localizationService
                                                              .translate('settings.backup_available_invalid')
                                                          : localizationService
                                                              .translate('settings.backup_available_checking'),
                                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Consumer<LocalizationService>(
                                          builder: (context, localizationService, child) {
                                            return Text(
                                              localizationService.translate('settings.backup_created_date', params: {
                                                'date': DateFormat('MMM dd, yyyy at HH:mm').format(_backupDate!),
                                              }),
                                              style: TextStyle(color: Colors.grey.shade700),
                                            );
                                          },
                                        ),
                                        if (_backupSize != null)
                                          Consumer<LocalizationService>(
                                            builder: (context, localizationService, child) {
                                              return Text(
                                                '${localizationService.translate('settings.backup_size')}: ${_formatFileSize(_backupSize!)}',
                                                style: TextStyle(color: Colors.grey.shade700),
                                              );
                                            },
                                          ),

                                        // Show backup contents if available
                                        if (_backupInfo != null && _backupInfo!['totalRecords'] > 0) ...[
                                          const SizedBox(height: 8),
                                          Consumer<LocalizationService>(
                                            builder: (context, localizationService, child) {
                                              return Text(
                                                localizationService
                                                    .translate('settings.backup_contains_records', params: {
                                                  'count': '${_backupInfo!['totalRecords']}',
                                                }),
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 4),
                                          if (_backupInfo!['counts'] != null)
                                            ...(_backupInfo!['counts'] as Map<String, int>)
                                                .entries
                                                .where((entry) => entry.value > 0)
                                                .map(
                                                  (entry) => Padding(
                                                    padding: const EdgeInsets.only(left: 8.0),
                                                    child: Consumer<LocalizationService>(
                                                      builder: (context, localizationService, child) {
                                                        return Text(
                                                          '• ${entry.key}: ${entry.value} ${localizationService.translate('settings.records')}',
                                                          style: TextStyle(
                                                            color: Colors.grey.shade600,
                                                            fontSize: 12,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                        ],

                                        if (_isBackupValid == false) ...[
                                          const SizedBox(height: 4),
                                          Consumer<LocalizationService>(
                                            builder: (context, localizationService, child) {
                                              return Text(
                                                localizationService.translate('settings.backup_corrupted_warning'),
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      border: Border.all(color: Colors.orange.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning_amber, color: Colors.orange.shade600, size: 16),
                                        const SizedBox(width: 8),
                                        Consumer<LocalizationService>(
                                          builder: (context, localizationService, child) {
                                            return Text(
                                              localizationService.translate('settings.no_backup'),
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _isLoading ? null : _createBackup,
                                        icon: const Icon(Icons.save),
                                        label: Consumer<LocalizationService>(
                                          builder: (context, localizationService, child) {
                                            return Text(
                                              _hasBackup
                                                  ? localizationService.translate('settings.create_backup')
                                                  : localizationService.translate('settings.create_backup'),
                                            );
                                          },
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: (_isLoading || !_hasBackup || _isBackupValid != true)
                                            ? null
                                            : _restoreBackup,
                                        icon: const Icon(Icons.restore),
                                        label: Consumer<LocalizationService>(
                                          builder: (context, localizationService, child) {
                                            return Text(localizationService.translate('settings.restore_backup'));
                                          },
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              (_hasBackup && _isBackupValid == true) ? Colors.orange : Colors.grey,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Data Migration Section (for troubleshooting)
                    if (_hasOldDatabase)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.sync_alt, size: 24),
                                  const SizedBox(width: 8),
                                  Consumer<LocalizationService>(
                                    builder: (context, localizationService, child) {
                                      return Text(
                                        localizationService.translate('settings.database_migration'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Consumer<LocalizationService>(
                                builder: (context, localizationService, child) {
                                  return Text(
                                    localizationService.translate('settings.data_migration_old_db_detected'),
                                    style: const TextStyle(color: Colors.grey),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              if (_oldDatabaseInfo?['totalRecords'] != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    border: Border.all(color: Colors.blue.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Consumer<LocalizationService>(
                                        builder: (context, localizationService, child) {
                                          return Text(
                                            localizationService
                                                .translate('settings.data_migration_records_found', params: {
                                              'count': '${_oldDatabaseInfo!['totalRecords']}',
                                            }),
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      if (_oldDatabaseInfo!['counts'] != null)
                                        ...(_oldDatabaseInfo!['counts'] as Map<String, int>).entries.map(
                                              (entry) => Consumer<LocalizationService>(
                                                builder: (context, localizationService, child) {
                                                  return Text(
                                                      '${localizationService.translate('common.list_item_bullet')} ${entry.key}: ${entry.value} ${localizationService.translate('settings.records')}');
                                                },
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _performMigration,
                                icon: const Icon(Icons.file_copy),
                                label: Consumer<LocalizationService>(
                                  builder: (context, localizationService, child) {
                                    return Text(localizationService.translate('settings.data_migration_now'));
                                  },
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
