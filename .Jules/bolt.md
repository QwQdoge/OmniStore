# Image Memory Optimization

Added `memCacheWidth` and `memCacheHeight` to `CachedNetworkImage` widgets to resize images before caching in memory.

This improves memory usage when dealing with large images or numerous icon images in lists.

It resizes:
- app icons to reasonable scales (80x80, 108x108, 200x200 depending on placement)
- hero banner image to 880 width.
- detail page hero to 720 width.
- detail page icon to 200 width.
