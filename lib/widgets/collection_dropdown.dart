import 'package:tasks/models/todo_collection.dart';
import 'package:flutter/material.dart';

class CollectionDropdown extends StatelessWidget {
  final List<ToDoCollection> collections;
  final ToDoCollection? selectedCollection;
  final ValueChanged<ToDoCollection?> onChanged;

  const CollectionDropdown({
    super.key,
    required this.collections,
    required this.selectedCollection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black54, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<ToDoCollection>(
        alignment: Alignment.center,
        borderRadius: BorderRadius.circular(5),
        value: selectedCollection,
        onChanged: collections.isNotEmpty ? onChanged : null,
        underline: const SizedBox.shrink(),
        isExpanded: true,
        hint: Text(
          collections.isEmpty ? 'No collections available' : 'Select collection',
          style: const TextStyle(color: Colors.black),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        items: collections.isNotEmpty
            ? collections.map<DropdownMenuItem<ToDoCollection>>((ToDoCollection collection) {
                return DropdownMenuItem<ToDoCollection>(
                  value: collection,
                  child: Text(collection.name),
                );
              }).toList()
            : [
                const DropdownMenuItem<ToDoCollection>(
                  value: null,
                  child: Text('No collections'),
                ),
              ],
      ),
    );
  }
}
