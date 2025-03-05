import 'package:flutter/material.dart';

class JsonEditorWidget extends StatefulWidget {
  final String initialJson;
  final Function(String) onJsonChanged;
  final VoidCallback onApply;

  const JsonEditorWidget({
    super.key,
    required this.initialJson,
    required this.onJsonChanged,
    required this.onApply,
  });

  @override
  State<JsonEditorWidget> createState() => _JsonEditorWidgetState();
}

class _JsonEditorWidgetState extends State<JsonEditorWidget> {
  late TextEditingController _jsonController;

  @override
  void initState() {
    super.initState();
    _jsonController = TextEditingController(text: widget.initialJson);
    _jsonController.addListener(_onJsonChanged);
  }

  @override
  void didUpdateWidget(JsonEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialJson != widget.initialJson) {
      _jsonController.text = widget.initialJson;
    }
  }

  void _onJsonChanged() {
    widget.onJsonChanged(_jsonController.text);
  }

  @override
  void dispose() {
    _jsonController.removeListener(_onJsonChanged);
    _jsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onApply,
                  child: const Text('Apply JSON Changes'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _jsonController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Edit JSON here',
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }
}
