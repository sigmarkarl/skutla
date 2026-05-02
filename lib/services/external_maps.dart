import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openDirections({required double lat, required double lng}) {
  final dest = '$lat,$lng';
  Uri url;
  if (kIsWeb) {
    url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving');
  } else if (Platform.isIOS || Platform.isMacOS) {
    url = Uri.parse('https://maps.apple.com/?daddr=$dest&dirflg=d');
  } else {
    url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving');
  }
  return launchUrl(url, mode: LaunchMode.externalApplication);
}

String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^\d+]'), '');

Future<bool> openPhone(String phone) =>
    launchUrl(Uri.parse('tel:${_digitsOnly(phone)}'));

Future<bool> openWhatsApp(String phone) {
  final clean = _digitsOnly(phone).replaceAll('+', '');
  return launchUrl(
    Uri.parse('https://wa.me/$clean'),
    mode: LaunchMode.externalApplication,
  );
}

Future<bool> openMessenger(String handle) =>
    launchUrl(
      Uri.parse('https://m.me/${handle.trim()}'),
      mode: LaunchMode.externalApplication,
    );

Future<bool> openPayPal(String handle, {double? amount, String? currency}) {
  final h = handle.trim();
  final tail = amount != null ? '/${amount.toStringAsFixed(2)}${currency ?? ''}' : '';
  return launchUrl(
    Uri.parse('https://paypal.me/$h$tail'),
    mode: LaunchMode.externalApplication,
  );
}

Future<bool> openVenmo(String handle) =>
    launchUrl(
      Uri.parse('https://venmo.com/u/${handle.trim()}'),
      mode: LaunchMode.externalApplication,
    );

Future<bool> openBitcoin(String address) =>
    launchUrl(
      Uri.parse('bitcoin:${address.trim()}'),
      mode: LaunchMode.externalApplication,
    );

Future<bool> openEthereum(String address) =>
    launchUrl(
      Uri.parse('ethereum:${address.trim()}'),
      mode: LaunchMode.externalApplication,
    );
