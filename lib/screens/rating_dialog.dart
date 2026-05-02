import 'package:flutter/material.dart';

import '../models/messages.dart';
import '../services/external_maps.dart';
import '../services/pricing.dart';

class RatingResult {
  const RatingResult({required this.score, this.comment});
  final int score;
  final String? comment;
}

Future<RatingResult?> showRatingDialog(
  BuildContext context, {
  required String counterpartyName,
  PaymentInfo? payment,
  double? price,
  String? currency,
}) {
  return showDialog<RatingResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RatingDialog(
      name: counterpartyName,
      payment: payment,
      price: price,
      currency: currency,
    ),
  );
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({
    required this.name,
    this.payment,
    this.price,
    this.currency,
  });
  final String name;
  final PaymentInfo? payment;
  final double? price;
  final String? currency;

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _score = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final priceLabel = (widget.price != null && widget.currency != null)
        ? Pricing.round(widget.price!, widget.currency!)
        : null;
    final paymentVisible =
        widget.payment != null && widget.payment!.hasAny;

    return AlertDialog(
      title: Text('Rate ${widget.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (paymentVisible) ...[
              if (priceLabel != null)
                Text('Pay $priceLabel to ${widget.name}',
                    style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _PaymentChips(
                payment: widget.payment!,
                amount: widget.price,
                currency: widget.currency,
              ),
              const Divider(height: 24),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _score;
                return IconButton(
                  iconSize: 36,
                  onPressed: () => setState(() => _score = i + 1),
                  icon: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: filled ? Colors.amber : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: _score == 0
              ? null
              : () => Navigator.of(context).pop(
                    RatingResult(
                      score: _score,
                      comment: _commentController.text.trim().isEmpty
                          ? null
                          : _commentController.text.trim(),
                    ),
                  ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _PaymentChips extends StatelessWidget {
  const _PaymentChips({
    required this.payment,
    this.amount,
    this.currency,
  });
  final PaymentInfo payment;
  final double? amount;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if ((payment.aur ?? '').isNotEmpty) {
      children.add(ActionChip(
        avatar: const Icon(Icons.account_balance_wallet, size: 16),
        label: Text('Aur ${payment.aur}'),
        onPressed: () => openPhone(payment.aur!),
      ));
    }
    if ((payment.paypal ?? '').isNotEmpty) {
      children.add(ActionChip(
        avatar: const Icon(Icons.paypal, size: 16),
        label: const Text('PayPal'),
        onPressed: () =>
            openPayPal(payment.paypal!, amount: amount, currency: currency),
      ));
    }
    if ((payment.venmo ?? '').isNotEmpty) {
      children.add(ActionChip(
        avatar: const Icon(Icons.attach_money, size: 16),
        label: const Text('Venmo'),
        onPressed: () => openVenmo(payment.venmo!),
      ));
    }
    if ((payment.wechat ?? '').isNotEmpty) {
      children.add(ActionChip(
        avatar: const Icon(Icons.qr_code, size: 16),
        label: Text('WeChat ${payment.wechat}'),
        onPressed: () {},
      ));
    }
    if ((payment.bitcoin ?? '').isNotEmpty) {
      children.add(ActionChip(
        avatar: const Icon(Icons.currency_bitcoin, size: 16),
        label: const Text('Bitcoin'),
        onPressed: () => openBitcoin(payment.bitcoin!,
            amount: amount, currency: currency),
      ));
    }
    if ((payment.ethereum ?? '').isNotEmpty) {
      children.add(ActionChip(
        avatar: const Icon(Icons.token, size: 16),
        label: const Text('Ethereum'),
        onPressed: () => openEthereum(payment.ethereum!,
            amount: amount, currency: currency),
      ));
    }
    if (payment.cash == true) {
      children.add(const Chip(
        avatar: Icon(Icons.payments, size: 16),
        label: Text('Cash OK'),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, children: children);
  }
}
