import 'package:ai_app_factory/services/project_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  Map<String, String> validProject() => {
        'pubspec.yaml': demoPubspec,
        'lib/main.dart': demoMain,
      };

  test('accepts a consistent project', () {
    expect(validateFlutterProject(validProject()), isEmpty);
  });

  test('reports missing core files', () {
    final problems = validateFlutterProject({'lib/main.dart': demoMain});
    expect(problems, contains('pubspec.yaml is missing.'));
  });

  test('detects a package import of a file that does not exist', () {
    final files = validProject()
      ..['lib/main.dart'] =
          "import 'package:demo_app/missing.dart';\nvoid main() {}\n";

    final problems = validateFlutterProject(files);

    expect(problems.single, contains('lib/missing.dart does not exist'));
  });

  test('detects a broken relative import', () {
    final files = validProject()
      ..['lib/screens/home.dart'] = "import '../widgets/card.dart';\n";

    final problems = validateFlutterProject(files);

    expect(problems.single, contains('lib/widgets/card.dart does not exist'));
  });

  test('accepts a valid relative import', () {
    final files = validProject()
      ..['lib/screens/home.dart'] = "import '../widgets/card.dart';\n"
      ..['lib/widgets/card.dart'] = 'class CardView {}\n';

    expect(validateFlutterProject(files), isEmpty);
  });

  test('detects a package that pubspec does not declare', () {
    final files = validProject()
      ..['lib/main.dart'] =
          "import 'package:provider/provider.dart';\nvoid main() {}\n";

    final problems = validateFlutterProject(files);

    expect(problems.single, contains("package 'provider'"));
  });

  test('detects TODO placeholders', () {
    final files = validProject()
      ..['lib/main.dart'] = 'void main() {\n  // TODO: write this\n}\n';

    expect(validateFlutterProject(files).single, contains('TODO'));
  });

  test('requires flutter_lints when analysis_options includes it', () {
    final files = validProject()
      ..['pubspec.yaml'] = demoPubspec.replaceAll('  flutter_lints: ^4.0.0\n', '')
      ..['analysis_options.yaml'] =
          'include: package:flutter_lints/flutter.yaml\n';

    expect(validateFlutterProject(files).single, contains('flutter_lints'));
  });

  test('reads package name and dependencies from pubspec', () {
    expect(packageName({'pubspec.yaml': demoPubspec}), 'demo_app');
    expect(
      pubspecDependencies(demoPubspec),
      containsAll(['flutter', 'flutter_test', 'flutter_lints']),
    );
  });
}
