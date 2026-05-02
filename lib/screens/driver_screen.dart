import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/messages.dart';
import '../models/ratings.dart';
import '../services/external_maps.dart';
import '../services/geocoding.dart';
import '../services/geohash.dart';
import '../services/identity_service.dart';
import '../services/location_service.dart';
import '../services/notifier.dart';
import '../services/p2p_service.dart';
import '../services/pricing.dart';
import '../services/rating_store.dart';
import '../models/ride_record.dart';
import '../services/ride_history.dart';
import 'backup_dialog.dart';
import 'car_info_dialog.dart';
import 'chat_screen.dart';
import 'contact_info_dialog.dart';
import 'history_screen.dart';
import 'payment_dialog.dart';
import 'rating_dialog.dart';
import 'role_selection_screen.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({
    super.key,
    required this.peerId,
    required this.displayName,
  });

  final String peerId;
  final String displayName;

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  late final P2PService _p2p;
  final _location = LocationService();
  final _map = MapController();
  final _ratings = RatingStore();
  final _identity = IdentityService();
  final _history = RideHistoryStore();
  RatingSummary _mySummary = RatingSummary.empty;
  CarInfo? _car;
  ContactInfo? _contact;
  PaymentInfo? _payment;
  bool _currencyOverride = false;

  StreamSubscription<Position>? _posSub;
  StreamSubscription<InboxMessage>? _inboxSub;
  StreamSubscription<InboxMessage>? _requestsSub;
  StreamSubscription<bool>? _connSub;
  Timer? _heartbeat;
  String? _requestCell;

  Position? _last;
  bool _available = true;
  bool _connected = false;
  String _currency = Pricing.detectCurrency();

  final Map<String, _PendingBid> _pendingRequests = {};
  final ValueNotifier<List<InboxMessage>> _chat = ValueNotifier([]);

  String? _activeRideId;
  String? _activePassengerId;
  String? _activePassengerName;
  ContactInfo? _activePassengerContact;
  double? _activePrice;
  String? _activeCurrency;
  LatLng? _passengerLocation;
  LatLng? _activeDestination;
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
    _car = await _identity.readCarInfo();
    _contact = await _identity.readContactInfo();
    _payment = await _identity.readPaymentInfo();
    final saved = await _identity.readCurrency();
    if (saved != null) {
      _currency = saved;
      _currencyOverride = true;
    }

    if (_car == null && mounted) {
      final entered = await showCarInfoDialog(context, isFirstSetup: true);
      if (entered != null) {
        await _identity.writeCarInfo(entered);
        if (mounted) setState(() => _car = entered);
      }
    }

    final ok = await _location.ensurePermission();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission required.')),
      );
    }

    _connSub = _p2p.connectionState.listen((c) {
      if (mounted) setState(() => _connected = c);
    });

    await _p2p.connect();
    if (mounted) setState(() => _connected = _p2p.isConnected);
    _p2p.subscribeToOwnInbox();

    _inboxSub = _p2p.inbox.listen(_onInbox);
    _requestsSub = _p2p.rideRequests.listen(_onRideRequest);

    final initial = await _location.currentPosition();
    if (initial != null && mounted) {
      setState(() => _last = initial);
      _refreshRequestArea(initial);
      if (initial.latitude != 0 || initial.longitude != 0) {
        _map.move(LatLng(initial.latitude, initial.longitude), 14);
        _resolveCurrency(initial);
      }
    }

    _posSub = _location.positionStream().listen((pos) {
      _last = pos;
      _refreshRequestArea(pos);
      if (_activeRideId != null && _activePassengerId != null) {
        _p2p.sendInbox(InboxMessage(
          kind: InboxKind.locationUpdate,
          fromId: widget.peerId,
          fromName: widget.displayName,
          toId: _activePassengerId!,
          rideId: _activeRideId,
          lat: pos.latitude,
          lng: pos.longitude,
        ));
      }
      if (mounted) setState(() {});
    });

    _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_last != null &&
          _activeRideId != null &&
          _activePassengerId != null) {
        _p2p.sendInbox(InboxMessage(
          kind: InboxKind.locationUpdate,
          fromId: widget.peerId,
          fromName: widget.displayName,
          toId: _activePassengerId!,
          rideId: _activeRideId,
          lat: _last!.latitude,
          lng: _last!.longitude,
        ));
      }
    });
  }

  Future<void> _editCar() async {
    final updated =
        await showCarInfoDialog(context, initial: _car, isFirstSetup: false);
    if (updated == null) return;
    await _identity.writeCarInfo(updated);
    if (!mounted) return;
    setState(() => _car = updated);
  }

  Future<void> _editContact() async {
    final updated = await showContactInfoDialog(context, initial: _contact);
    if (updated == null) return;
    await _identity.writeContactInfo(updated);
    if (!mounted) return;
    setState(() => _contact = updated);
  }

  void _refreshRequestArea(Position pos) {
    final cell = encodeGeohash(pos.latitude, pos.longitude);
    if (cell == _requestCell) return;
    _requestCell = cell;
    _p2p.updateDriverRequestArea(pos.latitude, pos.longitude);
  }

  Future<void> _resolveCurrency(Position pos) async {
    if (_currencyOverride) return;
    final country = await Geocoding.reverseCountryCode(pos.latitude, pos.longitude);
    if (country == null || !mounted) return;
    final c = Pricing.currencyForCountry(country);
    if (c != _currency) {
      setState(() => _currency = c);
    }
  }

  Future<void> _editPayment() async {
    final result = await showPaymentDialog(
      context,
      initial: _payment,
      currency: _currency,
    );
    if (result == null) return;
    await _identity.writePaymentInfo(result.payment);
    await _identity.writeCurrency(result.currency);
    if (!mounted) return;
    setState(() {
      _payment = result.payment;
      _currency = result.currency;
      _currencyOverride = true;
    });
  }

  void _onRideRequest(InboxMessage msg) {
    if (msg.kind != InboxKind.rideRequest) return;
    if (_activeRideId != null) return;
    if (!_available) return;
    if (msg.rideId == null) return;
    if (_pendingRequests.containsKey(msg.rideId)) return;

    // One pending request per passenger — replace any older request from
    // this same passenger so they only ever appear once on screen.
    _pendingRequests.removeWhere((_, bid) {
      if (bid.request.fromId == msg.fromId) {
        bid.expiry?.cancel();
        return true;
      }
      return false;
    });

    final pickup = (msg.lat != null && msg.lng != null)
        ? LatLng(msg.lat!, msg.lng!)
        : null;
    final dest = (msg.destLat != null && msg.destLng != null)
        ? LatLng(msg.destLat!, msg.destLng!)
        : null;

    double pickupMeters = 0;
    if (_last != null && pickup != null) {
      pickupMeters = Geolocator.distanceBetween(
        _last!.latitude, _last!.longitude,
        pickup.latitude, pickup.longitude,
      );
    }
    double tripMeters = 0;
    if (pickup != null && dest != null) {
      tripMeters = Geolocator.distanceBetween(
        pickup.latitude, pickup.longitude,
        dest.latitude, dest.longitude,
      );
    }
    final currency = _currency;
    final defaultPrice = Pricing.estimate(
      currency: currency,
      distanceMeters: pickupMeters + tripMeters,
    );

    setState(() {
      _pendingRequests[msg.rideId!] = _PendingBid(
        request: msg,
        currency: currency,
        price: defaultPrice,
        pickupMeters: pickupMeters,
        tripMeters: tripMeters,
      );
    });

    Notifier.notify(
      title: 'Ride request from ${msg.fromName ?? 'a passenger'}',
      body:
          'Pickup ${_fmtMeters(pickupMeters)} away · Trip ${_fmtMeters(tripMeters)}',
      id: msg.rideId.hashCode,
    );
  }

  void _onInbox(InboxMessage msg) {
    switch (msg.kind) {
      case InboxKind.rideResponse:
        if (msg.rideId == null) return;
        if (msg.accepted == true) {
          if (_activeRideId != null) return;
          final bid = _pendingRequests[msg.rideId];
          if (bid == null) return;
          bid.expiry?.cancel();
          _activateRide(bid, passengerContact: msg.fromContact);
        } else {
          final removed = _pendingRequests.remove(msg.rideId);
          if (removed != null && mounted) {
            removed.expiry?.cancel();
            setState(() {});
            final reason = msg.note != null && msg.note!.isNotEmpty
                ? ' (${msg.note})'
                : '';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Bid not selected$reason.')),
            );
          }
        }
        break;
      case InboxKind.locationUpdate:
        if (msg.rideId == _activeRideId && msg.lat != null && msg.lng != null) {
          setState(() => _passengerLocation = LatLng(msg.lat!, msg.lng!));
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
      case InboxKind.chat:
        if (msg.rideId == _activeRideId &&
            (msg.note?.isNotEmpty ?? false)) {
          _chat.value = [..._chat.value, msg];
          Notifier.notify(
            title: 'Message from ${msg.fromName ?? 'passenger'}',
            body: msg.note!,
            id: 'chat-${msg.fromId}'.hashCode,
          );
        }
        break;
      case InboxKind.rideRequest:
      case InboxKind.rideOffer:
        break;
    }
  }

  void _sendChat(String text) {
    if (_activeRideId == null || _activePassengerId == null) return;
    final msg = InboxMessage(
      kind: InboxKind.chat,
      fromId: widget.peerId,
      fromName: widget.displayName,
      toId: _activePassengerId!,
      rideId: _activeRideId,
      note: text,
    );
    _p2p.sendInbox(msg);
    _chat.value = [..._chat.value, msg];
  }

  void _activateRide(_PendingBid bid, {ContactInfo? passengerContact}) {
    for (final b in _pendingRequests.values) {
      b.expiry?.cancel();
    }
    setState(() {
      _activeRideId = bid.request.rideId;
      _activePassengerId = bid.request.fromId;
      _activePassengerName = bid.request.fromName;
      _activePassengerContact = passengerContact;
      _activePrice = bid.price;
      _activeCurrency = bid.currency;
      _activeStartedAt = DateTime.now();
      _passengerLocation = (bid.request.lat != null && bid.request.lng != null)
          ? LatLng(bid.request.lat!, bid.request.lng!)
          : null;
      _activeDestination =
          (bid.request.destLat != null && bid.request.destLng != null)
              ? LatLng(bid.request.destLat!, bid.request.destLng!)
              : null;
      _pendingRequests.clear();
    });
  }

  void _submitBid(_PendingBid bid) {
    final contactToSend =
        (_contact != null && _contact!.hasAny) ? _contact : null;
    _p2p.sendInbox(InboxMessage(
      kind: InboxKind.rideOffer,
      fromId: widget.peerId,
      fromName: widget.displayName,
      toId: bid.request.fromId,
      rideId: bid.request.rideId,
      lat: _last?.latitude,
      lng: _last?.longitude,
      price: bid.price,
      currency: bid.currency,
      fromAvgRating: _mySummary.count > 0 ? _mySummary.average : null,
      fromRatingCount: _mySummary.count > 0 ? _mySummary.count : null,
      fromCar: _car,
      fromContact: contactToSend,
      fromPayment: (_payment != null && _payment!.hasAny) ? _payment : null,
    ));
    bid.expiry?.cancel();
    bid.expiry = Timer(const Duration(seconds: 90), () {
      if (!mounted) return;
      final still = _pendingRequests[bid.request.rideId];
      if (still != bid || !bid.submitted) return;
      setState(() => _pendingRequests.remove(bid.request.rideId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid expired (no response).')),
      );
    });
    setState(() => bid.submitted = true);
  }

  void _dismissRequest(_PendingBid bid) {
    bid.expiry?.cancel();
    setState(() => _pendingRequests.remove(bid.request.rideId));
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
        content: Text(
            '${msg.fromName ?? 'Passenger'} rated you $score★'),
      ),
    );
  }


  void _endRide({bool notifyOther = true}) {
    final endedRideId = _activeRideId;
    final endedPassengerId = _activePassengerId;
    final endedPassengerName = _activePassengerName;
    final endedPrice = _activePrice;
    final endedCurrency = _activeCurrency;
    final endedPickup = _passengerLocation;
    final endedDest = _activeDestination;
    final startedAt = _activeStartedAt;

    if (notifyOther && endedRideId != null && endedPassengerId != null) {
      _p2p.sendInbox(InboxMessage(
        kind: InboxKind.cancel,
        fromId: widget.peerId,
        fromName: widget.displayName,
        toId: endedPassengerId,
        rideId: endedRideId,
      ));
    }
    setState(() {
      _activeRideId = null;
      _activePassengerId = null;
      _activePassengerName = null;
      _activePassengerContact = null;
      _activePrice = null;
      _activeCurrency = null;
      _passengerLocation = null;
      _activeDestination = null;
      _activeStartedAt = null;
    });
    _chat.value = const [];

    if (endedRideId != null && endedPassengerId != null) {
      _history.add(RideRecord(
        rideId: endedRideId,
        role: Role.driver,
        counterpartyId: endedPassengerId,
        counterpartyName: endedPassengerName,
        startedAt: startedAt ?? DateTime.now(),
        endedAt: DateTime.now(),
        pickupLat: endedPickup?.latitude,
        pickupLng: endedPickup?.longitude,
        destLat: endedDest?.latitude,
        destLng: endedDest?.longitude,
        price: endedPrice,
        currency: endedCurrency,
      ));
      _promptRating(
        rideId: endedRideId,
        counterpartyId: endedPassengerId,
        counterpartyName: endedPassengerName,
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
        counterpartyName: counterpartyName ?? 'passenger');
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
    _heartbeat?.cancel();
    for (final b in _pendingRequests.values) {
      b.expiry?.cancel();
    }
    _posSub?.cancel();
    _inboxSub?.cancel();
    _requestsSub?.cancel();
    _connSub?.cancel();
    _chat.dispose();
    _p2p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _last != null
        ? LatLng(_last!.latitude, _last!.longitude)
        : const LatLng(64.1466, -21.9426);

    final markers = <Marker>[
      if (_last != null)
        Marker(
          point: LatLng(_last!.latitude, _last!.longitude),
          width: 44,
          height: 44,
          child: const Icon(Icons.directions_car,
              size: 36, color: Colors.blueAccent),
        ),
      if (_passengerLocation != null)
        Marker(
          point: _passengerLocation!,
          width: 44,
          height: 44,
          child:
              const Icon(Icons.person_pin_circle, size: 36, color: Colors.red),
        ),
      if (_activeDestination != null)
        Marker(
          point: _activeDestination!,
          width: 64,
          height: 64,
          child: GestureDetector(
            onTap: () => openDirections(
              lat: _activeDestination!.latitude,
              lng: _activeDestination!.longitude,
            ),
            child: Tooltip(
              message: 'Open in Maps',
              child: const Icon(Icons.flag,
                  size: 36, color: Colors.deepPurple),
            ),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_mySummary.formatted() != null
            ? 'Driver · ${widget.displayName} · ${_mySummary.formatted()}'
            : 'Driver · ${widget.displayName}'),
        actions: [
          IconButton(
            tooltip: 'Edit vehicle',
            icon: const Icon(Icons.directions_car),
            onPressed: _editCar,
          ),
          IconButton(
            tooltip: 'Edit contact',
            icon: const Icon(Icons.contact_phone),
            onPressed: _editContact,
          ),
          IconButton(
            tooltip: 'Payment & currency',
            icon: const Icon(Icons.payments),
            onPressed: _editPayment,
          ),
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
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'is.skutla.app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _StatusBar(connected: _connected, available: _available),
          ),
          if (_activeRideId == null && _pendingRequests.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 80,
              child: _IncomingRequestsPanel(
                bids: _pendingRequests.values.toList(),
                driverLocation: _last == null
                    ? null
                    : LatLng(_last!.latitude, _last!.longitude),
                hasContact: _contact != null && _contact!.hasAny,
                onSubmit: _submitBid,
                onDismiss: _dismissRequest,
                onPriceChange: (bid, price) =>
                    setState(() => bid.price = price),
                onEditContact: _editContact,
              ),
            ),
          if (_activeRideId != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 100,
              child: _ActiveRideCard(
                passengerLabel:
                    _activePassengerName ?? _activePassengerId!.substring(0, 8),
                passengerContact: _activePassengerContact,
                price: _activePrice,
                currency: _activeCurrency,
                onEnd: _endRide,
                onOpenMaps: _activeDestination == null
                    ? null
                    : () => openDirections(
                          lat: _activeDestination!.latitude,
                          lng: _activeDestination!.longitude,
                        ),
                onOpenChat: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      title: _activePassengerName ?? 'Passenger',
                      messages: _chat,
                      myPeerId: widget.peerId,
                      onSend: _sendChat,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(_available ? Icons.toggle_on : Icons.toggle_off),
        label: Text(_available ? 'Available' : 'Offline'),
        onPressed: _activeRideId != null
            ? null
            : () {
                setState(() => _available = !_available);
              },
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.connected, required this.available});
  final bool connected;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.circle,
                size: 12, color: connected ? Colors.green : Colors.grey),
            const SizedBox(width: 8),
            Text(connected ? 'Connected to peers' : 'Connecting…'),
            const Spacer(),
            Text(available ? 'Visible to riders' : 'Hidden'),
          ],
        ),
      ),
    );
  }
}

