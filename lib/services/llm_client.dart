import '../core/errors.dart';
import '../models/app_settings.dart';
import 'http_transport.dart';

class LlmReply {
  const LlmReply(this.text, {this.truncated = false});

  final String text;

  /// True when the provider stopped because it hit the output token limit.
  final bool truncated;
}

abstract class LlmClient {
  Future<LlmReply> generate({required String system, required String prompt});
}

class HttpLlmClient implements LlmClient {
  HttpLlmClient({
    required this.provider,
    required this.apiKey,
    required this.model,
    required this.maxTokens,
    required this.transport,
  });

  final LlmProvider provider;
  final String apiKey;
  final String model;
  final int maxTokens;
  final HttpTransport transport;

  @override
  Future<LlmReply> generate({required String system, required String prompt}) {
    return switch (provider) {
      LlmProvider.anthropic => _anthropic(system, prompt),
      LlmProvider.gemini => _gemini(system, prompt),
      LlmProvider.openrouter => _openRouter(system, prompt),
    };
  }

  Future<LlmReply> _anthropic(String system, String prompt) async {
    final response = await _post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      {
        'model': model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    );
    final data = response.json as Map<String, dynamic>;
    final blocks = data['content'] as List<dynamic>? ?? const [];
    final text = blocks
        .whereType<Map<String, dynamic>>()
        .where((block) => block['type'] == 'text')
        .map((block) => block['text'] as String? ?? '')
        .join();
    return _reply(text, data['stop_reason'] == 'max_tokens');
  }

  Future<LlmReply> _gemini(String system, String prompt) async {
    final response = await _post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      ),
      {'x-goog-api-key': apiKey},
      {
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'maxOutputTokens': maxTokens},
      },
    );
    final data = response.json as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      throw FactoryException('Gemini لم يُرجع أي نتيجة.',
          details: response.text);
    }
    final candidate = candidates.first as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    final text = parts
        .whereType<Map<String, dynamic>>()
        .where((part) => part['thought'] != true)
        .map((part) => part['text'] as String? ?? '')
        .join();
    return _reply(text, candidate['finishReason'] == 'MAX_TOKENS');
  }

  Future<LlmReply> _openRouter(String system, String prompt) async {
    final response = await _post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      {'Authorization': 'Bearer $apiKey'},
      {
        'model': model,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ],
      },
    );
    final data = response.json as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw FactoryException('OpenRouter لم يُرجع أي نتيجة.',
          details: response.text);
    }
    final choice = choices.first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>?;
    final text = message?['content'] as String? ?? '';
    return _reply(text, choice['finish_reason'] == 'length');
  }

  LlmReply _reply(String text, bool truncated) {
    if (text.trim().isEmpty) {
      throw FactoryException('المزوّد أرجع ردّاً فارغاً.');
    }
    return LlmReply(text, truncated: truncated);
  }

  Future<HttpResult> _post(
    Uri url,
    Map<String, String> headers,
    Map<String, Object?> body,
  ) async {
    var attempt = 0;
    while (true) {
      final result = await transport.send(
        'POST',
        url,
        headers: headers,
        jsonBody: body,
      );
      if (result.ok) return result;

      final retryable = const {429, 500, 502, 503, 504}.contains(result.status);
      if (!retryable || attempt >= 2) {
        final text = result.text;
        throw FactoryException(
          'خطأ من مزوّد الذكاء الاصطناعي (HTTP ${result.status}).',
          details: text.length > 1500 ? text.substring(0, 1500) : text,
        );
      }
      attempt++;
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    }
  }
}
