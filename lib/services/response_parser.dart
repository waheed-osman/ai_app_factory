import 'dart:convert';

class ParseResult {
  ParseResult(this.files, this.warnings, this.truncated);

  /// Relative path -> full file content.
  final Map<String, String> files;

  /// Non-fatal issues (skipped unsafe paths, duplicates, missing code blocks).
  final List<String> warnings;

  /// Files whose code block never closed, i.e. the reply was cut off.
  final List<String> truncated;
}

final RegExp _headerPattern = RegExp(r'^\s*###\s*FILE:\s*(.+?)\s*$');
final RegExp _fenceOpenPattern = RegExp(r'^\s*(`{3,})[\w+.\-]*\s*$');
final RegExp _fenceClosePattern = RegExp(r'^\s*(`{3,})\s*$');
final RegExp _junkAroundPath = RegExp(r'''^[`"'*\s]+|[`"'*\s]+$''');
final RegExp _driveLetter = RegExp(r'^[A-Za-z]:');

class _Segment {
  _Segment(this.rawPath);

  final String rawPath;
  final List<String> body = [];
}

/// Returns a safe relative path, or null when the path must be rejected.
String? cleanPath(String raw) {
  var path = raw.replaceAll(_junkAroundPath, '').replaceAll('\\', '/');
  while (path.startsWith('./')) {
    path = path.substring(2);
  }
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains('\u0000') ||
      _driveLetter.hasMatch(path)) {
    return null;
  }
  final parts = path.split('/');
  if (parts.any((part) => part.isEmpty || part == '..')) return null;
  return path;
}

/// Parses `### FILE: path` headers followed by fenced code blocks.
///
/// The closing fence is the LAST fence line before the next header, so files
/// that themselves contain fenced blocks (such as a README) stay intact.
ParseResult parseResponse(String text) {
  final segments = <_Segment>[];
  _Segment? current;
  for (final line in const LineSplitter().convert(text)) {
    final header = _headerPattern.firstMatch(line);
    if (header != null) {
      current = _Segment(header.group(1)!);
      segments.add(current);
    } else if (current != null) {
      current.body.add(line);
    }
  }

  final files = <String, String>{};
  final warnings = <String>[];
  final truncated = <String>[];

  for (final segment in segments) {
    final path = cleanPath(segment.rawPath);
    if (path == null) {
      warnings.add('Skipped a file with an unsafe path: ${segment.rawPath}');
      continue;
    }

    final body = segment.body;
    final openIndex = body.indexWhere(_fenceOpenPattern.hasMatch);
    if (openIndex == -1) {
      warnings.add('No code block found for $path.');
      continue;
    }

    var closeIndex = -1;
    for (var i = body.length - 1; i > openIndex; i--) {
      if (_fenceClosePattern.hasMatch(body[i])) {
        closeIndex = i;
        break;
      }
    }

    final List<String> content;
    if (closeIndex == -1) {
      content = body.sublist(openIndex + 1).toList();
      truncated.add(path);
    } else {
      content = body.sublist(openIndex + 1, closeIndex).toList();
    }
    while (content.isNotEmpty && content.last.trim().isEmpty) {
      content.removeLast();
    }

    if (files.containsKey(path)) {
      warnings.add('$path appeared more than once; the last copy was used.');
    }
    files[path] = content.isEmpty ? '' : '${content.join('\n')}\n';
  }

  return ParseResult(files, warnings, truncated);
}