class _PendingBid {
  _PendingBid({
    required this.request,
    required this.currency,
    required this.price,
    required this.pickupMeters,
    required this.tripMeters,
  });
  final InboxMessage request;
  final String currency;
  double price;
  final double pickupMeters;
  final double tripMeters;
  bool submitted = false;
  Timer? expiry;

  double get totalMeters => pickupMeters + tripMeters;
}

String _fmtMeters(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

class _IncomingRequestsPanel extends StatelessWidget {
  const _IncomingRequestsPanel({
    required this.bids,
    required this.driverLocation,
    required this.hasContact,
    required this.onSubmit,
    required this.onDismiss,
    required this.onPriceChange,
    required this.onEditContact,
  });
  final List<_PendingBid> bids;
  final LatLng? driverLocation;
  final bool hasContact;
  final void Function(_PendingBid) onSubmit;
  final void Function(_PendingBid) onDismiss;
  final void Function(_PendingBid, double) onPriceChange;
  final VoidCallback onEditContact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: bids.length,
        itemBuilder: (_, i) => _RequestBidCard(
          bid: bids[i],
          driverLocation: driverLocation,
          hasContact: hasContact,
          onSubmit: () => onSubmit(bids[i]),
          onDismiss: () => onDismiss(bids[i]),
          onPriceChange: (p) => onPriceChange(bids[i], p),
          onEditContact: onEditContact,
        ),
      ),
    );
  }
}

