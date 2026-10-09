# `features/` — feature modules

Each feature owns its UI. Shared Python access goes through `data/repositories/`.

```
features/
├── home/                          # Explore landing / shelves
├── explore/presentation/
│   ├── controllers/browse_controller.dart
│   └── pages/                     # category, search, details, github, flatpak
├── apps/                          # Installed applications list
├── settings/presentation/
│   ├── controllers/settings_controller.dart
│   └── pages/tweaks_page.dart
├── task_manager/presentation/
│   ├── controllers/task_controller.dart
│   └── pages/download_page.dart
├── onboarding/welcome_page.dart
└── auth/auth_page.dart
```

Convention for new features:

```
features/<name>/presentation/
  controllers/   # ChangeNotifier / state
  pages/         # Widgets (screens)
```

Optional future split: `domain/` (pure Dart) and `data/` (repos) inside the feature.
