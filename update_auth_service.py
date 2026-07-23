import sys

filepath = 'FlutterUI/lib/features/auth/auth_service.dart'
with open(filepath, 'r') as f:
    content = f.read()

content = content.replace('class AuthService extends ChangeNotifier {', '''class AuthService extends ChangeNotifier {
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }''')

content = content.replace('  @override\n  void dispose() {\n    _linkSubscription?.cancel();\n    super.dispose();\n  }', '''  @override
  void dispose() {
    _disposed = true;
    _linkSubscription?.cancel();
    super.dispose();
  }''')

with open(filepath, 'w') as f:
    f.write(content)
