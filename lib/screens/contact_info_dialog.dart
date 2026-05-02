import 'package:flutter/material.dart';

import '../models/messages.dart';

Future<ContactInfo?> showContactInfoDialog(
  BuildContext context, {
  ContactInfo? initial,
}) {
  return showDialog<ContactInfo>(
    context: context,
    builder: (_) => _ContactInfoDialog(initial: initial),
  );
}

class _ContactInfoDialog extends StatefulWidget {
  const _ContactInfoDialog({this.initial});
  final ContactInfo? initial;

  @override
  State<_ContactInfoDialog> createState() => _ContactInfoDialogState();
}

class _ContactInfoDialogState extends State<_ContactInfoDialog> {
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _messenger;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.initial?.phone ?? '');
    _whatsapp = TextEditingController(text: widget.initial?.whatsapp ?? '');
    _messenger = TextEditingController(text: widget.initial?.messenger ?? '');
  }

  @override
  void dispose() {
    _phone.dispose();
    _whatsapp.dispose();
    _messenger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contact info'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0FB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Anything you fill in here will be shared with the driver or '
              'passenger you match with. Leave blank to share nothing.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              hintText: '+354 1234567',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp number',
              hintText: '+354 1234567',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messenger,
            decoration: const InputDecoration(
              labelText: 'Messenger username',
              hintText: 'your.handle',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final info = ContactInfo(
              phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              whatsapp:
                  _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
              messenger: _messenger.text.trim().isEmpty
                  ? null
                  : _messenger.text.trim(),
            );
            Navigator.of(context).pop(info);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
