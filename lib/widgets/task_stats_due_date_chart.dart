import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tasks/main.dart';
import 'package:tasks/services/tasks_service.dart';

class TaskStatsDueDateChart extends StatefulWidget {
  TaskStatsDueDateChart({super.key});
  final _tasksService = locator<TasksService>();

  @override
  State<TaskStatsDueDateChart> createState() => TaskStatsDueDateChartState();
}

class TaskStatsDueDateChartState extends State<TaskStatsDueDateChart> {
  late Future<Map<String, int>> _taskStats;

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  void refreshData() {
    final value = widget._tasksService.getRegularTaskDueDateStats();
    setState(() {
      _taskStats = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FutureBuilder<Map<String, int>>(
          future: _taskStats,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              return const SizedBox(
                height: 100,
                child: Center(child: Text('Failed to fetch task stats')),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox(
                height: 100,
                child: Center(child: Text('No data available')),
              );
            }

            final overdue = snapshot.data!['overdue']!.toDouble();
            final today = snapshot.data!['today']!.toDouble();
            final future = snapshot.data!['future']!.toDouble();
            final noDueDate = snapshot.data!['noDueDate']!.toDouble();
            final total = overdue + today + future + noDueDate;

            if (total == 0) {
              return const SizedBox(
                height: 100,
                child: Center(child: Text('No tasks')),
              );
            }

            return SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          if (overdue > 0)
                            PieChartSectionData(
                              color: Colors.red,
                              value: overdue,
                              radius: 30,
                              showTitle: false,
                            ),
                          if (today > 0)
                            PieChartSectionData(
                              color: Colors.orange,
                              value: today,
                              radius: 30,
                              showTitle: false,
                            ),
                          if (future > 0)
                            PieChartSectionData(
                              color: Colors.green,
                              value: future,
                              radius: 30,
                              showTitle: false,
                            ),
                          if (noDueDate > 0)
                            PieChartSectionData(
                              color: Colors.grey,
                              value: noDueDate,
                              radius: 30,
                              showTitle: false,
                            ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.red, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Overdue: ${(overdue / total * 100).toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.orange, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Today: ${(today / total * 100).toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.green, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Future: ${(future / total * 100).toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.grey, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'No due date: ${(noDueDate / total * 100).toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
