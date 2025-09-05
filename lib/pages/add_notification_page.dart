import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/todo.dart';
import 'package:tasks/services/notification_service.dart';
import 'package:tasks/widgets/task_description_field.dart';
import 'package:tasks/widgets/task_name_field.dart';

class AddNotificationPage extends StatefulWidget {
  final Todo task;
  final bool isSubTask;

  const AddNotificationPage({super.key, required this.task, required this.isSubTask});

  @override
  State<AddNotificationPage> createState() => _AddNotificationPageState();
}

class _AddNotificationPageState extends State<AddNotificationPage> {
  final _notificationService = locator<NotificationService>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now().add(const Duration(minutes: 1));

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Task: ${widget.task.name}';
    _descriptionController.text = widget.task.description ?? '';
  }

  Future<void> _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().add(const Duration(minutes: 1)),
      lastDate: DateTime(2100),
    );

    if (!mounted) {
      return;
    }

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _saveNotification() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required!')),
      );
      return;
    }

    await _notificationService.scheduleNotification(
      id: widget.task.id,
      title: _titleController.text,
      body: _descriptionController.text,
      scheduledDate: _selectedDateTime,
      payload: widget.task.id.toString(),
      isSubTask: widget.isSubTask,
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  _onBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Add Notification', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_circle_left_outlined),
            onPressed: _onBack,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNotification,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Title",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              TaskNameField(controller: _titleController),
              const SizedBox(height: 10),
              const Text(
                "Description",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              TaskDescriptionField(controller: _descriptionController),
              const SizedBox(height: 10),
              const Text(
                "Notification Date",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(_selectedDateTime),
                    style: const TextStyle(fontSize: 14),
                  ),
                  ElevatedButton(
                    onPressed: _pickDateTime,
                    child: const Text('Select Date'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
