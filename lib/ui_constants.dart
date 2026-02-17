// Frontend/ui_constants.dart
import 'package:flutter/material.dart';

class Spacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class Gaps {
  // Vertical
  static const xsH = SizedBox(height: Spacing.xs);
  static const smH = SizedBox(height: Spacing.sm);
  static const mdH = SizedBox(height: Spacing.md);
  static const lgH = SizedBox(height: Spacing.lg);
  static const xlH = SizedBox(height: Spacing.xl);
  static const xxlH = SizedBox(height: Spacing.xxl);

  // Horizontal
  static const xsW = SizedBox(width: Spacing.xs);
  static const smW = SizedBox(width: Spacing.sm);
  static const mdW = SizedBox(width: Spacing.md);
  static const lgW = SizedBox(width: Spacing.lg);
  static const xlW = SizedBox(width: Spacing.xl);
  static const xxlW = SizedBox(width: Spacing.xxl);
}

class Corners {
  static const sm = Radius.circular(8);
  static const md = Radius.circular(12);
  static const lg = Radius.circular(16);
}

class TouchTarget {
  static const minSize = Size(48, 48);
}
