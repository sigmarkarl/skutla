import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/messages.dart';
import '../models/ride_record.dart';
import '../services/pricing.dart';
import '../services/ride_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _store = RideHistoryStore();
  List<RideRecord>? _rides;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rides = await _store.all();
    if (!mounted) return;
    setState(() => _rides = rides);
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This removes all ride records on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _store.clear();
      _load();
    }
  }

  String _fmtDur(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    final h = d.inHours;
    final m = d.inMinutes - h * 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final rides = _rides;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride history'),
        actions: [
          if (rides != null && rides.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: rides == null
          ? const Center(child: CircularProgressIndicator())
          : rides.isEmpty
              ? const Center(child: Text('No completed rides yet.'))
              : ListView.separated(
                  itemCount: rides.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = rides[i];
                    final iconData = r.role == Role.driver
                        ? Icons.directions_car
                        : Icons.person_pin_circle;
                    final asLabel = r.role == Role.driver
                        ? 'as Driver'
                        : 'as Passenger';
                    final price = (r.price != null && r.currency != null)
                        ? Pricing.round(r.price!, r.currency!)
                        : null;
                    final when = DateFormat.yMMMd().add_Hm().format(r.endedAt);
                    return ListTile(
                      leading: Icon(iconData),
                      title: Text(
                        '${r.counterpartyName ?? r.counterpartyId.substring(0, 8)} · $asLabel',
                      ),
                      subtitle: Text(
                        '$when · ${_fmtDur(r.duration)}'
                        '${price != null ? ' · $price' : ''}',
                      ),
                    );
                  },
                ),
    );
  }
}
