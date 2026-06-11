import os
import re

def fix_file(filepath):
    with open(filepath, "r") as f:
        content = f.read()

    # Simple regex to pick the non-HEAD part of merge conflicts
    # This works for the specific format in the files
    fixed = re.sub(r"<<<<<<< HEAD.*?=======([\s\S]*?)>>>>>>> [a-f0-9]+", r"\1", content)

    with open(filepath, "w") as f:
        f.write(fixed)

fix_file("FlutterUI/lib/features/explore/presentation/pages/details_page.dart")
fix_file("FlutterUI/lib/services/backend_service.dart")
