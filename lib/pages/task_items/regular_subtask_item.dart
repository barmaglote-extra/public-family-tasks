import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tasks/models/subtodo.dart';
import 'package:tasks/models/todo_collection.dart';

class RegularSubTaskItem extends StatelessWidget {
  final SubTodo task;
  final ToDoCollection? collection;
  final Function(bool?, int?) onTaskStateChanged;
  final Function(int) onTaskTap;

  const RegularSubTaskItem({
    super.key,
    required this.task,
    required this.onTaskStateChanged,
    required this.onTaskTap,
    required this.collection,
  });

  String _daysDifferenceText(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference.abs() < 60) {
      return '$difference d.';
    } else if (difference.abs() < 730) {
      final months = (difference / 30).round();
      return '$months m.';
    } else {
      final years = (difference / 365).round();
      return '$years y.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dueDate = task.dueDate;

    Color borderColor = Colors.grey;

    if (dueDate != null) {
      final isOverdue = dueDate.isBefore(now);
      final isToday = dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day;

      if (isToday) {
        borderColor = Colors.yellow;
      } else if (isOverdue) {
        borderColor = Colors.red;
      }
    }

    bool showCollection = collection != null && collection!.id != 0;

    Widget urgencyIcon = Row(
      children: [
        Text(
          '!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: task.urgency == 2 ? Colors.red : Colors.orange,
          ),
        ),
      ],
    );

    Widget urgencyPlaceholder = const SizedBox(width: 6);

    Widget listTile = ListTile(
      title: Text(
        task.name,
        style: TextStyle(
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: Text(
        task.dueDate != null
            ? (showCollection ? _daysDifferenceText(task.dueDate!) : DateFormat('dd.MM.yyyy').format(task.dueDate!))
            : '',
      ),
      subtitle: task.description != null && task.description!.isNotEmpty
          ? Text(
              task.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                decorationStyle: TextDecorationStyle.wavy,
              ),
            )
          : null,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 0,
        children: [
          (task.urgency == 0 || task.urgency == null) ? urgencyPlaceholder : urgencyIcon,
          Checkbox(
            visualDensity: VisualDensity.compact,
            value: task.isCompleted,
            onChanged: (bool? value) => onTaskStateChanged(value, task.id),
          ),
        ],
      ),
      onTap: () => onTaskTap(task.id),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        boxShadow: const [
          BoxShadow(
            blurStyle: BlurStyle.outer,
            color: Colors.black12,
            spreadRadius: 0,
            blurRadius: 1,
            offset: Offset(0, 0),
          ),
        ],
        border: Border(
          left: BorderSide(
            color: borderColor,
            width: 4.0,
          ),
        ),
      ),
      child: showCollection
          ? Row(
              children: [
                Expanded(
                  flex: 3,
                  child: listTile,
                ),
                Container(
                  width: 90,
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: Colors.black12)),
                  ),
                  child: Text(
                    collection!.name,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            )
          : listTile,
    );
  }
}
