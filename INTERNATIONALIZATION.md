# Internationalization (i18n) Implementation

The Tasks app now supports multiple languages with a comprehensive internationalization system.

## Supported Languages

1. **English (US)** - `en_US` (Default)
2. **Russian** - `ru_RU` 
3. **German** - `de_DE`
4. **Ukrainian** - `uk_UA`
5. **Spanish** - `es_ES`
6. **French** - `fr_FR`

## Features

### Language Selection
- Available in **Settings** page
- Dropdown menu with native language names
- Immediate language switching
- Persistent language preference (saved in SharedPreferences)

### Comprehensive Translation Coverage
- App titles and navigation
- Page headers and section titles  
- Task and collection management
- Settings and configuration pages
- Action buttons and confirmation dialogs
- Error messages and status notifications
- Date and time formatting
- Statistics and charts labels

## How to Use

### For Users
1. Open the app
2. Navigate to **Settings** page using the drawer menu
3. Find the **Language** section at the top
4. Select your preferred language from the dropdown
5. The app interface will immediately update to the selected language

### For Developers

#### Using Localization in Widgets

**Method 1: Consumer Widget (Recommended for complex UI)**
```dart
Consumer<LocalizationService>(
  builder: (context, localizationService, child) {
    return Text(localizationService.translate('tasks.new_task'));
  },
)
```

**Method 2: Context Extension (Quick access)**
```dart
Text(context.tr('tasks.new_task'))
```

**Method 3: LocalizedText Widget (Simple text)**
```dart
LocalizedText('tasks.new_task', style: TextStyle(fontSize: 16))
```

**Method 4: With Parameters**
```dart
Text(context.tr('tasks.overdue_by', params: {'days': '3', 'plural': 's'}))
```

#### Adding New Languages

1. Create a new JSON file in `assets/intl/` (e.g., `it_IT.json` for Italian)
2. Copy the structure from `en_US.json` and translate all values
3. Add the locale to `LocalizationService.supportedLocales`:
```dart
static const List<Locale> supportedLocales = [
  // ... existing locales
  Locale('it', 'IT'), // Italian
];
```
4. Add the language name to `LocalizationService.languageNames`:
```dart
static const Map<String, String> languageNames = {
  // ... existing names
  'it_IT': 'Italiano',
};
```
5. Update `pubspec.yaml` assets section to include the new file

#### Adding New Translation Keys

1. Add the key to all language files in `assets/intl/`
2. Use the key in your widgets using any of the methods above
3. Test with different languages to ensure proper translation

## Technical Implementation

### Architecture
- **LocalizationService**: Core service managing language switching and translations
- **ChangeNotifier Pattern**: Reactive UI updates when language changes
- **Provider Pattern**: Dependency injection for accessing localization throughout the app
- **JSON Files**: Language-specific translation files
- **SharedPreferences**: Persistent storage of language preference

### File Structure
```
lib/
├── services/
│   └── localization_service.dart      # Core localization logic
├── widgets/
│   └── localized_text.dart            # Helper widgets
assets/intl/
├── en_US.json                         # English translations
├── ru_RU.json                         # Russian translations  
├── de_DE.json                         # German translations
├── uk_UA.json                         # Ukrainian translations
├── es_ES.json                         # Spanish translations
└── fr_FR.json                         # French translations
```

### Translation File Structure
```json
{
  "app": {
    "title": "Task Manager"
  },
  "navigation": {
    "home": "Home",
    "settings": "Settings"
  },
  "tasks": {
    "new_task": "New Task",
    "edit_task": "Edit Task"
  }
}
```

### Key Features

#### Automatic Language Detection
The app loads the saved language preference on startup and falls back to English if loading fails.

#### Immediate UI Updates
Language changes trigger immediate UI refresh using the Provider pattern without requiring app restart.

#### Parameter Support
Translation keys support parameters for dynamic content:
```json
"overdue_by": "Overdue by {days} day{plural}"
```

#### Nested Keys
Organized translation structure with nested categories for better maintenance.

#### Error Handling
Graceful fallback to English if a translation key is missing or a language file fails to load.

## Maintenance

### Best Practices
1. **Consistent Key Naming**: Use descriptive, hierarchical keys (e.g., `tasks.new_task`)
2. **Complete Translations**: Ensure all keys exist in all language files
3. **Context Awareness**: Provide enough context in translations for proper understanding
4. **Testing**: Test UI with different languages, especially longer German/French text
5. **Cultural Sensitivity**: Consider cultural differences, not just language translation

### Common Issues
- **Missing Keys**: Always add new keys to ALL language files
- **Text Overflow**: Longer translations (German/French) may cause layout issues
- **Date Formats**: Different locales may have different date/time preferences
- **RTL Languages**: Current implementation doesn't support RTL languages

## Future Enhancements

1. **Date/Time Localization**: Integrate with `intl` package for proper date formatting
2. **Pluralization Rules**: Advanced plural forms for different languages
3. **RTL Support**: Right-to-left language support (Arabic, Hebrew)
4. **Dynamic Loading**: Load translations from remote server
5. **Translation Management**: Integration with translation management platforms
6. **Contextual Help**: Language-specific help and documentation

## Testing

### Manual Testing Checklist
- [ ] Language selection works in Settings
- [ ] App title changes correctly
- [ ] Navigation drawer items are translated
- [ ] Page headers use correct language
- [ ] Button labels are translated
- [ ] Error messages appear in selected language
- [ ] Language preference persists after app restart
- [ ] Fallback to English works for missing keys

### Automated Testing
Consider adding widget tests for:
- Language switching functionality
- Translation key resolution
- UI layout with different text lengths
- Fallback behavior for missing translations