import os

files = [
    "FlutterUI/lib/features/explore/presentation/pages/category_page.dart",
    "FlutterUI/lib/features/task_manager/presentation/widgets/tasks_tab.dart"
]

for f in files:
    with open(f) as file:
        content = file.read()
        print(f"--- {f} ---")
        if "ListView" in content:
            print("Found ListView")
        else:
            print("Not found")
