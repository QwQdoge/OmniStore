import re

files_with_scrollable = [
    "FlutterUI/lib/features/explore/presentation/pages/github_store_page.dart",
    "FlutterUI/lib/features/explore/presentation/pages/flatpak_store_page.dart",
    "FlutterUI/lib/features/apps/apps_page.dart",
    "FlutterUI/lib/features/task_manager/presentation/widgets/updates_tab.dart"
]

for f in files_with_scrollable:
    with open(f) as file:
        content = file.read()
        print(f"--- {f} ---")
        if "ListView" in content:
            print("Found ListView")
            if "Scrollbar" in content:
                print("Found Scrollbar")
            else:
                print("Missing Scrollbar")
        else:
            print("Not found ListView")
