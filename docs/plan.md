So `isLoadingDetails` handles `AppAboutSection` using `AnimatedSwitcher` already. What about `AppTechnicalDetails`? It just shows details if available.
What about the screenshots section? If `extraDetails` becomes not-null due to `_fetchExtraDetails`, the UI will abruptly show the screenshots section and technical details. We should wrap the whole bottom half in `AnimatedSwitcher` or `AnimatedSize` or wrap the conditional screenshots in `AnimatedSize`.

Let's do this: I will create a `subtle_animations` wrapper using `AnimatedSize` or `AnimatedSwitcher` for `AppMainContent`'s conditionally rendered `AppScreenshots` and `AppTechnicalDetails`.
