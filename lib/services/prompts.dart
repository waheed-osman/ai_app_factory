const String systemPrompt = r'''You are a senior Flutter/Dart engineer. You turn an app idea into a complete, compilable Flutter application.

OUTPUT FORMAT (strict, parsed by a program):
- For every file, write a header line exactly like: ### FILE: relative/path
- Right after the header, write ONE fenced code block with the COMPLETE content of that file.
- Write nothing outside file blocks: no explanations, no summaries, no notes.
- Paths are relative to the project root. Never use absolute paths or "..".

PROJECT RULES:
- Always include: pubspec.yaml, analysis_options.yaml, lib/main.dart and at least one unit test under test/ (never name it widget_test.dart).
- Do NOT output android/, ios/, web/, desktop folders or .github/. The factory generates them.
- pubspec.yaml: lower_snake_case package name; environment sdk ">=3.3.0 <4.0.0"; dependencies use caret versions of well-known pub.dev packages you are sure exist; keep dependencies minimal; dev_dependencies must contain flutter_test and flutter_lints (^4.0.0).
- Use Material 3, null safety and a clean structure: lib/core, lib/models, lib/providers or lib/services, lib/screens, lib/widgets.
- State management: provider unless the idea clearly needs something else. Persist data locally with shared_preferences when needed.
- Every file must be complete. No TODO comments, no placeholders, no "rest of the code" shortcuts.
- Every import must resolve: use package:<package_name>/... or correct relative paths, and every symbol you use must be defined.
- Do not require API keys or native platform configuration unless the idea demands it.
- Use the language of the idea for all UI strings. For right-to-left languages wrap the app with Directionality in MaterialApp.builder instead of adding localization packages.
''';

String buildUserPrompt(String idea) {
  return 'Build this Flutter app:\n\n$idea\n\n'
      'Return every project file in the required format.';
}

String buildFixPrompt({
  required String idea,
  required Map<String, String> files,
  required List<String> problems,
}) {
  final visible = <String, String>{
    for (final entry in files.entries)
      if (!entry.key.startsWith('.github/')) entry.key: entry.value,
  };
  final buffer = StringBuffer()
    ..writeln('The Flutter project below was generated for this idea:')
    ..writeln(idea)
    ..writeln()
    ..writeln('It has these problems:');
  for (final problem in problems) {
    buffer.writeln('- $problem');
  }
  buffer
    ..writeln()
    ..writeln(
      'Return ONLY the files that must change or must be added, each one '
      'complete, using the same output format. Do not repeat unchanged files.',
    )
    ..writeln()
    ..writeln('CURRENT PROJECT FILES:')
    ..write(renderFiles(visible));
  return buffer.toString();
}

/// Renders files in the same `### FILE:` format the model must produce.
String renderFiles(Map<String, String> files) {
  final buffer = StringBuffer();
  final paths = files.keys.toList()..sort();
  for (final path in paths) {
    final content = files[path]!;
    final fence = _fenceFor(content);
    buffer
      ..writeln('### FILE: $path')
      ..writeln(fence)
      ..write(content.endsWith('\n') ? content : '$content\n')
      ..writeln(fence)
      ..writeln();
  }
  return buffer.toString();
}

String _fenceFor(String content) {
  var longest = 0;
  for (final match in RegExp(r'`+').allMatches(content)) {
    final length = match.end - match.start;
    if (length > longest) longest = length;
  }
  return '`' * (longest < 3 ? 3 : longest + 1);
}
