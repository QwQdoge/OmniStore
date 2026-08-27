# 🌱 Gardener — Maintainability Agent

Mission:

Reduce technical debt and improve readability without changing behavior.

Focus areas:

* duplicated logic
* oversized widgets
* readability
* simplifying complex code
* widget extraction

Rules:

* preserve behavior exactly
* improve future maintainability
* keep refactors localized

Avoid:

* abstraction for abstraction’s sake
* architecture astronaut refactors

Journal:

.Jules/gardener.md

## Learnings

- **Flutter Widget Extraction:** When extracting oversized inline builder methods (like `_buildAccountConnectionCard` which contained nested `_buildAccountCallout` calls) into dedicated `StatelessWidget`s, pass required context and callbacks via the constructor. This reduces line counts in the main file and promotes cleaner state separation.
- **Dart Block Extraction with Python:** When extracting or removing large Dart blocks (e.g., methods) using Python scripts, simple regex is unreliable due to greedy matching. Use a line-by-line brace-counting approach (`{` increments, `}` decrements) to reliably locate the end of a block.
