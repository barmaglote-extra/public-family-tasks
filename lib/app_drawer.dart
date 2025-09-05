import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:tasks/config/app_config.dart';
import 'package:tasks/main.dart';
import 'package:tasks/menu_header.dart';
import 'package:tasks/services/due_date_tasks_service.dart';
import 'package:tasks/services/localization_service.dart';
import 'package:tasks/services/recurring_tasks_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDrawer extends StatelessWidget {
  final _dueDateTasksService = locator<DueDateTasksService>();
  final _recurringTasksService = locator<RecurringTasksService>();
  late final Future<Map<String, int>> _dueDateTasksStatsFuture;
  late final Future<Map<String, int>> _recurringTasksStatsFuture;
  late final Future<String> _versionFuture;

  AppDrawer({super.key}) {
    _dueDateTasksStatsFuture = _dueDateTasksService.getDueDateTasksStats();
    _recurringTasksStatsFuture = _recurringTasksService.getTodayRecurringTasksStats();
    _versionFuture = _getAppVersion();
  }

  Future<String> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<void> _launchDonationUrl() async {
    final Uri url = Uri.parse(AppConfig.donationUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Color _getStatsColor(int total, int completed) {
    if (total == 0) {
      return Colors.transparent;
    } else if (total == completed) {
      return Colors.green;
    } else if (completed == 0) {
      return Colors.red;
    } else {
      return const Color.fromARGB(255, 213, 173, 11);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localizationService, child) {
        return Drawer(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                MenuHeader(),
                ListTile(
                  title: Text(localizationService.translate('navigation.home')),
                  dense: Platform.isAndroid,
                  leading: const Icon(Icons.home),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/');
                  },
                ),
                ListTile(
                  title: Text(localizationService.translate('navigation.collections')),
                  dense: Platform.isAndroid,
                  leading: const Icon(Icons.list),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, 'collections');
                  },
                ),
                ListTile(
                  title: Text(localizationService.translate('navigation.calendar')),
                  dense: Platform.isAndroid,
                  leading: const Icon(Icons.calendar_month),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, 'calendar');
                  },
                ),
                FutureBuilder<Map<String, int>>(
                  future: _dueDateTasksStatsFuture,
                  builder: (context, snapshot) {
                    Widget trailingWidget;
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      trailingWidget = Text(localizationService.translate('common.loading'), style: const TextStyle(fontSize: 12));
                    } else if (snapshot.hasError) {
                      trailingWidget = Text(localizationService.translate('common.error'), style: const TextStyle(fontSize: 12));
                    } else if (snapshot.hasData) {
                      final stats = snapshot.data!;
                      final total = stats['total']!;
                      final completed = stats['completed']!;
                      final color = _getStatsColor(total, completed);

                      trailingWidget = total == 0
                          ? const SizedBox.shrink()
                          : SizedBox(
                              width: 35,
                              child: Text(
                                '$completed/$total',
                                style: TextStyle(fontSize: 12, color: color),
                              ),
                            );
                    } else {
                      trailingWidget = const SizedBox.shrink();
                    }

                    return ListTile(
                      title: Text(localizationService.translate('navigation.due_tasks')),
                      dense: Platform.isAndroid,
                      leading: const Icon(Icons.calendar_today),
                      trailing: trailingWidget,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, 'tasks/duedate');
                      },
                    );
                  },
                ),
                FutureBuilder<Map<String, int>>(
                  future: _recurringTasksStatsFuture,
                  builder: (context, snapshot) {
                    Widget trailingWidget;
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      trailingWidget = Text(localizationService.translate('common.loading'), style: const TextStyle(fontSize: 12));
                    } else if (snapshot.hasError) {
                      trailingWidget = Text(localizationService.translate('common.error'), style: const TextStyle(fontSize: 12));
                    } else if (snapshot.hasData) {
                      final stats = snapshot.data!;
                      final total = stats['total']!;
                      final completed = stats['completed']!;
                      final color = _getStatsColor(total, completed);

                      trailingWidget = total == 0
                          ? const SizedBox.shrink()
                          : SizedBox(
                              width: 35,
                              child: Text(
                                '$completed/$total',
                                style: TextStyle(fontSize: 12, color: color),
                              ),
                            );
                    } else {
                      trailingWidget = const SizedBox.shrink();
                    }

                    return ListTile(
                      title: Text(localizationService.translate('navigation.today_tasks')),
                      dense: Platform.isAndroid,
                      leading: const Icon(Icons.repeat),
                      trailing: trailingWidget,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, 'tasks/recurrent');
                      },
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  title: Text(localizationService.translate('navigation.templates')),
                  dense: Platform.isAndroid,
                  leading: const Icon(Icons.bookmark),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, 'templates');
                  },
                ),
                ListTile(
                  title: Text(localizationService.translate('navigation.settings')),
                  dense: Platform.isAndroid,
                  leading: const Icon(Icons.settings),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, 'settings');
                  },
                ),
                ListTile(
                  title: Text(localizationService.translate('navigation.donate')),
                  dense: Platform.isAndroid,
                  leading: const Icon(Icons.coffee),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await _launchDonationUrl();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not open donation link: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: FutureBuilder<String>(
                    future: _versionFuture,
                    builder: (context, snapshot) {
                      return Consumer<LocalizationService>(
                        builder: (context, localizationService, child) {
                          return Text(
                            snapshot.hasData
                                ? localizationService.translate('app.version', params: {'version': snapshot.data!})
                                : localizationService.translate('app.version_loading'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
