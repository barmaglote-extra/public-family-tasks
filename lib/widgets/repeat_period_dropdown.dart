import 'package:flutter/material.dart';
import 'package:tasks/widgets/localized_text.dart';

class RepeatPeriodDropdown extends StatelessWidget {
  final String? selectedPeriod;
  final ValueChanged<String?> onChanged;
  const RepeatPeriodDropdown({super.key, required this.selectedPeriod, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final validPeriod = selectedPeriod != null && ['daily', 'weekly', 'monthly', 'yearly'].contains(selectedPeriod)
        ? selectedPeriod
        : null;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black54, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<String>(
        value: validPeriod,
        onChanged: onChanged,
        isExpanded: true,
        borderRadius: BorderRadius.circular(5),
        underline: const SizedBox.shrink(),
        hint: Text(context.tr('recurrence.select_period'), style: const TextStyle(color: Colors.black)),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        items: <String>['daily', 'weekly', 'monthly', 'yearly'].map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value == 'daily'
                  ? context.tr('recurrence.daily')
                  : value == 'weekly'
                      ? context.tr('recurrence.weekly')
                      : value == 'monthly'
                          ? context.tr('recurrence.monthly')
                          : context.tr('recurrence.yearly'),
            ),
          );
        }).toList(),
      ),
    );
  }
}
