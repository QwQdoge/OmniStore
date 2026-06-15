import os
import re

files_with_cached_network_image = [
    "FlutterUI/lib/features/home/home_page.dart",
    "FlutterUI/lib/features/explore/presentation/widgets/app_screenshots.dart",
    "FlutterUI/lib/features/explore/presentation/widgets/screenshot_viewer.dart",
    "FlutterUI/lib/features/explore/presentation/widgets/app_details_header.dart",
    "FlutterUI/lib/features/explore/presentation/pages/github_store_page.dart",
    "FlutterUI/lib/features/explore/presentation/pages/flatpak_store_page.dart",
    "FlutterUI/lib/features/explore/presentation/pages/search_page.dart",
    "FlutterUI/lib/features/apps/apps_page.dart",
    "FlutterUI/lib/features/task_manager/presentation/pages/download_page.dart"
]

for file_path in files_with_cached_network_image:
    with open(file_path, "r") as f:
        content = f.read()

    # Check if memCacheWidth or memCacheHeight is already present
    if "memCacheWidth" in content or "memCacheHeight" in content:
        print(f"Skipping {file_path} as it already has memCacheWidth/Height")
    else:
        print(f"File {file_path} missing memCacheWidth/Height")
