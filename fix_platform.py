import re

with open('FlutterUI/lib/services/backend/platform_environment.dart', 'r') as f:
    content = f.read()

# First replace
content = re.sub(
    r'\\\'',
    r"'",
    content
)

with open('FlutterUI/lib/services/backend/platform_environment.dart', 'w') as f:
    f.write(content)
