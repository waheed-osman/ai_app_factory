enum LlmProvider {
  anthropic('Anthropic (Claude)', 'claude-sonnet-5-5'),
  gemini('Google Gemini', 'gemini-2.5-pro'),
  openrouter('OpenRouter', '');

  const LlmProvider(this.label, this.defaultModel);

  final String label;

  /// Suggested model id; empty when the user must choose one.
  final String defaultModel;
}

class AppSettings {
  const AppSettings({
    this.provider = LlmProvider.anthropic,
    this.apiKey = '',
    this.model = 'claude-sonnet-5-5',
    this.maxTokens = 16000,
    this.githubToken = '',
    this.fixRounds = 2,
  });

  final LlmProvider provider;
  final String apiKey;
  final String model;
  final int maxTokens;
  final String githubToken;

  /// How many times the AI may retry after validation or build failures.
  final int fixRounds;

  bool get llmReady => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  bool get githubReady => githubToken.trim().isNotEmpty;

  AppSettings copyWith({
    LlmProvider? provider,
    String? apiKey,
    String? model,
    int? maxTokens,
    String? githubToken,
    int? fixRounds,
  }) {
    return AppSettings(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      maxTokens: maxTokens ?? this.maxTokens,
      githubToken: githubToken ?? this.githubToken,
      fixRounds: fixRounds ?? this.fixRounds,
    );
  }
}
