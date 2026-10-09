import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/background_update_runner.dart';

void main() {
  test('reads null-delimited Linux process arguments', () {
    final bytes =
        '/opt/omnistore/frontend\u0000--background-tray\u0000'.codeUnits;
    expect(parseProcCommandLine(bytes), [
      '/opt/omnistore/frontend',
      '--background-tray',
    ]);
  });

  test('parses the final backend command response from noisy output', () {
    final updates = parseBackgroundUpdateOutput('''
diagnostic output
{"status":"success","response":[{"name":"demo","source":"aur","new_version":"2.0"}]}
''');

    expect(updates, hasLength(1));
    expect(updates.single['name'], 'demo');
    expect(updates.single['new_version'], '2.0');
  });

  test('accepts an empty update response', () {
    expect(
      parseBackgroundUpdateOutput('{"status":"success","response":[]}'),
      isEmpty,
    );
  });

  test('rejects output without a JSON update payload', () {
    expect(
      () => parseBackgroundUpdateOutput('backend failed'),
      throwsFormatException,
    );
  });
}
