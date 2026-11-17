import 'dart:convert';

import 'package:ai_app_factory/services/project_packager.dart';
import 'package:ai_app_factory/services/templates.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('drops platform folders and CI files written by the AI', () {
    final result = sanitizeFiles({
      'pubspec.yaml': demoPubspec,
      'android/app/build.gradle': 'x',
      'ios/Runner/Info.plist': 'x',
      '.github/workflows/evil.yml': 'x',
      'lib/main.dart': demoMain,
    });

    expect(result.files.keys, ['pubspec.yaml', 'lib/main.dart']);
    expect(result.dropped.length, 3);
  });

  test('injects the workflow with the package name and default files', () {
    final files = injectStandardFiles({
      'pubspec.yaml': demoPubspec,
      'lib/main.dart': demoMain,
    }, 'demo_app');

    expect(files[workflowPath], contains('--project-name demo_app'));
    expect(files[workflowPath], isNot(contains('__PROJECT_NAME__')));
    expect(files['.gitignore'], isNotEmpty);
    expect(files['analysis_options.yaml'], contains('flutter_lints'));
  });

  test('keeps an analysis_options file the AI already wrote', () {
    final files = injectStandardFiles({
      'pubspec.yaml': demoPubspec,
      'analysis_options.yaml': 'custom: true\n',
    }, 'demo_app');

    expect(files['analysis_options.yaml'], 'custom: true\n');
  });

  test('zip round trip keeps every file and its text', () {
    final zip = buildZip({
      'pubspec.yaml': demoPubspec,
      'lib/main.dart': demoMain,
      'lib/arabic.dart': "const String title = 'مرحبا';\n",
    });

    final archive = ZipDecoder().decodeBytes(zip);
    final names = archive.files.map((file) => file.name).toList();

    expect(names, ['lib/arabic.dart', 'lib/main.dart', 'pubspec.yaml']);
    final arabic = archive.files.firstWhere((f) => f.name == 'lib/arabic.dart');
    expect(
      utf8.decode(arabic.content as List<int>),
      "const String title = 'مرحبا';\n",
    );
  });
}
