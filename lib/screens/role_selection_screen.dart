import 'package:flutter/material.dart';

import '../models/messages.dart';
import '../services/identity_service.dart';
import 'backup_dialog.dart';
import 'driver_screen.dart';
import 'passenger_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, required this.peerId});

  final String peerId;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _identity = IdentityService();
  final _nameController = TextEditingController();
  String _peerId = '';

  @override
  void initState() {
    super.initState();
    _peerId = widget.peerId;
    _identity.readName().then((value) {
      if (value != null && mounted) {
        _nameController.text = value;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continueAs(Role role) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a display name first.')),
      );
      return;
    }
    await _identity.writeName(name);
    await _identity.writeRole(role);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => role == Role.driver
            ? DriverScreen(peerId: _peerId, displayName: name)
            : PassengerScreen(peerId: _peerId, displayName: name),
      ),
    );
  }

  Future<void> _openBackup() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final restored = await showBackupDialog(context);
    if (!restored || !mounted) return;
    final newId = await _identity.getOrCreatePeerId();
    final newName = await _identity.readName() ?? '';
    final newRole = await _identity.readRole();
    if (!mounted) return;
    setState(() {
      _peerId = newId;
      _nameController.text = newName;
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Identity restored.')),
    );
    if (newRole != null && newName.isNotEmpty) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => newRole == Role.driver
              ? DriverScreen(peerId: newId, displayName: newName)
              : PassengerScreen(peerId: newId, displayName: newName),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortId = _peerId.substring(0, 8);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skutla'),
        actions: [
          IconButton(
            tooltip: 'Backup / Restore',
            icon: const Icon(Icons.vpn_key),
            onPressed: _openBackup,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Decentralized rides',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your peer id: $shortId…',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.directions_car),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Continue as Driver'),
              ),
              onPressed: () => _continueAs(Role.driver),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_pin_circle),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Continue as Passenger'),
              ),
              onPressed: () => _continueAs(Role.passenger),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _openBackup,
              icon: const Icon(Icons.vpn_key, size: 18),
              label: const Text('Backup or restore identity'),
            ),
          ],
        ),
      ),
    );
  }
}
