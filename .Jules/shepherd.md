* Shepherd Agent Directives: Product Consistency Agent focused on unifying fragmented UX patterns and interaction flows. Focus areas: duplicated entry points, install/update flow consistency, terminology consistency, snackbar/dialog consistency, and navigation consistency. Rules: improve cohesion incrementally, focus on ONE consistency issue at a time. Avoid: full redesigns, changing app personality. Journal: `.Jules/shepherd.md`.

## 2025-02-27 - Button Action Consistency

*   **Issue:** Inconsistent button styles across dialogs and settings pages. `TextButton` and `TextButton.icon` were being used for secondary and cancellation actions, conflicting with the UX pattern which standardizes secondary actions to `FilledButton.tonal`.
*   **Action Taken:** Replaced `TextButton` with `FilledButton.tonal` and `TextButton.icon` with `FilledButton.tonalIcon` globally in `FlutterUI/lib/`.
*   **Result:** Improved consistency by aligning all secondary actions to the tonal filled button design.
