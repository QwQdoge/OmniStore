import re

with open('FlutterUI/lib/features/explore/presentation/pages/details_page.dart', 'r') as f:
    content = f.read()

content = content.replace("_buildMainContent(context, colorScheme, theme, context.read<SettingsController>())", "_buildMainContent(context, colorScheme, theme)")

with open('FlutterUI/lib/features/explore/presentation/pages/details_page.dart', 'w') as f:
    f.write(content)
