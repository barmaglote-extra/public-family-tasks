import 'package:flutter/material.dart';

class TaskDescriptionField extends StatelessWidget {
  final TextEditingController controller;
  const TaskDescriptionField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
      ),
      autofocus: true,
      textInputAction: TextInputAction.newline,
      style: TextStyle(fontSize: 18),
      maxLines: 4,
    );
  }
}



