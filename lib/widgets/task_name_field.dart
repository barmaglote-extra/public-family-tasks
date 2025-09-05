import 'package:flutter/material.dart';

class TaskNameField extends StatelessWidget {
  final TextEditingController controller;
  const TaskNameField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
      ),
      autofocus: true,
      textInputAction: TextInputAction.done,
      style: TextStyle(fontSize: 18),
    );
  }
}
