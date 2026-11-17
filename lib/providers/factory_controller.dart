import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../models/app_settings.dart';
import '../services/factory_pipeline.dart';
import '../services/file_exporter.dart';
import '../services/github_builder.dart';
import '../services/http_transport.dart';
import '../services/llm_client.dart';

enum RunStatus { idle, running, done, failed }

class FactoryController extends ChangeNotifier {
  FactoryController({FileExporter? exporter})
      : _exporter = exporter ?? FileExporter();

  final FileExporter _exporter;

  RunStatus status = RunStatus.idle;
  final List<String> logs = [];
  FactoryResult? result;
  String? errorMessage;
  String errorDetails = '';

  bool get running => status == RunStatus.running;

  void _log(String message) {
    logs.add(message);
    notifyListeners();
  }

  Future<void> start({
    required String idea,
    required AppSettings settings,
    required bool build,
  }) async {
    if (running) return;
    status = RunStatus.running;
    logs.clear();
    result = null;
    errorMessage = null;
    errorDetails = '';
    notifyListeners();

    final transport = IoHttpTransport();
    try {
      final llm = HttpLlmClient(
        provider: settings.provider,
        apiKey: settings.apiKey.trim(),
        model: settings.model.trim(),
        maxTokens: settings.maxTokens,
        transport: transport,
      );
      final github = build
          ? GitHubBuilder(
              token: settings.githubToken.trim(),
              transport: transport,
              log: _log,
            )
          : null;
      final pipeline = FactoryPipeline(llm: llm, github: github, log: _log);
      result = await pipeline.run(
        idea: idea,
        build: build,
        fixRounds: settings.fixRounds,
      );
      status = RunStatus.done;
      _log('اكتمل العمل.');
    } on FactoryException catch (error) {
      status = RunStatus.failed;
      errorMessage = error.message;
      errorDetails = error.details;
    } catch (error) {
      status = RunStatus.failed;
      errorMessage = 'حدث خطأ غير متوقع.';
      errorDetails = '$error';
    }
    notifyListeners();
  }

  Future<void> shareZip() async {
    final current = result;
    if (current == null) return;
    await _exporter.shareBytes(
      current.zipBytes,
      '${current.projectName}.zip',
      'application/zip',
    );
  }

  Future<void> shareApk() async {
    final current = result;
    final apk = current?.apkBytes;
    if (current == null || apk == null) return;
    await _exporter.shareBytes(
      apk,
      '${current.projectName}.apk',
      'application/vnd.android.package-archive',
    );
  }
}
