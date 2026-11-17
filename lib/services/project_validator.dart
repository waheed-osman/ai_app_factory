final RegExp _importPattern = RegExp(
  r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);
final RegExp _namePattern = RegExp(
  r'^name:\s*[\x22\x27]?([A-Za-z0-9_]+)[\x22\x27]?\s*$',
  multiLine: true,
);
final RegExp _placeholderPattern = RegExp(
  r'//\s*TODO|rest of (the )?(code|file)',
  caseSensitive: false,
);
final RegExp _mainPattern = RegExp(r'\bmain\s*\(');
final RegExp _topLevelKey = RegExp(r'^([A-Za-z_]+):');
final RegExp _dependencyKey = RegExp(r'^  ([A-Za-z0-9_]+):');

/// The Dart package name declared in pubspec.yaml, or null if missing.
String? packageName(Map<String, String> files) {
  final pubspec = files['pubspec.yaml'];
  if (pubspec == null) return null;
  return _namePattern.firstMatch(pubspec)?.group(1);
}

/// Names listed under dependencies, dev_dependencies and overrides.
Set<String> pubspecDependencies(String pubspec) {
  const sections = {'dependencies', 'dev_dependencies', 'dependency_overrides'};
  final dependencies = <String>{};
  String? section;
  for (final line in pubspec.split('\n')) {
    final top = _topLevelKey.firstMatch(line);
    if (top != null) {
      section = top.group(1);
      continue;
    }
    if (sections.contains(section)) {
      final match = _dependencyKey.firstMatch(line);
      if (match != null) dependencies.add(match.group(1)!);
    }
  }
  return dependencies;
}

/// Static checks that catch the most common generation mistakes before the
/// (slow) cloud build. Returns human-readable problems; empty means OK.
List<String> validateFlutterProject(Map<String, String> files) {
  final problems = <String>[];
  final pubspec = files['pubspec.yaml'];
  if (pubspec == null) problems.add('pubspec.yaml is missing.');
  if (!files.containsKey('lib/main.dart')) {
    problems.add('lib/main.dart is missing.');
  }
  if (pubspec == null) return problems;

  final name = packageName(files);
  if (name == null) {
    problems.add("pubspec.yaml has no valid top-level 'name:' field.");
  }
  final dependencies = pubspecDependencies(pubspec);
  if (!dependencies.contains('flutter')) {
    problems.add("pubspec.yaml must depend on the 'flutter' SDK package.");
  }

  final mainSource = files['lib/main.dart'];
  if (mainSource != null && !_mainPattern.hasMatch(mainSource)) {
    problems.add('lib/main.dart has no main() function.');
  }

  final analysis = files['analysis_options.yaml'];
  if (analysis != null &&
      analysis.contains('flutter_lints') &&
      !dependencies.contains('flutter_lints')) {
    problems.add(
      'analysis_options.yaml includes flutter_lints but pubspec.yaml does '
      'not list flutter_lints in dev_dependencies.',
    );
  }

  final dartPaths = files.keys.where((path) => path.endsWith('.dart')).toList()
    ..sort();
  for (final path in dartPaths) {
    final content = files[path]!;
    if (_placeholderPattern.hasMatch(content)) {
      problems.add('$path contains a TODO or placeholder; write the real code.');
    }
    for (final match in _importPattern.allMatches(content)) {
      final problem = _checkImport(
        path: path,
        uri: match.group(1)!,
        name: name,
        dependencies: dependencies,
        files: files,
      );
      if (problem != null) problems.add(problem);
    }
  }
  return problems;
}

String? _checkImport({
  required String path,
  required String uri,
  required String? name,
  required Set<String> dependencies,
  required Map<String, String> files,
}) {
  if (uri.startsWith('dart:')) return null;

  if (uri.startsWith('package:')) {
    final rest = uri.substring('package:'.length);
    final slash = rest.indexOf('/');
    final package = slash == -1 ? rest : rest.substring(0, slash);
    final relative = slash == -1 ? '' : rest.substring(slash + 1);
    if (name != null && package == name) {
      return files.containsKey('lib/$relative')
          ? null
          : "$path imports '$uri' but lib/$relative does not exist.";
    }
    if (!dependencies.contains(package)) {
      return "$path imports package '$package' which is not declared in "
          'pubspec.yaml.';
    }
    return null;
  }

  final slash = path.lastIndexOf('/');
  final directory = slash == -1 ? '' : path.substring(0, slash);
  final target = _normalize(directory.isEmpty ? uri : '$directory/$uri');
  return files.containsKey(target)
      ? null
      : "$path imports '$uri' but $target does not exist.";
}

String _normalize(String path) {
  final stack = <String>[];
  for (final part in path.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (stack.isNotEmpty) stack.removeLast();
    } else {
      stack.add(part);
    }
  }
  return stack.join('/');
}
