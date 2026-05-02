import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../models/messages.dart';
import '../models/ratings.dart';
import '../models/ride_record.dart';
import '../services/external_maps.dart';
import '../services/geocoding.dart';
import '../services/geohash.dart';
import '../services/identity_service.dart';
import '../services/ride_history.dart';
import 'backup_dialog.dart';
import 'history_screen.dart';
import '../services/location_service.dart';
import '../services/notifier.dart';
import '../services/p2p_service.dart';
import '../services/pricing.dart';
import '../services/rating_store.dart';
import 'rating_dialog.dart';
import 'role_selection_screen.dart';

class PassengerScreen extends StatefulWidget {
  const PassengerScreen({
    super.key,
    required this.peerId,
    required this.displayName,
  });

  final String peerId;
  final String displayName;

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  late final P2PService _p2p;
  final _location = LocationService();
  final _map = MapController();
  final _bidsScroll = ScrollController();
  final _ratings = RatingStore();
  final _history = RideHistoryStore();
  RatingSummary _mySummary = RatingSummary.empty;

  StreamSubscription<Position>? _posSub;
  StreamSubscription<DriverPresence>? _driversSub;
  StreamSubscription<InboxMessage>? _inboxSub;
  StreamSubscription<bool>? _connSub;
  Timer? _staleTimer;

  Position? _last;
  bool _connected = false;
  String? _searchCell;
  LatLng? _destination;
  String _currency = Pricing.detectCurrency();

  final Map<String, DriverPresence> _drivers = {};

  String? _pendingRideId;
  bool _broadcasting = false;
  Timer? _broadcastTimeout;
  final Map<String, InboxMessage> _bids = {};

  String? _activeDriverId;
  String? _activeDriverName;
  String? _activeRideId;
  String? _selectedBidId;
  LatLng? _activeDriverLocation;
  CarInfo? _activeDriverCar;
  ContactInfo? _activeDriverContact;
  PaymentInfo? _activeDriverPayment;
  double? _activePrice;
  String? _activeCurrency;
  DateTime? _activeStartedAt;

