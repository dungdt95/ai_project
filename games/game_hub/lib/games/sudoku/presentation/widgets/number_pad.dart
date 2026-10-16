import 'package:flutter/material.dart';

class NumberPad extends StatelessWidget {
  const NumberPad({
    super.key,
    required this.placed,
    required this.notesMode,
    required this.onNumber,
    required this.onErase,
    required this.onToggleNotes,
  });

  final Map<int, int> placed; // digit → count placed
  final bool notesMode;
  final void Function(int value) onNumber;
  final VoidCallback onErase;
  final VoidCallback onToggleNotes;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (int d = 1; d <= 9; d++) _NumberButton(
          digit: d,
          remaining: 9 - (placed[d] ?? 0),
          onTap: () => onNumber(d),
        ),
        IconButton(
          onPressed: onErase,
          icon: const Icon(Icons.backspace_outlined),
          tooltip: 'Xóa',
        ),
        IconButton(
          onPressed: onToggleNotes,
          icon: Icon(
            Icons.edit_note,
            color: notesMode ? cs.primary : null,
          ),
          tooltip: 'Ghi chú',
        ),
      ],
    );
  }
}

class _NumberButton extends StatelessWidget {
  const _NumberButton({
    required this.digit,
    required this.remaining,
    required this.onTap,
  });

  final int digit;
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = remaining <= 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TextButton(
          onPressed: disabled ? null : onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(36, 44),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            '$digit',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: disabled
                  ? cs.onSurface.withOpacity(0.3)
                  : cs.onSurface,
            ),
          ),
        ),
        if (!disabled)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$remaining',
                style: TextStyle(
                  fontSize: 9,
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
