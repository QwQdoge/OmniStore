import os

files_with_horizontal_scroll = [
    "FlutterUI/lib/core/widgets/ai_app_resolver.dart",
    "FlutterUI/lib/features/home/home_page.dart",
    "FlutterUI/lib/features/explore/presentation/widgets/app_screenshots.dart",
    "FlutterUI/lib/features/explore/presentation/widgets/app_details_header.dart",
    "FlutterUI/lib/features/explore/presentation/pages/search_page.dart",
    "FlutterUI/lib/features/task_manager/presentation/pages/download_page.dart"
]

for f in files_with_horizontal_scroll:
    with open(f) as file:
        content = file.read()
        print(f"--- {f} ---")
        if "thumbVisibility: true" in content:
            print("Found thumbVisibility: true")
        else:
            print("Missing thumbVisibility: true")
