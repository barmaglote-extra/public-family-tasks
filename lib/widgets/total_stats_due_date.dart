import 'package:flutter/material.dart';

import 'package:tasks/main.dart';
import 'package:tasks/services/tasks_service.dart';

class TotalStatsDueDate extends StatefulWidget {
  TotalStatsDueDate({super.key});
  final _tasksService = locator<TasksService>();

  @override
  State<TotalStatsDueDate> createState() => TotalStatsDueDateState();
}

class TotalStatsDueDateState extends State<TotalStatsDueDate> {
  late Future<int> _totalCompleted;

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  void refreshData() {
    final value = widget._tasksService.getTotalCompletedTasks();
    setState(() {
      _totalCompleted = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2.0, bottom: 2.0),
          child: Text(
            'Completed tasks counter',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        FutureBuilder<int>(
          future: _totalCompleted,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            } else if (snapshot.hasError) {
              return const Text(
                'Failed to load',
                style: TextStyle(fontSize: 16, color: Colors.red),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                '${snapshot.data ?? 0}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
