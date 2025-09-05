import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as badges;
import 'package:provider/provider.dart';
import 'package:tasks/services/localization_service.dart';

mixin NavigationMixin<T extends StatefulWidget> on State<T> {
  static const routesMap = {
    0: '/',
    1: 'collections',
    2: 'calendar',
    3: 'tasks/duedate',
    4: 'tasks/recurrent',
  };

  void _navigate(int index) {
    final route = routesMap[index] ?? '/';
    if (ModalRoute.of(context)?.settings.name != route) {
      Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
    }
  }

  Widget buildBottomNavigationBar(int dueDates, int recurrents, {int? todayTasks}) {
    return Consumer<LocalizationService>(
      builder: (context, localizationService, child) {
        return BottomNavigationBar(
          onTap: _navigate,
          type: BottomNavigationBarType.fixed,
          currentIndex: _getCurrentIndex(ModalRoute.of(context)?.settings.name),
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          showSelectedLabels: true,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: localizationService.translate('bottom_navigation.home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.list),
              label: localizationService.translate('bottom_navigation.collections'),
            ),
            BottomNavigationBarItem(
              icon: todayTasks != null && todayTasks > 0
                  ? badges.Badge(
                      label: Text(todayTasks.toString(), style: const TextStyle(color: Colors.white)),
                      child: const Icon(Icons.calendar_month),
                    )
                  : const Icon(Icons.calendar_month),
              label: localizationService.translate('bottom_navigation.calendar'),
            ),
            BottomNavigationBarItem(
              icon: dueDates > 0
                  ? badges.Badge(
                      label: Text(dueDates.toString(), style: const TextStyle(color: Colors.white)),
                      child: const Icon(Icons.calendar_today),
                    )
                  : const Icon(Icons.calendar_today),
              label: localizationService.translate('bottom_navigation.due_date'),
            ),
            BottomNavigationBarItem(
              icon: recurrents > 0
                  ? badges.Badge(
                      label: Text(recurrents.toString(), style: const TextStyle(color: Colors.white)),
                      child: const Icon(Icons.repeat),
                    )
                  : const Icon(Icons.repeat),
              label: localizationService.translate('bottom_navigation.recurrent'),
            ),
          ],
        );
      },
    );
  }

  int _getCurrentIndex(String? currentRoute) {
    return routesMap.entries
        .firstWhere((entry) => entry.value == currentRoute, orElse: () => const MapEntry(0, '/'))
        .key;
  }
}
