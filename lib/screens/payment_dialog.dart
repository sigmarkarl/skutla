import 'package:flutter/material.dart';

import '../models/messages.dart';

class PaymentDialogResult {
  PaymentDialogResult({required this.payment, required this.currency});
  final PaymentInfo payment;
  final String currency;
}

Future<PaymentDialogResult?> showPaymentDialog(
  BuildContext context, {
  PaymentInfo? initial,
  required String currency,
}) {
  return showDialog<PaymentDialogResult>(
    context: context,
    builder: (_) => _PaymentDialog(initial: initial, currency: currency),
  );
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({this.initial, required this.currency});
  final PaymentInfo? initial;
  final String currency;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _currency;
  late final TextEditingController _aur;
  late final TextEditingController _paypal;
  late final TextEditingController _venmo;
  late final TextEditingController _wechat;
  late final TextEditingController _bitcoin;
  late final TextEditingController _ethereum;
  late bool _cash;

  @override
  void initState() {
    super.initState();
    _currency = TextEditingController(text: widget.currency);
    _aur = TextEditingController(text: widget.initial?.aur ?? '');
    _paypal = TextEditingController(text: widget.initial?.paypal ?? '');
    _venmo = TextEditingController(text: widget.initial?.venmo ?? '');
    _wechat = TextEditingController(text: widget.initial?.wechat ?? '');
    _bitcoin = TextEditingController(text: widget.initial?.bitcoin ?? '');
    _ethereum = TextEditingController(text: widget.initial?.ethereum ?? '');
    _cash = widget.initial?.cash ?? false;
  }

  @override
  void dispose() {
    _currency.dispose();
    _aur.dispose();
    _paypal.dispose();
    _venmo.dispose();
    _wechat.dispose();
    _bitcoin.dispose();
    _ethereum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Payment & currency'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currency,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Currency code',
                  hintText: 'ISK / USD / EUR / …',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aur,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Aur (Iceland) — phone',
                  hintText: '+354 …',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _paypal,
                decoration: const InputDecoration(
                  labelText: 'PayPal.me handle',
                  hintText: 'yourname',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _venmo,
                decoration: const InputDecoration(
                  labelText: 'Venmo username',
                  hintText: 'yourname',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _wechat,
                decoration: const InputDecoration(
                  labelText: 'WeChat ID',
                  hintText: 'wxid…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bitcoin,
                decoration: const InputDecoration(
                  labelText: 'Bitcoin address',
                  hintText: 'bc1q… or 1A1zP…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ethereum,
                decoration: const InputDecoration(
                  labelText: 'Ethereum / USDC address',
                  hintText: '0x…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Accept cash'),
                value: _cash,
                onChanged: (v) => setState(() => _cash = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final code = _currency.text.trim().toUpperCase();
            if (code.length < 3) return;
            final p = PaymentInfo(
              aur: _aur.text.trim().isEmpty ? null : _aur.text.trim(),
              paypal:
                  _paypal.text.trim().isEmpty ? null : _paypal.text.trim(),
              venmo: _venmo.text.trim().isEmpty ? null : _venmo.text.trim(),
              wechat:
                  _wechat.text.trim().isEmpty ? null : _wechat.text.trim(),
              bitcoin: _bitcoin.text.trim().isEmpty
                  ? null
                  : _bitcoin.text.trim(),
              ethereum: _ethereum.text.trim().isEmpty
                  ? null
                  : _ethereum.text.trim(),
              cash: _cash ? true : null,
            );
            Navigator.of(context).pop(PaymentDialogResult(
              payment: p,
              currency: code,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
