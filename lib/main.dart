import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:tasks/pages/calendar_page.dart';
import 'package:tasks/pages/collections_page.dart';
import 'package:tasks/pages/edit_template_page.dart';
import 'package:tasks/pages/new_collection_page.dart';
import 'package:tasks/pages/new_task_page.dart';
import 'package:tasks/pages/settings_page.dart';
import 'package:tasks/pages/tasks_duedate_page.dart';
import 'package:tasks/pages/collection_page.dart';
import 'package:tasks/pages/templates_page.dart';
import 'package:get_it/get_it.dart';
import 'package:tasks/pages/today_recurrent_tasks_page.dart';
import 'package:tasks/repository/sqllitedb.dart';
import 'package:tasks/services/collections_service.dart';
import 'package:tasks/services/due_date_tasks_service.dart';
import 'package:tasks/services/notification_service.dart';
import 'package:tasks/services/recurring_tasks_service.dart';
import 'package:tasks/services/sub_tasks_service.dart';
import 'package:tasks/services/task_badge_service.dart';
import 'package:tasks/services/task_completions_service.dart';
import 'package:tasks/services/tasks_service.dart';
import 'package:tasks/services/backup_service.dart';
import 'package:tasks/services/database_migration_service.dart';
import 'package:tasks/services/share_service.dart';
import 'package:tasks/services/update_provider.dart';
import 'package:tasks/services/localization_service.dart';
import 'package:tasks/services/templates_service.dart';
import 'package:tasks/services/default_collections_service.dart';
import 'pages/home_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GetIt locator = GetIt.instance;

Future<void> setupLocator() async {
  locator.registerLazySingleton<SQLLiteDB>(() => SQLLiteDB());
  locator.registerLazySingleton<CollectionsService>(() => CollectionsService());
  locator.registerLazySingleton<TasksService>(() => TasksService());
  locator.registerLazySingleton<UpdateProvider>(() => UpdateProvider());
  locator.registerLazySingleton<TaskCompletionsService>(() => TaskCompletionsService());
  locator.registerLazySingleton<RecurringTasksService>(() => RecurringTasksService());
  locator.registerLazySingleton<DueDateTasksService>(() => DueDateTasksService());
  locator.registerLazySingleton<TaskBadgeService>(() => TaskBadgeService());
  locator.registerLazySingleton<SubTasksService>(() => SubTasksService());
  locator.registerLazySingleton<BackupService>(() => BackupService());
  locator.registerLazySingleton<DatabaseMigrationService>(() => DatabaseMigrationService());
  locator.registerLazySingleton<ShareService>(() => ShareService());
  locator.registerLazySingleton<LocalizationService>(() => LocalizationService());
  locator.registerLazySingleton<TemplatesService>(() => TemplatesService());
  locator.registerLazySingleton<DefaultCollectionsService>(() => DefaultCollectionsService());

  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();
  await notificationService.requestExactAlarmPermission();
  locator.registerSingleton<NotificationService>(notificationService);

  if (Platform.isAndroid) {
    final badgeService = locator<TaskBadgeService>();
    badgeService.initialize();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initializeDateFormatting('en_US', null);
  await setupLocator();
  await locator<LocalizationService>().loadLanguage();
  await locator<TasksService>().initTotalCompletedCounter();
  await locator<SubTasksService>().initializeOrderIndexes();
  
  // Initialize default collections
  final collectionsService = locator<CollectionsService>();
  await DefaultCollectionsService.initializeDefaultCollections(collectionsService);

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    locator<NotificationService>().handleLaunchFromNotification();
    _handleIntentData();
  });
}

void _handleIntentData() async {
  if (Platform.isAndroid) {
    try {
      const platform = MethodChannel('app.channel.shared.data');
      final String? sharedData = await platform.invokeMethod('getSharedData');

      if (sharedData != null && sharedData.isNotEmpty) {
        _processSharedData(sharedData);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get intent data: $e');
      }
    }
  }
}

