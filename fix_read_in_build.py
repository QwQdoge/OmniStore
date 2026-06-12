import re

def remove_read_from_build(file_path, provider_name, var_name):
    with open(file_path, 'r') as f:
        content = f.read()

    # Find the final var_name = context.read<provider_name>();
    pattern = r'\s*final\s+' + var_name + r'\s*=\s*context\.read<' + provider_name + r'>\(\)\;'
    content = re.sub(pattern, '', content)

    # Replace usages of var_name with context.read<provider_name>()
    content = content.replace(var_name + '.', f'context.read<{provider_name}>().')

    with open(file_path, 'w') as f:
        f.write(content)

remove_read_from_build('FlutterUI/lib/app/main_navigation.dart', 'NavigationController', 'nav')
remove_read_from_build('FlutterUI/lib/core/layout/adaptive_navigation_shell.dart', 'NavigationController', 'nav')
remove_read_from_build('FlutterUI/lib/features/explore/presentation/pages/details_page.dart', 'SettingsController', 'settings')