class _RequestBidCard extends StatefulWidget {
  const _RequestBidCard({
    required this.bid,
    required this.driverLocation,
    required this.hasContact,
    required this.onSubmit,
    required this.onDismiss,
    required this.onPriceChange,
    required this.onEditContact,
  });
  final _PendingBid bid;
  final LatLng? driverLocation;
  final bool hasContact;
  final VoidCallback onSubmit;
  final VoidCallback onDismiss;
  final ValueChanged<double> onPriceChange;
  final VoidCallback onEditContact;

  @override
  State<_RequestBidCard> createState() => _RequestBidCardState();
}

class _RequestBidCardState extends State<_RequestBidCard> {
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _priceController =
        TextEditingController(text: widget.bid.price.round().toString());
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.bid.request;
    final pickup = (r.lat != null && r.lng != null)
        ? LatLng(r.lat!, r.lng!)
        : null;

    String? pickupDistance;
    if (widget.driverLocation != null && pickup != null) {
      pickupDistance = _fmtMeters(Geolocator.distanceBetween(
        widget.driverLocation!.latitude,
        widget.driverLocation!.longitude,
        pickup.latitude,
        pickup.longitude,
      ));
    }

    return SizedBox(
      width: 300,
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.fromName ?? r.fromId.substring(0, 8),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    (r.fromAvgRating != null &&
                            (r.fromRatingCount ?? 0) > 0)
                        ? '${r.fromAvgRating!.toStringAsFixed(1)} ★ (${r.fromRatingCount})'
                        : 'New',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                pickupDistance != null
                    ? 'Pickup · $pickupDistance away'
                    : 'Pickup',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Trip · ${_fmtMeters(widget.bid.tripMeters)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Price (${widget.bid.currency})',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      enabled: !widget.bid.submitted,
                      onChanged: (v) {
                        final p = double.tryParse(v);
                        if (p != null) widget.onPriceChange(p);
                      },
                    ),
                  ),
                ],
              ),
              if (!widget.hasContact)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton.icon(
                    icon: const Icon(Icons.contact_phone, size: 16),
                    label: const Text('Add contact info'),
                    onPressed: widget.onEditContact,
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.bid.submitted ? null : widget.onDismiss,
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.bid.submitted ? null : widget.onSubmit,
                      child: Text(widget.bid.submitted ? 'Bid sent' : 'Bid'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveRideCard extends StatelessWidget {
  const _ActiveRideCard({
    required this.passengerLabel,
    required this.onEnd,
    this.onOpenMaps,
    this.onOpenChat,
    this.passengerContact,
    this.price,
    this.currency,
  });
  final String passengerLabel;
  final VoidCallback onEnd;
  final VoidCallback? onOpenMaps;
  final VoidCallback? onOpenChat;
  final ContactInfo? passengerContact;
  final double? price;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Active ride with $passengerLabel'),
                ),
                if (price != null && currency != null) ...[
                  Text(Pricing.round(price!, currency!),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                ],
                if (onOpenChat != null)
                  IconButton(
                    tooltip: 'Chat',
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: onOpenChat,
                  ),
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
            if (passengerContact != null) ...[
              const SizedBox(height: 4),
              _ContactChips(contact: passengerContact!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactChips extends StatelessWidget {
  const _ContactChips({required this.contact});
  final ContactInfo contact;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if ((contact.phone ?? '').isNotEmpty) {
      children.add(ActionChip(
        avatar: const Icon(Icons.call, size: 16),
        label: const Text('Call'),
        onPressed: () => openPhone(contact.phone!),
      ));
    }
    if ((contact.whatsapp ?? '').isNotEmpty) {
      children.add(ActionChip(
        avatar: const Icon(Icons.chat, size: 16),
        label: const Text('WhatsApp'),
        onPressed: () => openWhatsApp(contact.whatsapp!),
      ));
    }
    if ((contact.messenger ?? '').isNotEmpty) {
      children.add(ActionChip(
        avatar: const Icon(Icons.message, size: 16),
        label: const Text('Messenger'),
        onPressed: () => openMessenger(contact.messenger!),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, children: children);
  }
}
