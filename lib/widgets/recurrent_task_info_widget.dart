import 'package:flutter/material.dart';
import 'package:tasks/main.dart';
import 'package:tasks/services/task_completions_service.dart';
import 'package:intl/intl.dart';
import 'package:tasks/utils/date_utils.dart';

class RecurrentTaskInfoWidget extends StatefulWidget {
  final int taskId;
  final String? recurrenceRule;
  final _taskCompletionsService = locator<TaskCompletionsService>();

  RecurrentTaskInfoWidget({
    super.key,
    required this.taskId,
    required this.recurrenceRule,
  });

  @override
  State<RecurrentTaskInfoWidget> createState() => _RecurrentTaskInfoWidgetState();
}

class _RecurrentTaskInfoWidgetState extends State<RecurrentTaskInfoWidget> {
  List<bool> _completionStatus = [];
  Map<int, int> _daysInMonth = {};
  int _totalUnits = 0;
  late DateTime _startOfYear; // Убираем DateTime.now()
  final DateTime _currentYear = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startOfYear = DateTime(_currentYear.year, 1, 1);
    _loadCompletionData();
  }

  Future<void> _toggleTaskCompletion(DateTime date, int index) async {
    bool newStatus = !_completionStatus[index];

    setState(() {
      _completionStatus[index] = newStatus;
    });

    if (newStatus) {
      await widget._taskCompletionsService.markTaskAsCompleted(widget.taskId, date);
    } else {
      await widget._taskCompletionsService
          .markTaskAsNotCompleted(widget.taskId, date, recurrenceRule: widget.recurrenceRule);
    }
  }

  Future<void> _loadCompletionData() async {
    _startOfYear = DateTime(_startOfYear.year, 1, 1); // Начало года
    DateTime endOfYear = DateTime(_startOfYear.year, 12, 31);

    List<DateTime> completions =
        await widget._taskCompletionsService.getTaskCompletions(widget.taskId, _startOfYear, endOfYear, 400);

    _daysInMonth = {for (int month = 1; month <= 12; month++) month: DateTime(_startOfYear.year, month + 1, 0).day};

    switch (widget.recurrenceRule) {
      case 'daily':
        _totalUnits = DateTime(_startOfYear.year, 2, 29).day == 29 ? 366 : 365;
        break;
      case 'weekly':
        _totalUnits = 52;
        break;
      case 'monthly':
        _totalUnits = 12;
        break;
      case 'yearly':
        _totalUnits = 1;
        break;
      default:
        _totalUnits = 0;
    }

    List<bool> statusList = List.generate(_totalUnits, (index) => false);

    for (var completion in completions) {
      int? index;
      if (widget.recurrenceRule == 'daily') {
        for (int i = 0; i < _totalUnits; i++) {
          DateTime expectedDate = _startOfYear.add(Duration(days: i));
          if (completion.year == expectedDate.year &&
              completion.month == expectedDate.month &&
              completion.day == expectedDate.day) {
            index = i;
            break;
          }
        }
      } else if (widget.recurrenceRule == 'weekly') {
        DateTime firstDayOfYear = DateTime(_startOfYear.year, 1, 1);
        int daysToMonday = (DateTime.monday - firstDayOfYear.weekday + 7) % 7;
        DateTime firstMonday = firstDayOfYear.add(Duration(days: daysToMonday));
        firstMonday = DateTime(firstMonday.year, firstMonday.month, firstMonday.day);
        for (int i = 0; i < _totalUnits; i++) {
          DateTime weekStart = firstMonday.add(Duration(days: i * 7));
          weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
          DateTime weekEnd = weekStart.add(Duration(days: 6));
          weekEnd = DateTime(weekEnd.year, weekEnd.month, weekEnd.day);
          if (completion.isAtSameMomentAs(weekStart) ||
              (completion.isAfter(weekStart) && completion.isBefore(weekEnd.add(Duration(milliseconds: 1))))) {
            index = i;
            break;
          }
        }
      } else if (widget.recurrenceRule == 'monthly') {
        for (int i = 0; i < _totalUnits; i++) {
          DateTime monthDate = DateTime(_startOfYear.year, i + 1, 1);
          if (completion.year == monthDate.year && completion.month == monthDate.month) {
            index = i;
            break;
          }
        }
      } else if (widget.recurrenceRule == 'yearly') {
        if (completion.year == _startOfYear.year) {
          index = 0;
        }
      }

      if (index != null && index >= 0 && index < _totalUnits) {
        statusList[index] = true;
      }
    }

    setState(() {
      _completionStatus = statusList;
    });
  }

  bool _isCurrentPeriod(DateTime date, int index) {
    final now = DateTime.now();
    switch (widget.recurrenceRule) {
      case 'daily':
        return date.year == now.year && date.month == now.month && date.day == now.day;
      case 'weekly':
        return _startOfYear.year == now.year && getISOWeekNumber(date) == getISOWeekNumber(now);
      case 'monthly':
        return date.year == now.year && date.month == now.month;
      case 'yearly':
        return date.year == now.year;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildYearSelector(),
        widget.recurrenceRule == 'daily'
            ? _buildDailyView()
            : widget.recurrenceRule == 'weekly'
                ? _buildWeeklyView()
                : widget.recurrenceRule == 'monthly'
                    ? _buildMonthlyView()
                    : widget.recurrenceRule == 'yearly'
                        ? _buildYearlyView()
                        : const Center(child: Text('Unsupported recurrence rule')),
      ],
    );
  }

  void _changeYear(int delta) {
    setState(() {
      _startOfYear = DateTime(_startOfYear.year + delta, 1, 1);
    });
    _loadCompletionData();
  }

  Widget _buildYearSelector() {
    bool isFutureDisabled = _startOfYear.year >= _currentYear.year;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_left),
            onPressed: () => _changeYear(-1),
          ),
          Text(
            '${_startOfYear.year}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_right),
            onPressed: isFutureDisabled ? null : () => _changeYear(1),
            color: isFutureDisabled ? Colors.grey : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyView() {
    int total = 0;

    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(12, (month) {
          int days = _daysInMonth[month + 1] ?? 0;
          Widget monthHeader = Padding(
            padding: const EdgeInsets.only(bottom: 4.0, top: 4.0),
            child: Text(
              DateFormat('MMMM').format(DateTime(_startOfYear.year, month + 1)),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );

          Widget daysWidget = Padding(
            padding: const EdgeInsets.only(bottom: 5.0),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: List.generate(days, (day) {
                int dayOfYear = total + day;
                DateTime currentDate = _startOfYear.add(Duration(days: dayOfYear));
                currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
                bool isCompleted = (dayOfYear < _completionStatus.length) && _completionStatus[dayOfYear];
                bool isCurrent = _isCurrentPeriod(currentDate, dayOfYear);

                return GestureDetector(
                  onTap: () => _toggleTaskCompletion(currentDate, dayOfYear),
                  child: Tooltip(
                    message: DateFormat('d MMM').format(currentDate),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: isCurrent ? 27 : 25,
                          height: isCurrent ? 27 : 25,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted ? Colors.green : Colors.grey.shade300,
                            border: isCurrent
                                ? Border.all(color: Colors.red, width: 2)
                                : Border.all(color: Colors.grey.shade400, width: 0.5),
                          ),
                          child: Center(
                            child: Text(
                              '${day + 1}',
                              style: TextStyle(
                                color: isCompleted ? Colors.white : Colors.black54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );

          total += days;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [monthHeader, daysWidget],
          );
        }),
      ),
    );
  }

  Widget _buildWeeklyView() {
    DateTime firstDayOfYear = DateTime(_startOfYear.year, 1, 1);
    int daysToMonday = (DateTime.monday - firstDayOfYear.weekday + 7) % 7;
    DateTime firstMonday = firstDayOfYear.add(Duration(days: daysToMonday));

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_totalUnits, (index) {
              DateTime weekStart = firstMonday.add(Duration(days: index * 7));
              DateTime weekEnd = weekStart.add(Duration(days: 6));
              String dateRange = '${DateFormat('d MMM').format(weekStart)} - ${DateFormat('d MMM').format(weekEnd)}';
              bool isCompleted = index < _completionStatus.length && _completionStatus[index];
              bool isCurrent = _isCurrentPeriod(weekStart, index);

              return GestureDetector(
                onTap: () => _toggleTaskCompletion(weekStart, index),
                child: Tooltip(
                  message: dateRange,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: isCurrent ? 32 : 30,
                        height: isCurrent ? 32 : 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted ? Colors.green : Colors.grey.shade300,
                          border: isCurrent
                              ? Border.all(color: Colors.red, width: 2)
                              : Border.all(color: Colors.grey.shade400, width: 0.5),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${getISOWeekNumber(weekStart)}',
                                style: TextStyle(
                                  color: isCompleted ? Colors.white : Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat('d.MM').format(weekStart),
                                style: TextStyle(
                                  color: isCompleted ? Colors.white : Colors.black54,
                                  fontSize: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyView() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_totalUnits, (index) {
              DateTime monthDate = DateTime(_startOfYear.year, index + 1, 1);
              bool isCompleted = index < _completionStatus.length && _completionStatus[index];
              bool isCurrent = _isCurrentPeriod(monthDate, index);

              return GestureDetector(
                onTap: () => _toggleTaskCompletion(monthDate, index),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: isCurrent ? 42 : 40,
                      height: isCurrent ? 42 : 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? Colors.green : Colors.grey.shade300,
                        border: isCurrent
                            ? Border.all(color: Colors.red, width: 2)
                            : Border.all(color: Colors.grey.shade400, width: 0.5),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('MMM').format(monthDate),
                              style: TextStyle(
                                color: isCompleted ? Colors.white : Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCompleted ? Colors.white70 : Colors.black38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyView() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_totalUnits, (index) {
              DateTime yearDate = DateTime(_startOfYear.year, 1, 1);
              bool isCompleted = index < _completionStatus.length && _completionStatus[index];
              bool isCurrent = _isCurrentPeriod(yearDate, index);

              return GestureDetector(
                onTap: () => _toggleTaskCompletion(yearDate, index),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: isCurrent ? 52 : 50,
                      height: isCurrent ? 52 : 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? Colors.green : Colors.grey.shade300,
                        border: isCurrent
                            ? Border.all(color: Colors.red, width: 2)
                            : Border.all(color: Colors.grey.shade400, width: 0.5),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('yyyy').format(yearDate),
                          style: TextStyle(
                            color: isCompleted ? Colors.white : Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
