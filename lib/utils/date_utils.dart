int getISOWeekNumber(DateTime date) {
  DateTime firstDayOfYear = DateTime(date.year, 1, 1);
  int daysToMonday = (DateTime.monday - firstDayOfYear.weekday + 7) % 7;
  DateTime firstMonday = firstDayOfYear.add(Duration(days: daysToMonday));

  int daysSinceFirstMonday = date.difference(firstMonday).inDays;
  int weekNumber = (daysSinceFirstMonday / 7).floor() + 1;

  if (date.isBefore(firstMonday)) {
    return getISOWeekNumber(DateTime(date.year - 1, 12, 31));
  }

  DateTime lastDayOfYear = DateTime(date.year, 12, 31);
  DateTime lastMonday =
      lastDayOfYear.subtract(Duration(days: lastDayOfYear.weekday - 1));
  if (date.isAfter(lastMonday) && lastDayOfYear.weekday <= DateTime.wednesday) {
    return 1;
  }

  return weekNumber;
}
