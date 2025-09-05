import 'package:intl/intl.dart';

class TaskCompletion {
  final int id;
  final int taskId;
  final DateTime completionDate;

  TaskCompletion({
    required this.id,
    required this.taskId,
    required this.completionDate,
  });

  String get dailyKey => DateFormat('yyyy-MM-dd').format(completionDate);

  String get weeklyKey {
    final firstDayOfYear = DateTime(completionDate.year, 1, 1);
    final dayOfYear = completionDate.difference(firstDayOfYear).inDays;
    final weekNumber = ((dayOfYear + firstDayOfYear.weekday - 1) / 7).ceil();
    return '${completionDate.year}-W$weekNumber';
  }

  String get monthlyKey => DateFormat('yyyy-MM').format(completionDate);

  factory TaskCompletion.fromMap(Map<String, dynamic> map) {
    return TaskCompletion(
      id: map['id'],
      taskId: map['task_id'],
      completionDate: DateTime.parse(map['completion_date']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'completion_date': DateFormat('yyyy-MM-dd').format(completionDate),
    };
  }
}