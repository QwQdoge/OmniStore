import re

def fix_file(filepath, replacements):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    for search, replace in replacements:
        if search in content:
            content = content.replace(search, replace)
        else:
            print(f"Warning: Could not find '{search}' in {filepath}")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

replacements = {
    'FlutterUI/lib/app/main_navigation.dart': [
        (
            "await wm.windowManager.setPreventClose(false);\n    await wm.windowManager.close();",
            "if (!mounted) return;\n    await wm.windowManager.setPreventClose(false);\n    await wm.windowManager.close();"
        )
    ],
    'FlutterUI/lib/features/task_manager/presentation/pages/download_page.dart': [
        (
            "if (!context.mounted) return;\n                        if (results.isNotEmpty) {",
            "if (!mounted) return;\n                        if (results.isNotEmpty) {" # Wait, context.mounted is valid in Flutter 3.7+ but maybe we can just stick to `context.mounted` or `mounted`? State subclasses have `mounted`, but inside a `ListView.builder` itemBuilder, `mounted` might not be available unless it's a State class method. Let's leave context.mounted.
        )
    ]
}
