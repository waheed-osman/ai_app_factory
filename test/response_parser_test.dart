import 'package:ai_app_factory/services/response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('parses several files with their exact content', () {
    final text = fileBlock('pubspec.yaml', 'name: demo_app') +
        fileBlock('lib/main.dart', 'void main() {}\n// done');

    final result = parseResponse(text);

    expect(result.files.keys, ['pubspec.yaml', 'lib/main.dart']);
    expect(result.files['pubspec.yaml'], 'name: demo_app\n');
    expect(result.files['lib/main.dart'], 'void main() {}\n// done\n');
    expect(result.warnings, isEmpty);
    expect(result.truncated, isEmpty);
  });

  test('keeps nested code fences inside a file', () {
    final text = '### FILE: README.md\n'
        '```markdown\n'
        '# Title\n'
        '```bash\n'
        'flutter run\n'
        '```\n'
        'after\n'
        '```\n'
        '### FILE: lib/a.dart\n'
        '```dart\n'
        'int a = 1;\n'
        '```\n';

    final result = parseResponse(text);

    expect(
      result.files['README.md'],
      '# Title\n```bash\nflutter run\n```\nafter\n',
    );
    expect(result.files['lib/a.dart'], 'int a = 1;\n');
  });

  test('rejects unsafe paths and reports them', () {
    final text = fileBlock('../evil.dart', 'x') +
        fileBlock('/etc/passwd', 'x') +
        fileBlock('C:/windows/x.dart', 'x') +
        fileBlock('lib/ok.dart', 'int ok = 1;');

    final result = parseResponse(text);

    expect(result.files.keys, ['lib/ok.dart']);
    expect(result.warnings.length, 3);
  });

  test('cleans decorated paths', () {
    expect(cleanPath('`lib/main.dart`'), 'lib/main.dart');
    expect(cleanPath('./lib\\main.dart'), 'lib/main.dart');
    expect(cleanPath('lib//main.dart'), isNull);
    expect(cleanPath(''), isNull);
  });

  test('flags a file whose code block never closes', () {
    final text = '### FILE: lib/main.dart\n```dart\nvoid main() {\n';

    final result = parseResponse(text);

    expect(result.truncated, ['lib/main.dart']);
    expect(result.files['lib/main.dart'], 'void main() {\n');
  });

  test('warns when a header has no code block', () {
    final result = parseResponse('### FILE: lib/main.dart\njust text\n');

    expect(result.files, isEmpty);
    expect(result.warnings.single, contains('lib/main.dart'));
  });
}
