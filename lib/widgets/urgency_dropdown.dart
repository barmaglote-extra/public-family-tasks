import 'package:flutter/material.dart';
import 'package:tasks/widgets/localized_text.dart';

class UrgencyDropdown extends StatelessWidget {
  final int? selectedUrgency;
  final ValueChanged<int?> onChanged;

  const UrgencyDropdown({super.key, required this.selectedUrgency, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black54, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: EdgeInsetsDirectional.symmetric(horizontal: 0),
      child: DropdownButton<int>(
        value: selectedUrgency,
        autofocus: true,
        onChanged: onChanged,
        hint: Text(context.tr('tasks.select_importance'), style: TextStyle(color: Colors.black)),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        isExpanded: true,
        underline: SizedBox.shrink(),
        items: <int>[0, 1, 2].map<DropdownMenuItem<int>>((int value) {
          return DropdownMenuItem<int>(
            value: value,
            child: Text(value == 0
                ? context.tr('tasks.normal')
                : value == 1
                    ? context.tr('tasks.urgent')
                    : context.tr('tasks.extra_urgent')),
          );
        }).toList(),
      ),
    );
  }
}