void _processSharedData(String data) async {
  try {
    final shareService = locator<ShareService>();
    final importedData = await shareService.importTaskFromJson(data);

    if (importedData != null) {
      final parsedData = shareService.parseImportedTaskForForm(importedData);

      // Wait a bit for the app to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to import page
      navigatorKey.currentState?.pushNamed(
        'tasks/import',
        arguments: {'importData': parsedData},
      );
    }
  } catch (e) {
    if (kDebugMode) {
      print('Failed to process shared data: $e');
    }
    // Show error message
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import shared task: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: locator<LocalizationService>(),
      child: Consumer<LocalizationService>(
        builder: (context, localizationService, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: localizationService.translate('app.title'),
            initialRoute: '/',
            locale: localizationService.currentLocale,
            supportedLocales: LocalizationService.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
            ),
            onGenerateRoute: (RouteSettings settings) {
              final Uri uri = Uri.parse(settings.name ?? '');
              final int collectionId =
                  settings.arguments is Map ? (settings.arguments as Map)['collectionId'] ?? -1 : -1;
              final String? recurrenceInterval =
                  settings.arguments is Map ? (settings.arguments as Map)['recurrenceInterval'] : null;

              switch (uri.path) {
                case 'collections':
                  return MaterialPageRoute(
                    settings: RouteSettings(name: 'collections'),
                    builder: (context) => CollectionsPage(),
                  );
                case 'collections/new':
                  return MaterialPageRoute(
                    settings: RouteSettings(name: 'collections/new'),
                    builder: (context) => NewCollectionPage(title: 'Collections'),
                  );
                case 'tasks':
                  return MaterialPageRoute(
                    settings: RouteSettings(name: 'tasks'),
                    builder: (context) => CollectionPage(collectionId: collectionId),
                  );
                case 'tasks/new':
                  final templateId = settings.arguments is Map ? (settings.arguments as Map)['templateId'] : null;
                  return MaterialPageRoute(
                    settings: RouteSettings(name: 'tasks/new'),
                    builder: (context) => NewTaskPage(
                      title: 'New Task',
                      collectionId: collectionId,
                      templateId: templateId,
                    ),
                  );
                case 'tasks/import':
                  final importData = settings.arguments is Map ? (settings.arguments as Map)['importData'] : null;
                  return MaterialPageRoute(
                    settings: RouteSettings(name: 'tasks/import'),
                    builder: (context) => NewTaskPage(
                      title: 'Import Task',
                      collectionId: -1,
                      importedTaskData: importData,
                    ),
                  );
                case 'tasks/duedate':
                  return MaterialPageRoute(
                    settings: RouteSettings(name: 'tasks/duedate'),
                    builder: (context) => TasksDueDatePage(),
                  );
                case 'tasks/recurrent':
                  return MaterialPageRoute(
                    settings: RouteSettings(name: 'tasks/recurrent'),
                    builder: (context) => TodayRecurrentTasksPage(recurrenceInterval: recurrenceInterval),
                  );
                case 'calendar':
                  return MaterialPageRoute(
                    settings: RouteSettings(name: 'calendar'),
                    builder: (context) => CalendarPage(),
                  );
                case 'settings':
                  return MaterialPageRoute(
                    settings: RouteSettings(name: 'settings'),
                    builder: (context) => const SettingsPage(),
                  );
                case 'templates':
                  return MaterialPageRoute(
                    settings: RouteSettings(name: 'templates'),
                    builder: (context) => const TemplatesPage(),
                  );
                case 'templates/edit':
                  final templateId = settings.arguments is Map ? (settings.arguments as Map)['templateId'] : null;
                  return MaterialPageRoute(
                    settings: RouteSettings(name: 'templates/edit'),
                    builder: (context) => EditTemplatePage(templateId: templateId),
                  );
                default:
                  return MaterialPageRoute(builder: (context) => MyHomePage(title: 'Home Page'));
              }
            },
          );
        },
      ),
    );
  }
}
