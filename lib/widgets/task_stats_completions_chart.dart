import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tasks/main.dart';
import 'package:tasks/services/tasks_service.dart';

class TaskCompletionsStatsChart extends StatefulWidget {
  TaskCompletionsStatsChart({super.key});
  final _tasksService = locator<TasksService>();

  @override
  State<TaskCompletionsStatsChart> createState() => TaskCompletionsStatsChartState();
}

class TaskCompletionsStatsChartState extends State<TaskCompletionsStatsChart> {
  late Future<Map<String, int>> _taskStats;

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  void refreshData() {
    final value = widget._tasksService.getTaskCompletionStats();
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
                child: Center(child: Text('No data')),
              );
            }

            final completed = snapshot.data!['completed']!.toDouble();
            final incomplete = snapshot.data!['incomplete']!.toDouble();
            final total = completed + incomplete;

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
                  // График слева
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          if (completed > 0)
                            PieChartSectionData(
                              color: Colors.green,
                              value: completed,
                              radius: 35,
                              showTitle: false,
                            ),
                          if (incomplete > 0)
                            PieChartSectionData(
                              color: Colors.red,
                              value: incomplete,
                              radius: 35,
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
                              Icon(Icons.circle, color: Colors.green, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Completed: ${(completed / total * 100).toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.red, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'In Progress: ${(incomplete / total * 100).toStringAsFixed(1)}%',
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
