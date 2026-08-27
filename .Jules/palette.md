## 2025-05-18 - ActionChip Semantics & Tooltip Consolidation

**Learning:** Flutter's ActionChip, FilterChip, and ChoiceChip natively handle desktop hover tooltips and screen-reader accessibility through their built-in tooltip parameter. Wrapping chips inside redundant Semantics widgets creates duplicate semantic nodes in the accessibility tree and unnecessary widget tree depth.

**Action:** Pass localized semantic strings (e.g., l10n.categorySemantics(name)) directly to ActionChip.tooltip instead of enclosing chips in separate Semantics wrappers.
