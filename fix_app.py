import re

def fix_file(filepath, replacements):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    for search, replace in replacements:
        if search in content:
            content = content.replace(search, replace)
        else:
            print(f"Warning: Could not find search string in {filepath}")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

replacements = {
    'FlutterUI/lib/features/home/home_page.dart': [
        (
            "await browse.fetchRecommendations();\n    await _fetchAIPick();",
            "await browse.fetchRecommendations();\n    if (!mounted) return;\n    await _fetchAIPick();"
        ),
        (
            "FilePickerResult? result = await FilePicker.pickFiles(\n      type: FileType.custom,\n      allowedExtensions: ['txt', 'json'],\n    );\n\n    if (!mounted) return;",
            "FilePickerResult? result = await FilePicker.pickFiles(\n      type: FileType.custom,\n      allowedExtensions: ['txt', 'json'],\n    );\n\n    if (!mounted) return;"
        )
    ],
    'FlutterUI/lib/features/explore/presentation/pages/details_page.dart': [
        (
            "final cleanOrphansResult = await showDialog<bool?>(\n      context: context,\n      builder: (context) {",
            "final cleanOrphansResult = await showDialog<bool?>(\n      context: context,\n      builder: (context) {" # showDialog requires context! But wait, is it after an await?
            # In `_handleAction`, it is `final cleanOrphansResult = await showDialog...` which is the FIRST await in the method! So it doesn't need mounted check BEFORE it.
        )
    ]
}