  @override
  void initState() {
    super.initState();
    _p2p = P2PService(peerId: widget.peerId);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Notifier.init();
    _mySummary = await _ratings.summary();

    final ok = await _location.ensurePermission();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission required.')),
      );
    }

    _connSub = _p2p.connectionState.listen((c) {
      if (mounted) setState(() => _connected = c);
    });
    _driversSub = _p2p.driverUpdates.listen((p) {
      setState(() => _drivers[p.driverId] = p);
    });
    _inboxSub = _p2p.inbox.listen(_onInbox);

    await _p2p.connect();
    if (mounted) setState(() => _connected = _p2p.isConnected);
    _p2p.subscribeToOwnInbox();

    final initial = await _location.currentPosition();
    if (initial != null && mounted) {
      setState(() => _last = initial);
      _refreshSearchArea(initial);
      if (initial.latitude != 0 || initial.longitude != 0) {
        _map.move(LatLng(initial.latitude, initial.longitude), 14);
        _resolveCurrency(initial);
      }
    }

    _posSub = _location.positionStream().listen((pos) {
      _last = pos;
      _refreshSearchArea(pos);
      if (_activeRideId != null && _activeDriverId != null) {
        _p2p.sendInbox(InboxMessage(
          kind: InboxKind.locationUpdate,
          fromId: widget.peerId,
          fromName: widget.displayName,
          toId: _activeDriverId!,
          rideId: _activeRideId,
          lat: pos.latitude,
          lng: pos.longitude,
        ));
      }
      if (mounted) setState(() {});
    });

    _staleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      setState(() {
        _drivers.removeWhere((_, p) => now.difference(p.updatedAt).inSeconds > 25);
      });
    });
  }

  void _refreshSearchArea(Position pos) {
    final cell = encodeGeohash(pos.latitude, pos.longitude);
    if (cell == _searchCell) return;
    _searchCell = cell;
    _p2p.updatePassengerSearchArea(pos.latitude, pos.longitude);
  }

  Future<void> _resolveCurrency(Position pos) async {
    final country = await Geocoding.reverseCountryCode(pos.latitude, pos.longitude);
    if (country == null || !mounted) return;
    final c = Pricing.currencyForCountry(country);
    if (c != _currency) {
      setState(() => _currency = c);
    }
  }

  void _onInbox(InboxMessage msg) {
    switch (msg.kind) {
      case InboxKind.rideOffer:
        if (msg.rideId != _pendingRideId || _activeRideId != null) return;
        setState(() => _bids[msg.fromId] = msg);
        final priceLabel = (msg.price != null && msg.currency != null)
            ? Pricing.round(msg.price!, msg.currency!)
            : '';
        Notifier.notify(
          title: 'New offer from ${msg.fromName ?? 'a driver'}',
          body: priceLabel.isEmpty ? 'Tap to review' : 'Price: $priceLabel',
          id: msg.fromId.hashCode,
        );
        break;
      case InboxKind.locationUpdate:
        if (msg.rideId == _activeRideId &&
            msg.lat != null &&
            msg.lng != null) {
          final loc = LatLng(msg.lat!, msg.lng!);
          final wasNull = _activeDriverLocation == null;
          setState(() => _activeDriverLocation = loc);
          if (wasNull) _fitToRide();
        }
        break;
      case InboxKind.cancel:
        if (msg.rideId == _activeRideId) {
          _endRide(notifyOther: false);
        }
        break;
      case InboxKind.rating:
        _onRatingReceived(msg);
        break;
      case InboxKind.rideRequest:
      case InboxKind.rideResponse:
        break;
    }
  }

  Future<void> _onRatingReceived(InboxMessage msg) async {
    final score = msg.score;
    if (score == null || score < 1 || score > 5) return;
    final added = await _ratings.add(RatingRecord(
      fromId: msg.fromId,
      fromName: msg.fromName,
      score: score,
      comment: msg.note,
      when: DateTime.now(),
      rideId: msg.rideId,
    ));
    if (!added) return;
    _mySummary = await _ratings.summary();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${msg.fromName ?? 'Driver'} rated you $score★'),
      ),
    );
  }

  Future<void> _requestRide() async {
    if (_last == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for your location…')),
      );
      return;
    }
    if (_destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap the map to set a destination first.')),
      );
      return;
    }
    if (_broadcasting || _activeRideId != null) return;

    final cell = encodeGeohash(_last!.latitude, _last!.longitude);
    final rideId = const Uuid().v4();
    setState(() {
      _broadcasting = true;
      _pendingRideId = rideId;
      _bids.clear();
    });

    final request = InboxMessage(
      kind: InboxKind.rideRequest,
      fromId: widget.peerId,
      fromName: widget.displayName,
      toId: '',
      rideId: rideId,
      lat: _last!.latitude,
      lng: _last!.longitude,
      destLat: _destination!.latitude,
      destLng: _destination!.longitude,
      currency: _currency,
      fromAvgRating: _mySummary.count > 0 ? _mySummary.average : null,
      fromRatingCount: _mySummary.count > 0 ? _mySummary.count : null,
    );

    _p2p.broadcastRideRequest(request, cell);

    _broadcastTimeout?.cancel();
    _broadcastTimeout = Timer(const Duration(seconds: 60), () {
      if (!mounted || _activeRideId != null) return;
      if (_bids.isEmpty) {
        _cancelBroadcast(reason: 'No drivers responded.');
      }
    });
  }

  void _cancelBroadcast({String? reason}) {
    _broadcastTimeout?.cancel();
    final rideId = _pendingRideId;
    final bidders = _bids.keys.toList();
    setState(() {
      _broadcasting = false;
      _pendingRideId = null;
      _bids.clear();
    });
    for (final driverId in bidders) {
      _p2p.sendInbox(InboxMessage(
        kind: InboxKind.rideResponse,
        fromId: widget.peerId,
        fromName: widget.displayName,
        toId: driverId,
        rideId: rideId,
        accepted: false,
        note: 'cancelled',
      ));
    }
    if (reason != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason)),
      );
    }
  }

  void _acceptBid(InboxMessage bid) {
    if (_activeRideId != null) return;
    final rideId = _pendingRideId;
    if (rideId == null || rideId != bid.rideId) return;

    final losers = _bids.keys.where((id) => id != bid.fromId).toList();

    setState(() {
      _activeDriverId = bid.fromId;
      _activeDriverName = bid.fromName;
      _activeDriverCar = bid.fromCar;
      _activeDriverContact = bid.fromContact;
      _activeDriverPayment = bid.fromPayment;
      _activeRideId = rideId;
      _activePrice = bid.price;
      _activeCurrency = bid.currency ?? _currency;
      _activeStartedAt = DateTime.now();
      _broadcasting = false;
      _bids.clear();
    });
    _broadcastTimeout?.cancel();

    _p2p.sendInbox(InboxMessage(
      kind: InboxKind.rideResponse,
      fromId: widget.peerId,
      fromName: widget.displayName,
      toId: bid.fromId,
      rideId: rideId,
      accepted: true,
    ));
    for (final loser in losers) {
      _p2p.sendInbox(InboxMessage(
        kind: InboxKind.rideResponse,
        fromId: widget.peerId,
        fromName: widget.displayName,
        toId: loser,
        rideId: rideId,
        accepted: false,
        note: 'another driver was selected',
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ride confirmed with ${bid.fromName ?? 'driver'}')),
    );
  }

  void _endRide({bool notifyOther = true}) {
    final endedRideId = _activeRideId;
    final endedDriverId = _activeDriverId;
    final endedDriverName = _activeDriverName;
    final endedPrice = _activePrice;
    final endedCurrency = _activeCurrency;
    final endedDestination = _destination;
    final endedPickup = _last;
    final startedAt = _activeStartedAt;

    if (notifyOther && endedRideId != null && endedDriverId != null) {
      _p2p.sendInbox(InboxMessage(
        kind: InboxKind.cancel,
        fromId: widget.peerId,
        fromName: widget.displayName,
        toId: endedDriverId,
        rideId: endedRideId,
      ));
    }
    setState(() {
      _activeDriverId = null;
      _activeDriverName = null;
      _activeRideId = null;
      _activeDriverLocation = null;
      _activeDriverCar = null;
      _activeDriverContact = null;
      _activeDriverPayment = null;
      _activePrice = null;
      _activeCurrency = null;
      _activeStartedAt = null;
      _destination = null;
    });

    if (endedRideId != null && endedDriverId != null) {
      _history.add(RideRecord(
        rideId: endedRideId,
        role: Role.passenger,
        counterpartyId: endedDriverId,
        counterpartyName: endedDriverName,
        startedAt: startedAt ?? DateTime.now(),
        endedAt: DateTime.now(),
        pickupLat: endedPickup?.latitude,
        pickupLng: endedPickup?.longitude,
        destLat: endedDestination?.latitude,
        destLng: endedDestination?.longitude,
        price: endedPrice,
        currency: endedCurrency,
      ));
    }

    if (endedRideId != null && endedDriverId != null) {
      _promptRating(
        rideId: endedRideId,
        counterpartyId: endedDriverId,
        counterpartyName: endedDriverName,
      );
    }
  }

  Future<void> _promptRating({
    required String rideId,
    required String counterpartyId,
    String? counterpartyName,
  }) async {
    if (!mounted) return;
    final result = await showRatingDialog(context,
        counterpartyName: counterpartyName ?? 'driver');
    if (result == null) return;
    _p2p.sendInbox(InboxMessage(
      kind: InboxKind.rating,
      fromId: widget.peerId,
      fromName: widget.displayName,
      toId: counterpartyId,
      rideId: rideId,
      score: result.score,
      note: result.comment,
    ));
  }

  Future<void> _switchRole() async {
    await IdentityService().clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RoleSelectionScreen(peerId: widget.peerId),
      ),
    );
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    _broadcastTimeout?.cancel();
    _posSub?.cancel();
    _driversSub?.cancel();
    _inboxSub?.cancel();
    _connSub?.cancel();
    _bidsScroll.dispose();
    _p2p.dispose();
    super.dispose();
  }

  void _fitToRide() {
    if (_last == null || _activeDriverLocation == null) return;
    final passenger = LatLng(_last!.latitude, _last!.longitude);
    final bounds = LatLngBounds.fromPoints([passenger, _activeDriverLocation!]);
    _map.fitCamera(CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(80),
    ));
  }

  double? _driverDistanceMeters() {
    if (_last == null || _activeDriverLocation == null) return null;
    return Geolocator.distanceBetween(
      _last!.latitude,
      _last!.longitude,
      _activeDriverLocation!.latitude,
      _activeDriverLocation!.longitude,
    );
  }

  void _scrollBidIntoView(String bidId) {
    final ids = _bids.keys.toList();
    final idx = ids.indexOf(bidId);
    if (idx < 0 || !_bidsScroll.hasClients) return;
    const cardWidth = 240.0 + 8.0;
    final target = idx * cardWidth;
    final maxScroll = _bidsScroll.position.maxScrollExtent;
    _bidsScroll.animateTo(
      target.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _last != null
        ? LatLng(_last!.latitude, _last!.longitude)
        : const LatLng(64.1466, -21.9426);

    final visibleDrivers = _drivers.values.where((d) => d.available).toList();

    final markers = <Marker>[
      if (_last != null)
        Marker(
          point: LatLng(_last!.latitude, _last!.longitude),
          width: 44,
          height: 44,
          child:
              const Icon(Icons.person_pin_circle, size: 36, color: Colors.red),
        ),
      if (_destination != null)
        Marker(
          point: _destination!,
          width: 64,
          height: 64,
          child: _activeRideId != null
              ? GestureDetector(
                  onTap: () => openDirections(
                    lat: _destination!.latitude,
                    lng: _destination!.longitude,
                  ),
                  child: const Tooltip(
                    message: 'Open in Maps',
                    child: Icon(Icons.flag,
                        size: 36, color: Colors.deepPurple),
                  ),
                )
              : const Icon(Icons.flag, size: 36, color: Colors.deepPurple),
        ),
      ...visibleDrivers.map((d) {
        final bid = _bids[d.driverId];
        final isBidder = bid != null;
        final isSelected = _selectedBidId == d.driverId;
        final dimNonBidders = _broadcasting && !isBidder;
        final color = isBidder
            ? (isSelected ? Colors.green.shade700 : Colors.green)
            : Colors.blueAccent;
        final size = isSelected ? 48.0 : (isBidder ? 42.0 : 36.0);
        return Marker(
          point: LatLng(d.lat, d.lng),
          width: 80,
          height: 80,
          child: Opacity(
            opacity: dimNonBidders ? 0.35 : 1,
            child: GestureDetector(
              onTap: isBidder
                  ? () {
                      final willSelect = !isSelected;
                      setState(() => _selectedBidId =
                          willSelect ? d.driverId : null);
                      _map.move(LatLng(d.lat, d.lng), 14);
                      if (willSelect) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _scrollBidIntoView(d.driverId),
                        );
                      }
                    }
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bid != null && bid.price != null && bid.currency != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.green.shade700 : Colors.green,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(blurRadius: 2, color: Colors.black26),
                        ],
                      ),
                      child: Text(
                        Pricing.round(bid.price!, bid.currency!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Icon(Icons.directions_car, size: size, color: color),
                ],
              ),
            ),
          ),
        );
      }),
      if (_activeDriverLocation != null)
        Marker(
          point: _activeDriverLocation!,
          width: 50,
          height: 50,
          child: const Icon(Icons.directions_car,
              size: 40, color: Colors.green),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_mySummary.formatted() != null
            ? 'Passenger · ${widget.displayName} · ${_mySummary.formatted()}'
            : 'Passenger · ${widget.displayName}'),
        actions: [
          IconButton(
            tooltip: 'Ride history',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Backup / Restore',
            icon: const Icon(Icons.vpn_key),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final restored = await showBackupDialog(context);
              if (!mounted || !restored) return;
              navigator.pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      RoleSelectionScreen(peerId: widget.peerId),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Switch role',
            icon: const Icon(Icons.swap_horiz),
            onPressed: _switchRole,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 14,
                    onTap: _activeRideId == null
                        ? (_, point) {
                            setState(() => _destination = point);
                          }
                        : null,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'is.skutla.app',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _StatusCard(
                    connected: _connected,
                    driverCount: visibleDrivers.length,
                    hasDestination: _destination != null,
                    onClearDestination: _destination == null
                        ? null
                        : () => setState(() => _destination = null),
                  ),
                ),
                if (_activeRideId != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _ActiveRideCard(
                      driverLabel: _activeDriverName ??
                          _activeDriverId!.substring(0, 8),
                      car: _activeDriverCar,
                      contact: _activeDriverContact,
                      payment: _activeDriverPayment,
                      price: _activePrice,
                      currency: _activeCurrency,
                      driverDistanceMeters: _driverDistanceMeters(),
                      canRecenter: _activeDriverLocation != null &&
                          _last != null,
                      onRecenter: _fitToRide,
                      onEnd: _endRide,
                      onOpenMaps: _destination == null
                          ? null
                          : () => openDirections(
                                lat: _destination!.latitude,
                                lng: _destination!.longitude,
                              ),
                    ),
                  ),
              ],
            ),
          ),
          if (_activeRideId == null)
            _BottomPanel(
              broadcasting: _broadcasting,
              hasDestination: _destination != null,
              hasLocation: _last != null,
              bids: _bids.values.toList(),
              myPos: _last,
              selectedBidId: _selectedBidId,
              scrollController: _bidsScroll,
              onRequest: _requestRide,
              onCancel: () => _cancelBroadcast(),
              onSelect: (bid) {
                setState(() => _selectedBidId =
                    _selectedBidId == bid.fromId ? null : bid.fromId);
                if (bid.lat != null && bid.lng != null) {
                  _map.move(LatLng(bid.lat!, bid.lng!), 14);
                }
              },
              onAccept: _acceptBid,
            ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.broadcasting,
    required this.hasDestination,
    required this.hasLocation,
    required this.bids,
    required this.myPos,
    required this.selectedBidId,
    required this.scrollController,
    required this.onRequest,
    required this.onCancel,
    required this.onSelect,
    required this.onAccept,
  });
  final bool broadcasting;
  final bool hasDestination;
  final bool hasLocation;
  final List<InboxMessage> bids;
  final Position? myPos;
  final String? selectedBidId;
  final ScrollController scrollController;
  final VoidCallback onRequest;
  final VoidCallback onCancel;
  final ValueChanged<InboxMessage> onSelect;
  final ValueChanged<InboxMessage> onAccept;

  @override
  Widget build(BuildContext context) {
    if (!broadcasting) {
      final canRequest = hasDestination && hasLocation;
      String label = 'Request ride';
      if (!hasLocation) {
        label = 'Waiting for your location…';
      } else if (!hasDestination) {
        label = 'Set a destination';
      }
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.local_taxi),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(label),
            ),
            onPressed: canRequest ? onRequest : null,
          ),
        ),
      );
    }
    return SizedBox(
      height: 240,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(bids.isEmpty
                      ? 'Waiting for offers…'
                      : '${bids.length} offer${bids.length == 1 ? '' : 's'} — pick one'),
                ),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
          ),
          Expanded(
            child: bids.isEmpty
                ? const Center(
                    child: Text('Drivers nearby will see your request soon…'),
                  )
                : ListView.separated(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemCount: bids.length,
                    itemBuilder: (_, i) => _BidCard(
                      bid: bids[i],
                      myPos: myPos,
                      selected: selectedBidId == bids[i].fromId,
                      onSelect: () => onSelect(bids[i]),
                      onAccept: () => onAccept(bids[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BidCard extends StatelessWidget {
  const _BidCard({
    required this.bid,
    required this.myPos,
    required this.selected,
    required this.onSelect,
    required this.onAccept,
  });
  final InboxMessage bid;
  final Position? myPos;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final price = bid.price;
    final currency = bid.currency;
    final priceLabel = (price != null && currency != null)
        ? Pricing.round(price, currency)
        : '—';
    final ratingLabel =
        (bid.fromAvgRating != null && (bid.fromRatingCount ?? 0) > 0)
            ? '${bid.fromAvgRating!.toStringAsFixed(1)} ★ (${bid.fromRatingCount})'
            : 'New';
    final car = bid.fromCar;

    return SizedBox(
      width: 240,
      child: Card(
        elevation: selected ? 8 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(color: Colors.green.shade700, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onSelect,
          child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_car,
                      color: selected ? Colors.green.shade700 : Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bid.fromName ?? bid.fromId.substring(0, 8),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(priceLabel,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text(ratingLabel,
                  style: Theme.of(context).textTheme.bodySmall),
              if (car != null && car.isComplete)
                Text(car.summary,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontStyle: FontStyle.italic)),
              if (bid.fromContact != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _ContactButtons(contact: bid.fromContact!),
                ),
              if (bid.fromPayment != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _PaymentButtons(
                    payment: bid.fromPayment!,
                    price: bid.price,
                    currency: bid.currency,
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.connected,
    required this.driverCount,
    required this.hasDestination,
    this.onClearDestination,
  });
  final bool connected;
  final int driverCount;
  final bool hasDestination;
  final VoidCallback? onClearDestination;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle,
                    size: 12, color: connected ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Text(connected ? 'Connected' : 'Connecting…'),
                const Spacer(),
                Text('$driverCount drivers nearby'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.flag,
                    size: 14,
                    color: hasDestination ? Colors.deepPurple : Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasDestination
                        ? 'Destination set'
                        : 'Tap the map to set a destination',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (onClearDestination != null)
                  TextButton(
                    onPressed: onClearDestination,
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveRideCard extends StatelessWidget {
  const _ActiveRideCard({
    required this.driverLabel,
    required this.onEnd,
    this.onOpenMaps,
    this.car,
    this.contact,
    this.payment,
    this.price,
    this.currency,
    this.driverDistanceMeters,
    this.canRecenter = false,
    this.onRecenter,
  });
  final String driverLabel;
  final VoidCallback onEnd;
  final VoidCallback? onOpenMaps;
  final CarInfo? car;
  final ContactInfo? contact;
  final PaymentInfo? payment;
  final double? price;
  final String? currency;
  final double? driverDistanceMeters;
  final bool canRecenter;
  final VoidCallback? onRecenter;

  @override
  Widget build(BuildContext context) {
    final dist = driverDistanceMeters;
    final distLabel = dist == null
        ? null
        : (dist < 1000
            ? '${dist.round()} m away'
            : '${(dist / 1000).toStringAsFixed(1)} km away');

    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('On the way: $driverLabel'),
                      if (distLabel != null)
                        Text(distLabel,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (price != null && currency != null) ...[
                  Text(Pricing.round(price!, currency!),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 4),
                ],
                if (canRecenter && onRecenter != null) ...[
                  IconButton(
                    tooltip: 'Center map on ride',
                    icon: const Icon(Icons.my_location),
                    onPressed: onRecenter,
                  ),
                ],
                if (onOpenMaps != null)
                  IconButton(
                    tooltip: 'Open destination in Maps',
                    icon: const Icon(Icons.directions),
                    onPressed: onOpenMaps,
                  ),
                const SizedBox(width: 4),
                FilledButton.tonal(
                  onPressed: onEnd,
                  child: const Text('End ride'),
                ),
              ],
            ),
            if (car != null && car!.isComplete) ...[
              const SizedBox(height: 4),
              Text('Look for: ${car!.summary}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (contact != null) ...[
              const SizedBox(height: 4),
              _ContactButtons(contact: contact!),
            ],
            if (payment != null) ...[
              const SizedBox(height: 4),
              _PaymentButtons(
                payment: payment!,
                price: price,
                currency: currency,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentButtons extends StatelessWidget {
  const _PaymentButtons({
    required this.payment,
    this.price,
    this.currency,
  });
  final PaymentInfo payment;
  final double? price;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if ((payment.aur ?? '').isNotEmpty) {
      children.add(_ContactChip(
        icon: Icons.account_balance_wallet,
        label: 'Aur ${payment.aur}',
        onTap: () => openPhone(payment.aur!),
      ));
    }
    if ((payment.paypal ?? '').isNotEmpty) {
      children.add(_ContactChip(
        icon: Icons.paypal,
        label: 'PayPal',
        onTap: () => openPayPal(payment.paypal!,
            amount: price, currency: currency),
      ));
    }
    if ((payment.venmo ?? '').isNotEmpty) {
      children.add(_ContactChip(
        icon: Icons.attach_money,
        label: 'Venmo',
        onTap: () => openVenmo(payment.venmo!),
      ));
    }
    if ((payment.wechat ?? '').isNotEmpty) {
      children.add(_ContactChip(
        icon: Icons.qr_code,
        label: 'WeChat ${payment.wechat}',
        onTap: () {},
      ));
    }
    if (payment.cash == true) {
      children.add(const _ContactChip(
        icon: Icons.payments,
        label: 'Cash OK',
        onTap: _noop,
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, children: children);
  }
}

void _noop() {}

class _ContactButtons extends StatelessWidget {
  const _ContactButtons({required this.contact});
  final ContactInfo contact;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if ((contact.phone ?? '').isNotEmpty) {
      children.add(_ContactChip(
        icon: Icons.call,
        label: 'Call',
        onTap: () => openPhone(contact.phone!),
      ));
    }
    if ((contact.whatsapp ?? '').isNotEmpty) {
      children.add(_ContactChip(
        icon: Icons.chat,
        label: 'WhatsApp',
        onTap: () => openWhatsApp(contact.whatsapp!),
      ));
    }
    if ((contact.messenger ?? '').isNotEmpty) {
      children.add(_ContactChip(
        icon: Icons.message,
        label: 'Messenger',
        onTap: () => openMessenger(contact.messenger!),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: children,
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
