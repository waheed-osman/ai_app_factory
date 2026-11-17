const String demoPubspec = 'name: demo_app\n'
    'environment:\n'
    '  sdk: ">=3.3.0 <4.0.0"\n'
    'dependencies:\n'
    '  flutter:\n'
    '    sdk: flutter\n'
    'dev_dependencies:\n'
    '  flutter_test:\n'
    '    sdk: flutter\n'
    '  flutter_lints: ^4.0.0\n';

const String demoMain = "import 'package:flutter/material.dart';\n"
    'void main() => runApp(const MaterialApp());\n';

/// One `### FILE:` block exactly as the AI must produce it.
String fileBlock(String path, String code) =>
    '### FILE: $path\n```dart\n$code\n```\n';
