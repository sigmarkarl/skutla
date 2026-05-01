import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/messages.dart';

class IdentityService {
  static const _kIdKey = 'skutla.peer_id';
  static const _kRoleKey = 'skutla.role';
  static const _kNameKey = 'skutla.display_name';
  static const _kCarKey = 'skutla.car_info';
  static const _kContactKey = 'skutla.contact_info';
  static const _kShareContactKey = 'skutla.share_contact';
  static const _kPaymentKey = 'skutla.payment_info';
  static const _kCurrencyKey = 'skutla.currency';

  Future<String> getOrCreatePeerId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_kIdKey, id);
    return id;
  }

  Future<Role?> readRole() async {
    final prefs = await SharedPreferences.getInstance();
    final r = prefs.getString(_kRoleKey);
    if (r == null) return null;
    return Role.values.firstWhere(
      (e) => e.name == r,
      orElse: () => Role.passenger,
    );
  }

  Future<void> writeRole(Role role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRoleKey, role.name);
  }

  Future<String?> readName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kNameKey);
  }

  Future<void> writeName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNameKey, name);
  }

  Future<CarInfo?> readCarInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCarKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CarInfo.tryFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCarInfo(CarInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCarKey, jsonEncode(info.toJson()));
  }

  Future<ContactInfo?> readContactInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kContactKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return ContactInfo.tryFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeContactInfo(ContactInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kContactKey, jsonEncode(info.toJson()));
  }

  Future<bool> readShareContact() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kShareContactKey) ?? true;
  }

  Future<void> writeShareContact(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShareContactKey, value);
  }

  Future<PaymentInfo?> readPaymentInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPaymentKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PaymentInfo.tryFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> writePaymentInfo(PaymentInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPaymentKey, jsonEncode(info.toJson()));
  }

  Future<String?> readCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kCurrencyKey);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> writeCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrencyKey, code.toUpperCase());
  }

  Future<void> clearCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrencyKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRoleKey);
    await prefs.remove(_kNameKey);
  }
}
