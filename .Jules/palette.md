# Palette Journal - UI/UX & Accessibility Polish

## Learnings & Patterns
- **MD3 Empty States**: Empty states anchor illustrative icons inside tonal surface container badges (`surfaceContainerHigh` circular decoration with a subtle `outlineVariant` border and `primary` icon color). Titles use high-contrast `theme.colorScheme.onSurface`, and text hierarchy is wrapped in a `Semantics` node with `excludeSemantics: true` to prevent unstyled text node duplication in screen readers.
