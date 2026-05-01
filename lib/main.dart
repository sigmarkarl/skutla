import 'package:flutter/material.dart';

import 'models/messages.dart';
import 'screens/driver_screen.dart';
import 'screens/passenger_screen.dart';
import 'screens/role_selection_screen.dart';
import 'services/identity_service.dart';

void main() {
  runApp(const SkutlaApp());
}

class SkutlaApp extends StatelessWidget {
  const SkutlaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skutla',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const _Bootstrap(),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  final _identity = IdentityService();
  String? _peerId;
  Role? _role;
  String? _name;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await _identity.getOrCreatePeerId();
    final role = await _identity.readRole();
    final name = await _identity.readName();
    if (!mounted) return;
    setState(() {
      _peerId = id;
      _role = role;
      _name = name;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _peerId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_role == null || _name == null || _name!.isEmpty) {
      return RoleSelectionScreen(peerId: _peerId!);
    }
    return _role == Role.driver
        ? DriverScreen(peerId: _peerId!, displayName: _name!)
        : PassengerScreen(peerId: _peerId!, displayName: _name!);
  }
}
