import 'package:flutter/material.dart';

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
        hint: const Text('Select repeat period', style: TextStyle(color: Colors.black)),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        items: <String>['daily', 'weekly', 'monthly', 'yearly'].map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value == 'daily'
                  ? 'Daily'
                  : value == 'weekly'
                      ? 'Weekly'
                      : value == 'monthly'
                          ? 'Monthly'
                          : 'Yearly',
            ),
          );
        }).toList(),
      ),
    );
  }
}
