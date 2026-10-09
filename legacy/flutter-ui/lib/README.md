# `lib/` — source layout

```
lib/
├── main.dart              # → bootstrapOmniStore()
├── app/                   # App shell, providers, navigation
├── core/                  # Theme, layout, GitHub client, desktop window
├── features/              # Feature-first UI modules
├── data/                  # Python CLI repositories (not python/ backend)
├── services/              # TaskManager, BackendService, UpdateService
├── models/                # Domain models
├── widgets/               # Shared components
└── l10n/                  # Generated i18n
```

Full diagrams and rules: **[../ARCHITECTURE.md](../ARCHITECTURE.md)**.
