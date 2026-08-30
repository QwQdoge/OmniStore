# Plan

1. We have already modified `GitHubIntegrationPage` in `FlutterUI/lib/features/settings/presentation/pages/github_integration_page.dart` to add a visibility toggle for the GitHub PAT and bind `onSubmitted` to trigger `_savePat()`.
2. We have already modified `WelcomeAiPage` in `FlutterUI/lib/features/onboarding/widgets/welcome_ai_page.dart` to change it to a `StatefulWidget` and added a visibility toggle for the API Key.
3. We have already modified `SignInForm` in `FlutterUI/lib/features/auth/presentation/widgets/sign_in_form.dart` to use `ConstrainedBox(maxWidth: 600)`.
4. We verified the code compiles, the tests pass, and we haven't introduced any regression.
5. Complete pre commit steps to ensure proper testing, verification, review, and reflection are done.
6. Submit the code.
