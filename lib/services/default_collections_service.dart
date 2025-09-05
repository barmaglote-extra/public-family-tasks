import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasks/services/collections_service.dart';

class DefaultCollectionsService {
  static const String _prefsKey = 'default_collections_initialized';
  
  // Default collections data
  static final List<Map<String, String>> _defaultCollections = [
    {
      'name': 'Work & Career',
      'description': 'Tasks and goals related to your professional life and career development.'
    },
    {
      'name': 'Health & Fitness',
      'description': 'Stay active, track workouts, and take care of your body and mind.'
    },
    {
      'name': 'Personal Growth',
      'description': 'Learn new things, reflect, and grow personally and professionally.'
    },
    {
      'name': 'Home & Family',
      'description': 'Daily routines and activities that keep your home and family life balanced.'
    },
    {
      'name': 'Finance',
      'description': 'Manage money, track expenses, and plan for financial stability.'
    },
    {
      'name': 'Travel & Leisure',
      'description': 'Plan trips, explore hobbies, and enjoy your free time.'
    }
  ];

  /// Check if default collections have been initialized
  static Future<bool> isInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  /// Mark default collections as initialized
  static Future<void> markAsInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  /// Initialize default collections if not already done
  static Future<void> initializeDefaultCollections(CollectionsService collectionsService) async {
    // Check if already initialized
    if (await isInitialized()) {
      return;
    }

    // Add default collections
    for (final collection in _defaultCollections) {
      await collectionsService.addItem(
        collection['name']!,
        collection['description']!,
      );
    }

    // Mark as initialized
    await markAsInitialized();
  }
}