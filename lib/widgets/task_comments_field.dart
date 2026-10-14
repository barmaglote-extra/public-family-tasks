import 'package:flutter/material.dart';

class TaskCommentsField extends StatelessWidget {
  final TextEditingController controller;
  const TaskCommentsField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
      ),
      autofocus: false,
      textInputAction: TextInputAction.newline,
      style: TextStyle(fontSize: 18),
      maxLines: 4,
    );
  }
}
