# Performance Optimization Journal

**Optimization:** Added `prototypeItem` to `ListView.builder` widgets for uniform-height lists.

**Files modified:**
- `FlutterUI/lib/features/explore/presentation/widgets/flatpak_app_list.dart`
- `FlutterUI/lib/features/explore/presentation/widgets/search_results_view.dart`
- `FlutterUI/lib/features/apps/widgets/installed_app_list.dart`

**Reasoning:**
By supplying a `prototypeItem` to vertical lists containing uniform-sized widgets (like `ListTile`s wrapped in `AppCard`), Flutter avoids performing continuous layout passes to calculate the vertical extent of items as they scroll onto the screen. This statically forces the vertical extent of every list element to match the prototype, significantly improving list virtualization frame rendering performance and ensuring that the UI scrollbar size is fully accurate from the first frame, rather than recalculating its thumb size dynamically as the user scrolls.
