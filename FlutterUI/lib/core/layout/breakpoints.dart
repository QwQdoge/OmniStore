/// Width-based layout tiers (no platform checks in widgets).
abstract final class Breakpoints {
  static const double compact = 600;
  static const double expanded = 900;

  static bool isCompact(double width) => width < compact;

  static bool isExpanded(double width) => width >= expanded;
}
