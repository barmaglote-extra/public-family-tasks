import 'package:flutter/material.dart';
import 'package:tasks/widgets/localized_text.dart';

class TaskTypeDropdown extends StatelessWidget {
  final String currentType;
  final ValueChanged<String?> onChanged;
  const TaskTypeDropdown({super.key, required this.currentType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black54, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: DropdownButton<String>(
          alignment: Alignment.center,
          borderRadius: BorderRadius.circular(5),
          value: currentType,
          onChanged: onChanged,
          underline: SizedBox.shrink(),
          isExpanded: true,
          hint: Text(context.tr('tasks.select_type'), style: TextStyle(color: Colors.black)),
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          items: <String>['regular', 'recurrent'].map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child:
                  Text(value == 'regular' ? context.tr('tasks.one_time_tasks') : context.tr('tasks.recurring_tasks')),
            );
          }).toList(),
        ));
  }
}
