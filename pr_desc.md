⚡ Bolt: Optimize CachedNetworkImage Memory Usage

🎯 **What**
Added `memCacheWidth` and `memCacheHeight` properties to various `CachedNetworkImage` usages throughout the app.
Created the `.Jules/bolt.md` journal file.

💡 **Why**
By explicitly specifying memory cache dimensions, we prevent the framework from loading and caching original high-resolution images in memory. This significantly reduces the app's overall memory footprint, particularly when scrolling through lists of applications with large icons or viewing detailed pages with high-res screenshots.

✅ **Verification**
- Verified using `flutter test` that existing functionality is preserved.
- Verified using `flutter analyze` that no new issues were introduced.

✨ **Result**
Reduced application memory consumption, especially on pages displaying numerous images, preventing potential Out-of-Memory (OOM) crashes on low-end devices without modifying the visible UI.
