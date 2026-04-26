## 2025-05-14 - [Internationalization and Tooltips]
**Learning:** In localized applications, ensure micro-UX enhancements like tooltips follow the project's primary language (e.g., Chinese in this case) to maintain a cohesive and professional experience. Mixing languages (e.g., English tooltips with Chinese labels) can feel unpolished.
**Action:** Always inspect the existing UI text and localization patterns before adding new tooltips, ARIA labels, or helper text.

## 2025-05-14 - [Autofocus in Navigation Containers]
**Learning:** Using `autofocus: true` on widgets within navigation containers (like `IndexedStack` or `PageView`) can cause the keyboard to trigger unexpectedly if the widget is mounted in the background.
**Action:** Be cautious with `autofocus` in multi-page layouts; consider triggering focus only when the page becomes active or using it selectively.
