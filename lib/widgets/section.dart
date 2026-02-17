import 'package:flutter/material.dart';
import '../ui_constants.dart';

class Section extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const Section({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.margin = const EdgeInsets.symmetric(
        horizontal: Spacing.lg, vertical: Spacing.md),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Gaps.smH,
          ],
          Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
