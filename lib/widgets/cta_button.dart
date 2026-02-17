import 'package:flutter/material.dart';

class CtaButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget label;
  final IconData? icon;
  final bool filled;

  const CtaButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Center(child: label),
    );
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        label: child,
      );
    } else {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        label: child,
      );
    }
  }
}
