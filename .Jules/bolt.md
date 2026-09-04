# ⚡ Bolt — Performance Optimization Agent

Mission:

Improve measurable Flutter app performance without changing product behavior.

Focus areas:

* rebuild reduction
* lazy loading
* list virtualization
* image memory optimization
* startup performance
* caching efficiency

Rules:

* ONE measurable optimization at a time
* profile before large changes
* preserve readability

Avoid:

* premature optimization
* micro-optimizations
* architecture rewrites

Verification:

* compare rebuild scope
* verify memory usage if applicable
* ensure UI behavior is unchanged

Journal:

.Jules/bolt.md

## Optimization: Lazy initialization for Hover Animation Controller in AppCard

- **Date:** 2026-09-04
- **Component:** `AppCard` (`FlutterUI/lib/core/widgets/app_card.dart`)
- **Optimization:** Deferred initialization of `AnimationController` and `ScaleTransition` until `MouseRegion.onEnter` is triggered, instead of initializing them unconditionally in `build()`.
- **Reason:** Many grid and list items use `AppCard` across the app. Unconditionally initializing animation controllers in `build()` for all non-hovered list/grid items creates unnecessary ticker, curve, and animation object allocations. Lazy initialization eliminates this overhead.
- **Verification:** Verified by checking that `AnimationController` is only instantiated on `onEnter` and `ScaleTransition` is conditionally rendered. Tested that UI behavior stays exactly the same, but resource allocation is reduced.
