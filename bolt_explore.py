import os
from pprint import pprint

# Looking at `ListView.builder` usage.
files = [
    "FlutterUI/lib/features/task_manager/presentation/pages/download_page.dart",
    "FlutterUI/lib/features/apps/apps_page.dart"
]

for f in files:
    with open(f) as file:
        content = file.read()
        print(f"--- {f} ---")
        if "ListView.builder" in content:
            print("Found ListView.builder")
        else:
            print("Not found")
