import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DatePickerField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const DatePickerField({super.key, required this.controller, required this.label});

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  DateTime? selectedDate;

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
    );

    setState(() {
      selectedDate = pickedDate;
      widget.controller.text = selectedDate == null ? '' : DateFormat('yyyy-MM-dd').format(selectedDate!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.calendar_today),
        ),
      readOnly: true,
      onTap: _selectDate,
    );
  }
}