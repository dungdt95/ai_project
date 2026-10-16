import 'package:flutter/material.dart';

/// Consistent full-width filled button used across all game screens.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = color != null
        ? FilledButton.styleFrom(backgroundColor: color)
        : null;
    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}
