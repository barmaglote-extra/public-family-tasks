import 'package:flutter/material.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/collection_fields.dart';
import 'package:tasks/services/collections_service.dart';
import 'package:tasks/widgets/task_description_field.dart';

class EditCollectionPage extends StatefulWidget {
  final int collectionId;
  final String initialName;
  final String? description;

  const EditCollectionPage(
      {super.key, required this.collectionId, required this.initialName, required this.description});

  @override
  State<EditCollectionPage> createState() => _EditCollectionPageState();
}

class _EditCollectionPageState extends State<EditCollectionPage> {
  final _collectionsService = locator<CollectionsService>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _descriptionController.text = widget.description ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCollectionName() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    await _collectionsService.updateItemById(
      widget.collectionId,
      {CollectionFields.name: _nameController.text, CollectionFields.description: _descriptionController.text},
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Edit Collection', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveCollectionName,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Collection Name',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            const Text("Description",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            TaskDescriptionField(controller: _descriptionController),
          ],
        ),
      ),
    );
  }
}
