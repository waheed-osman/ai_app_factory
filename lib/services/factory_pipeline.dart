import 'dart:typed_data';

import '../core/errors.dart';
import 'github_builder.dart';
import 'llm_client.dart';
import 'project_packager.dart';
import 'project_validator.dart';
import 'prompts.dart';
import 'response_parser.dart';

class FactoryResult {
  const FactoryResult({
    required this.projectName,
    required this.files,
    required this.zipBytes,
    required this.warnings,
    this.apkBytes,
    this.repoUrl,
  });

  final String projectName;
  final Map<String, String> files;
  final Uint8List zipBytes;
  final Uint8List? apkBytes;
  final String? repoUrl;

  /// Problems that were still present when the pipeline stopped retrying.
  final List<String> warnings;
}

class _Draft {
  const _Draft(this.files, this.problems);

  final Map<String, String> files;
  final List<String> problems;
}

/// idea -> AI -> parse -> validate (+ fix rounds) -> ZIP -> optional APK build.
class FactoryPipeline {
  FactoryPipeline({required this.llm, required this.log, this.github});

  final LlmClient llm;
  final GitHubBuilder? github;
  final LogFn log;

  Future<FactoryResult> run({
    required String idea,
    bool build = false,
    int fixRounds = 2,
  }) async {
    final cleanIdea = idea.trim();
    if (cleanIdea.isEmpty) {
      throw FactoryException('اكتب فكرة التطبيق أولاً.');
    }
    final builder = github;
    if (build && builder == null) {
      throw FactoryException('رمز GitHub مطلوب لبناء الـ APK.');
    }

    final draft = await _generate(cleanIdea, fixRounds);
    var files = draft.files;
    final projectName = packageName(files);
    if (!files.containsKey('lib/main.dart') || projectName == null) {
      throw FactoryException(
        'الذكاء الاصطناعي لم يُنتج ملفات التطبيق الأساسية.',
        details: draft.problems.join('\n'),
      );
    }

    files = injectStandardFiles(files, projectName);
    var zip = buildZip(files);
    log('تم تجهيز ${files.length} ملفاً وضغطها في ملف ZIP.');

    Uint8List? apk;
    String? repoUrl;
    if (build && builder != null) {
      final stamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final repo = await builder.createRepo(
        '${projectName.replaceAll('_', '-')}-$stamp',
      );
      repoUrl = repo.url;
      log('تم إنشاء مستودع خاص: ${repo.url}');

      var sha = await builder.pushFiles(
        repo,
        files,
        'Initial commit from AI App Factory',
      );
      log('تم رفع الملفات، بانتظار بناء الـ APK (قد يستغرق عدة دقائق)...');

      for (var attempt = 0;; attempt++) {
        final ciRun = await builder.waitForRun(repo, sha);
        final runId = ciRun['id'] as int;
        if (ciRun['conclusion'] == 'success') {
          apk = await builder.downloadApk(repo, runId);
          log('تم تنزيل ملف الـ APK بنجاح.');
          break;
        }

        final buildLog = await builder.failureLog(repo, runId);
        if (attempt >= fixRounds) {
          throw BuildFailedException(
            'فشل بناء الـ APK على GitHub.',
            details: buildLog,
          );
        }
        log('فشل البناء، سأطلب من الذكاء الاصطناعي إصلاح الأخطاء '
            '(محاولة ${attempt + 1} من $fixRounds)...');
        final reply = await llm.generate(
          system: systemPrompt,
          prompt: buildFixPrompt(
            idea: cleanIdea,
            files: files,
            problems: [
              'The CI build failed. Fix the code. Tail of the build log:\n'
                  '$buildLog',
            ],
          ),
        );
        final parsed = parseResponse(reply.text);
        final merged = sanitizeFiles({...files, ...parsed.files}).files;
        files = injectStandardFiles(merged, projectName);
        zip = buildZip(files);
        sha = await builder.pushFiles(
          repo,
          files,
          'Fix build errors (round ${attempt + 1})',
        );
        log('تم رفع الإصلاح، بانتظار بناء جديد...');
      }
    }

    return FactoryResult(
      projectName: projectName,
      files: files,
      zipBytes: zip,
      apkBytes: apk,
      repoUrl: repoUrl,
      warnings: draft.problems,
    );
  }

  Future<_Draft> _generate(String idea, int fixRounds) async {
    log('جاري تصميم التطبيق وكتابة الكود بالذكاء الاصطناعي...');
    var reply = await llm.generate(
      system: systemPrompt,
      prompt: buildUserPrompt(idea),
    );

    var files = <String, String>{};
    var problems = <String>[];
    for (var attempt = 0; attempt <= fixRounds; attempt++) {
      final parsed = parseResponse(reply.text);
      final sanitized = sanitizeFiles({...files, ...parsed.files});
      files = sanitized.files;

      if (sanitized.dropped.isNotEmpty) {
        log('تم تجاهل ${sanitized.dropped.length} ملف خاص بالمنصة '
            '(يولّدها المصنع تلقائياً).');
      }
      for (final warning in parsed.warnings) {
        log('تنبيه: $warning');
      }

      problems = [
        for (final path in parsed.truncated)
          'File "$path" is cut off (no closing code fence). '
              'Re-send it complete.',
        ...validateFlutterProject(files),
      ];
      if (problems.isEmpty) {
        log('اجتاز المشروع الفحص الثابت.');
        break;
      }
      if (attempt == fixRounds) {
        log('بقيت ${problems.length} ملاحظة بعد استنفاد المحاولات.');
        break;
      }

      log('وُجدت ${problems.length} ملاحظة، سأطلب إصلاحها '
          '(محاولة ${attempt + 1} من $fixRounds)...');
      reply = await llm.generate(
        system: systemPrompt,
        prompt: buildFixPrompt(idea: idea, files: files, problems: problems),
      );
    }
    return _Draft(files, problems);
  }
}
