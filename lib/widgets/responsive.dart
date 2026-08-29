import 'package:flutter/widgets.dart';

/// Layout breakpoints. We branch on available WIDTH, never on platform, so the
/// same screens adapt whether they run on web, tablet, or phone.
class Breakpoints {
  static const compact = 600.0; // phones
  static const medium = 900.0; // large phones / small tablets
  static const expanded = 1200.0; // tablets / desktop / web
}

extension ResponsiveContext on BuildContext {
  double get _w => MediaQuery.sizeOf(this).width;

  /// True on wide surfaces (tablet/desktop/web) — use a side nav rail, multi-column.
  bool get isWide => _w >= Breakpoints.medium;

  /// True on the widest surfaces — room for a persistent extended rail.
  bool get isExpanded => _w >= Breakpoints.expanded;
}
