import 'package:flutter/material.dart';

import '../models/messages.dart';

Future<CarInfo?> showCarInfoDialog(
  BuildContext context, {
  CarInfo? initial,
  bool isFirstSetup = false,
}) {
  return showDialog<CarInfo>(
    context: context,
    barrierDismissible: !isFirstSetup,
    builder: (_) => _CarInfoDialog(initial: initial, isFirstSetup: isFirstSetup),
  );
}

class _CarInfoDialog extends StatefulWidget {
  const _CarInfoDialog({this.initial, this.isFirstSetup = false});
  final CarInfo? initial;
  final bool isFirstSetup;

  @override
  State<_CarInfoDialog> createState() => _CarInfoDialogState();
}

class _CarInfoDialogState extends State<_CarInfoDialog> {
  late final TextEditingController _makeModel;
  late final TextEditingController _color;
  late final TextEditingController _plate;

  @override
  void initState() {
    super.initState();
    _makeModel = TextEditingController(text: widget.initial?.makeModel ?? '');
    _color = TextEditingController(text: widget.initial?.color ?? '');
    _plate = TextEditingController(text: widget.initial?.plate ?? '');
  }

  @override
  void dispose() {
    _makeModel.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  bool get _valid =>
      _makeModel.text.trim().isNotEmpty &&
      _color.text.trim().isNotEmpty &&
      _plate.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isFirstSetup ? 'Your vehicle' : 'Edit vehicle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _makeModel,
            decoration: const InputDecoration(
              labelText: 'Make & model',
              hintText: 'e.g. Toyota Yaris',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _color,
            decoration: const InputDecoration(
              labelText: 'Color',
              hintText: 'e.g. Silver',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _plate,
            decoration: const InputDecoration(
              labelText: 'License plate',
              hintText: 'e.g. AB-123',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        if (!widget.isFirstSetup)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop(CarInfo(
                    makeModel: _makeModel.text.trim(),
                    color: _color.text.trim(),
                    plate: _plate.text.trim().toUpperCase(),
                  ))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
