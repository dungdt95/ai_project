import 'package:flutter/material.dart';

class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.canHint,
    required this.hintsUsed,
    required this.notesMode,
    required this.onUndo,
    required this.onRedo,
    required this.onHint,
    required this.onToggleNotes,
    required this.onErase,
  });

  final bool canUndo, canRedo, canHint;
  final int hintsUsed;
  final bool notesMode;
  final VoidCallback onUndo, onRedo, onHint, onToggleNotes, onErase;

  static const _maxHints = 3;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Btn(
          icon: Icons.undo,
          label: 'Undo',
          onTap: canUndo ? onUndo : null,
        ),
        _Btn(
          icon: Icons.redo,
          label: 'Redo',
          onTap: canRedo ? onRedo : null,
        ),
        _Btn(
          icon: Icons.edit_note,
          label: 'Ghi chú',
          color: notesMode ? cs.primary : null,
          onTap: onToggleNotes,
        ),
        _Btn(
          icon: Icons.backspace_outlined,
          label: 'Xóa',
          onTap: onErase,
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _Btn(
              icon: Icons.lightbulb_outline,
              label: 'Gợi ý',
              onTap: canHint ? onHint : null,
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_maxHints - hintsUsed}',
                  style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? (onTap != null ? cs.onSurface : cs.onSurface.withOpacity(0.3));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: c)),
          ],
        ),
      ),
    );
  }
}
