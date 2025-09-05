import 'package:flutter/material.dart';
import 'package:tasks/app_drawer.dart';
import 'package:tasks/main.dart';
import 'package:tasks/services/collections_service.dart';
import 'package:tasks/widgets/task_description_field.dart';

class NewCollectionPage extends StatefulWidget {
  final _service = locator<CollectionsService>();
  NewCollectionPage({super.key, required this.title});

  final String title;

  @override
  State<NewCollectionPage> createState() => _NewCollectionPageState();
}

class _NewCollectionPageState extends State<NewCollectionPage> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  void _addCollection() async {
    await widget._service.addItem(_textController.text, _descriptionController.text);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  _onBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_circle_left_outlined),
            onPressed: _onBack,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _addCollection,
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'New Collection',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              TextField(
                controller: _textController,
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
      ),
    );
  }
}
