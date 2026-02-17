import 'package:flutter/material.dart';

class Skeleton extends StatelessWidget {
  final double height;
  final double width;
  final BorderRadius? borderRadius;

  const Skeleton(
      {super.key,
      this.height = 16,
      this.width = double.infinity,
      this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Colors.black.withValues(alpha: 0.06);
    return _AnimatedShimmer(
      builder: (t) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Color.lerp(base, highlight, t),
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _AnimatedShimmer extends StatefulWidget {
  final Widget Function(double t) builder;
  const _AnimatedShimmer({required this.builder});

  @override
  State<_AnimatedShimmer> createState() => _AnimatedShimmerState();
}

class _AnimatedShimmerState extends State<_AnimatedShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) => widget.builder(_ctl.value),
    );
  }
}
