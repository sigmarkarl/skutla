import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'crypto_rates.dart';

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

Future<bool> openBitcoin(String address,
    {double? amount, String? currency}) async {
  String uri = 'bitcoin:${address.trim()}';
  if (amount != null && currency != null) {
    final btc = await CryptoRates.convert(
      coinId: 'bitcoin',
      currency: currency,
      fiatAmount: amount,
    );
    if (btc != null && btc > 0) {
      uri += '?amount=${btc.toStringAsFixed(8)}';
    }
  }
  return launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
}

Future<bool> openEthereum(String address,
    {double? amount, String? currency}) async {
  String uri = 'ethereum:${address.trim()}';
  if (amount != null && currency != null) {
    final eth = await CryptoRates.convert(
      coinId: 'ethereum',
      currency: currency,
      fiatAmount: amount,
    );
    if (eth != null && eth > 0) {
      // EIP-681 expresses amount in wei.
      final wei = (eth * 1e18).round();
      uri += '?value=$wei';
    }
  }
  return launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
}
