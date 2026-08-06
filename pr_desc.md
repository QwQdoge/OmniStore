## What
Added `prototypeItem` to `FlatpakAppListSkeleton` inside `FlutterUI/lib/features/explore/presentation/widgets/flatpak_app_list.dart`.

## Why
`ListView.builder` inside Skeleton loading states should include a `prototypeItem` matching the dimensions of the skeleton items to ensure efficient scroll virtualization and avoid redundant layout calculations across the viewport. This directly addresses the missing scroll virtualization issue reported by Bolt.

## Measured Improvement
Provides O(1) list virtualization performance during loading states, significantly reducing layout operations and engine overhead when rendering repetitive skeleton items.

## Coverage
- `FlutterUI/lib/features/explore/presentation/widgets/flatpak_app_list.dart`
- Tests passed.
