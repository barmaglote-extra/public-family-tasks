# Family Tasks - Task Management Application

[![Platform Support](https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20windows%20%7C%20macos%20%7C%20linux-blue)](#)
[![License](https://img.shields.io/badge/license-MIT-green)](#)
[![Flutter](https://img.shields.io/badge/flutter-3.6.2-blue)](#)

Family Tasks is a comprehensive, cross-platform task management application built with Flutter. It allows users to organize their tasks into collections, set due dates, create recurring tasks, manage subtasks, and track their productivity with detailed statistics.

<p align="center">
  <img src="assets/icon/app_icon.png" alt="Family Tasks App Icon" width="200">
</p>

## 🌟 Features

### Task Management
- **Regular Tasks**: Create one-time tasks with descriptions, due dates, and priority levels
- **Recurring Tasks**: Set up daily, weekly, monthly, or yearly recurring tasks
- **Subtasks**: Break down complex tasks into manageable subtasks
- **Task Collections**: Organize related tasks into customizable collections
- **Task Templates**: Create and reuse task templates for common tasks
- **Due Date Reminders**: Set notifications for important tasks

### Advanced Features
- **Statistics & Analytics**: Visualize task completion trends and due date distributions with interactive charts
- **Multi-language Support**: Available in English, Russian, German, Ukrainian, Spanish, and French
- **Data Backup & Restore**: Secure your data with built-in backup functionality
- **Cross-platform**: Works seamlessly on Android, iOS, Windows, macOS, and Linux
- **Dark/Light Theme**: Automatic theme switching based on system preferences
- **Search Functionality**: Quickly find tasks by name or description
- **App Badge Support**: Track pending tasks with app icon badges (Android/iOS)

### Productivity Tools
- **Calendar View**: Visualize tasks on a calendar interface
- **Priority Levels**: Mark tasks as urgent, normal, or low priority
- **Task Statistics**: Track completion rates and due date distributions
- **Share Tasks**: Export and import tasks as JSON files
- **Default Collections**: Predefined collections to help you get started (Work & Career, Health & Fitness, Personal Growth, Home & Family, Finance, and Travel & Leisure)

## 📋 Detailed Feature Descriptions

### Task Templates
The new Templates feature allows users to create reusable task templates, saving time when creating similar tasks. Key functionality includes:

- **Create Templates**: Save any existing task as a template with its subtasks
- **Template Management**: View, edit, and delete templates in a dedicated templates section
- **Use Templates**: Create new tasks based on existing templates with a single click
- **Template Details**: View template information including name, description, and associated subtasks
- **Full Localization**: Templates feature is fully localized in all supported languages

### Default Collections
To help users get started quickly, the app now includes predefined collections that cover common life areas:

- **Work & Career**: Tasks and goals related to your professional life and career development
- **Health & Fitness**: Stay active, track workouts, and take care of your body and mind
- **Personal Growth**: Learn new things, reflect, and grow personally and professionally
- **Home & Family**: Daily routines and activities that keep your home and family life balanced
- **Finance**: Manage money, track expenses, and plan for financial stability
- **Travel & Leisure**: Plan trips, explore hobbies, and enjoy your free time

These collections are automatically created on first launch, providing a structured starting point for organizing tasks.

## 📱 Screenshots

*(Add screenshots of your app here showing the main interface, task creation, calendar view, and statistics)*

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (version 3.6.2 or higher)
- Dart SDK
- Android Studio or VS Code with Flutter extensions

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/barmaglote-extra/family-tasks.git
   ```

2. Navigate to the project directory:
   ```bash
   cd family-tasks
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the application:
   ```bash
   flutter run
   ```

## 🏗️ Project Structure

```
lib/
├── config/          # Configuration files
├── mixins/          # Reusable mixins for navigation and functionality
├── models/          # Data models (Task, Collection, Subtask, etc.)
├── pages/           # UI screens and pages
├── repository/      # Database access layer (SQLite)
├── services/        # Business logic and services
├── utils/           # Utility functions
├── widgets/         # Reusable UI components
├── app_drawer.dart  # Main app drawer component
├── main.dart        # Application entry point
└── menu_header.dart # Header component for pages
```

## 🛠️ Key Components

### Task Types
- **Regular Tasks**: One-time tasks with optional due dates and subtasks
- **Recurring Tasks**: Tasks that repeat on a schedule (daily, weekly, monthly, yearly)
- **Subtasks**: Child tasks that belong to a parent task (only for regular tasks)
- **Templates**: Reusable task definitions that can be used to create new tasks

### Core Services
- **CollectionsService**: Manages task collections
- **TasksService**: Handles task operations and statistics
- **RecurringTasksService**: Manages recurring task logic
- **SubTasksService**: Manages subtask operations
- **TemplatesService**: Manages task templates and template subtasks
- **NotificationService**: Handles task reminders
- **BackupService**: Manages data backup and restoration
- **LocalizationService**: Handles multi-language support
- **TaskBadgeService**: Manages app icon badges
- **DefaultCollectionsService**: Initializes default collections on first launch

### UI Components
- **HomePage**: Dashboard with statistics and quick access
- **CollectionsPage**: View and manage task collections
- **TemplatesPage**: View and manage task templates
- **TemplatePage**: View template details
- **EditTemplatePage**: Create and edit templates
- **CalendarPage**: Calendar view of tasks
- **SettingsPage**: Application settings and preferences
- **Task Creation/Editing**: Forms for creating and editing tasks
- **Statistics Charts**: Visual representations of task data

## 📦 Dependencies

- `flutter_local_notifications`: For task reminders
- `sqflite`: Local database storage
- `provider`: State management
- `table_calendar`: Calendar view
- `fl_chart`: Data visualization
- `intl`: Internationalization support
- `shared_preferences`: User preferences storage
- `get_it`: Dependency injection
- `app_badge_plus`: App icon badge management
- `share_plus`: Share functionality
- `path`: Path manipulation utilities
- `package_info_plus`: Application package information
- `url_launcher`: Launch URLs
- `timezone`: Timezone handling

## 📋 Database Schema

The application uses SQLite for local data storage with the following tables:

- `collections`: Task collections with name and description
  - id (INTEGER PRIMARY KEY)
  - name (TEXT)
  - description (TEXT)

- `tasks`: Main task records with support for regular and recurring tasks
  - id (INTEGER PRIMARY KEY)
  - collection_id (INTEGER, FOREIGN KEY to collections)
  - is_completed (INTEGER)
  - description (TEXT)
  - urgency (INTEGER)
  - due_date (INTEGER - timestamp)
  - name (TEXT)
  - task_type (TEXT - 'regular' or 'recurrent')
  - recurrence_rule (TEXT - for recurring tasks)

- `subtasks`: Subtask records linked to parent tasks
  - id (INTEGER PRIMARY KEY)
  - task_id (INTEGER, FOREIGN KEY to tasks)
  - is_completed (INTEGER)
  - description (TEXT)
  - urgency (INTEGER)
  - due_date (INTEGER - timestamp)
  - name (TEXT)
  - order_index (INTEGER)

- `templates`: Task template records
  - id (INTEGER PRIMARY KEY)
  - name (TEXT)
  - description (TEXT)
  - created_at (INTEGER - timestamp)

- `template_subtasks`: Subtask definitions for templates
  - id (INTEGER PRIMARY KEY)
  - template_id (INTEGER, FOREIGN KEY to templates)
  - name (TEXT)
  - description (TEXT)
  - urgency (INTEGER)
  - order_index (INTEGER)

- `task_completions`: Task completion history for statistics
  - id (INTEGER PRIMARY KEY)
  - task_id (INTEGER, FOREIGN KEY to tasks)
  - completion_date (TEXT)

## 🌍 Localization

The app supports multiple languages with JSON-based translation files:
- English (en_US)
- Russian (ru_RU)
- German (de_DE)
- Ukrainian (uk_UA)
- Spanish (es_ES)
- French (fr_FR)

Translation files are located in `assets/intl/` and can be easily extended with new languages. All UI elements, including the new templates functionality, are fully localized in all supported languages.

## 🎯 Supported Platforms

- **Android**: 5.0+
- **iOS**: 11.0+
- **Windows**: 10+
- **macOS**: 10.15+
- **Linux**: Ubuntu 20.04+

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a pull request

## 📄 License

This project is licensed under the AGPL-3.0 license - see the [LICENSE](https://github.com/barmaglote-extra/public-family-tasks?tab=AGPL-3.0-1-ov-file#readme) file for details.

## 🙏 Acknowledgments

- Thanks to the Flutter community for the excellent framework and packages
- Inspired by various productivity and task management applications
- Icons and assets from [Cupertino Icons](https://pub.dev/packages/cupertino_icons)

## 📞 Support

For support, feature requests, or bug reports, please open an issue on GitHub.