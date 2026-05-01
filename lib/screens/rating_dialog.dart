import 'package:flutter/material.dart';

class RatingResult {
  const RatingResult({required this.score, this.comment});
  final int score;
  final String? comment;
}

Future<RatingResult?> showRatingDialog(
  BuildContext context, {
  required String counterpartyName,
}) {
  return showDialog<RatingResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RatingDialog(name: counterpartyName),
  );
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({required this.name});
  final String name;

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
    return AlertDialog(
      title: Text('Rate ${widget.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
