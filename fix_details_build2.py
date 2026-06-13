import re

with open('FlutterUI/lib/features/explore/presentation/pages/details_page.dart', 'r') as f:
    content = f.read()

content = content.replace("Widget _buildMainContent(BuildContext context, ColorScheme colorScheme, ThemeData theme, SettingsController settings) {", "Widget _buildMainContent(BuildContext context, ColorScheme colorScheme, ThemeData theme) {")

with open('FlutterUI/lib/features/explore/presentation/pages/details_page.dart', 'w') as f:
    f.write(content)
