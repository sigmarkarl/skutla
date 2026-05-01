import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/backup_service.dart';

/// Returns true if a restore was applied (caller should reload state).
Future<bool> showBackupDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => const _BackupDialog(),
  );
  return result == true;
}

class _BackupDialog extends StatefulWidget {
  const _BackupDialog();

  @override
  State<_BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<_BackupDialog>
    with SingleTickerProviderStateMixin {
  final _service = BackupService();
  final _restoreController = TextEditingController();
  late final TabController _tabs;
  String? _backup;
  String? _restoreError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _service.export().then((s) {
      if (mounted) setState(() => _backup = s);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _restoreController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    if (_backup == null) return;
    await Clipboard.setData(ClipboardData(text: _backup!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup copied to clipboard')),
    );
  }

  Future<void> _restore() async {
    final raw = _restoreController.text.trim();
    if (raw.isEmpty) return;
    final ok = await _service.import(raw);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _restoreError = 'Could not parse backup. Check the text.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Identity backup'),
      content: SizedBox(
        width: 480,
        height: 360,
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Backup'),
                Tab(text: 'Restore'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildBackup(),
                  _buildRestore(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildBackup() {
    if (_backup == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Save this string. Paste it into another device to restore your identity, ratings, and ride history.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _backup!,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _copy,
          icon: const Icon(Icons.copy),
          label: const Text('Copy'),
        ),
      ],
    );
  }

  Widget _buildRestore() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Paste a backup string from another device. This will overwrite the data on this device.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: _restoreController,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              hintText: '{"v":1,"data":{...}}',
              border: const OutlineInputBorder(),
              errorText: _restoreError,
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            onChanged: (_) {
              if (_restoreError != null) {
                setState(() => _restoreError = null);
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _restore,
          icon: const Icon(Icons.restore),
          label: const Text('Restore identity'),
        ),
      ],
    );
  }
}
