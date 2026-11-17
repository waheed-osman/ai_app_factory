import 'package:ai_app_factory/core/errors.dart';
import 'package:ai_app_factory/services/factory_pipeline.dart';
import 'package:ai_app_factory/services/llm_client.dart';
import 'package:ai_app_factory/services/templates.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _FakeLlm implements LlmClient {
  _FakeLlm(this.replies);

  final List<String> replies;
  final List<String> prompts = [];

  @override
  Future<LlmReply> generate({
    required String system,
    required String prompt,
  }) async {
    prompts.add(prompt);
    return LlmReply(replies[prompts.length - 1]);
  }
}

void main() {
  test('accepts a valid first reply without asking for fixes', () async {
    final llm = _FakeLlm([
      fileBlock('pubspec.yaml', demoPubspec) +
          fileBlock('lib/main.dart', demoMain),
    ]);
    final logs = <String>[];
    final pipeline = FactoryPipeline(llm: llm, log: logs.add);

    final result = await pipeline.run(idea: 'a demo app');

    expect(llm.prompts.length, 1);
    expect(result.projectName, 'demo_app');
    expect(result.warnings, isEmpty);
    expect(result.files.containsKey(workflowPath), isTrue);
    expect(result.apkBytes, isNull);

    final names = ZipDecoder()
        .decodeBytes(result.zipBytes)
        .files
        .map((file) => file.name)
        .toList();
    expect(names, containsAll(['pubspec.yaml', 'lib/main.dart', workflowPath]));
  });

  test('asks the AI to fix a missing file and merges the answer', () async {
    final llm = _FakeLlm([
      fileBlock('pubspec.yaml', demoPubspec) +
          fileBlock(
            'lib/main.dart',
            "import 'package:demo_app/missing.dart';\nvoid main() {}",
          ),
      fileBlock('lib/missing.dart', 'class Missing {}'),
    ]);
    final pipeline = FactoryPipeline(llm: llm, log: (_) {});

    final result = await pipeline.run(idea: 'a demo app');

    expect(llm.prompts.length, 2);
    expect(llm.prompts[1], contains('lib/missing.dart does not exist'));
    expect(result.files.containsKey('lib/missing.dart'), isTrue);
    expect(result.files['lib/main.dart'], contains('package:demo_app/missing'));
    expect(result.warnings, isEmpty);
  });

  test('stops after the allowed rounds and reports remaining problems',
      () async {
    final broken = fileBlock('pubspec.yaml', demoPubspec) +
        fileBlock(
          'lib/main.dart',
          "import 'package:demo_app/missing.dart';\nvoid main() {}",
        );
    final llm = _FakeLlm([broken, broken]);
    final pipeline = FactoryPipeline(llm: llm, log: (_) {});

    final result = await pipeline.run(idea: 'a demo app', fixRounds: 1);

    expect(llm.prompts.length, 2);
    expect(result.warnings, isNotEmpty);
  });

  test('fails clearly when the AI returns no project files', () async {
    final llm = _FakeLlm(['Sorry, I cannot help with that.']);
    final pipeline = FactoryPipeline(llm: llm, log: (_) {});

    expect(
      () => pipeline.run(idea: 'a demo app', fixRounds: 0),
      throwsA(isA<FactoryException>()),
    );
  });

  test('requires a GitHub builder when an APK is requested', () async {
    final pipeline = FactoryPipeline(llm: _FakeLlm(const []), log: (_) {});

    expect(
      () => pipeline.run(idea: 'a demo app', build: true),
      throwsA(isA<FactoryException>()),
    );
  });
}
