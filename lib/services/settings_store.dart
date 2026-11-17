import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Persists settings in the app's private storage.
class SettingsStore {
  static const String _provider = 'provider';
  static const String _apiKey = 'apiKey';
  static const String _model = 'model';
  static const String _maxTokens = 'maxTokens';
  static const String _githubToken = 'githubToken';
  static const String _fixRounds = 'fixRounds';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString(_provider);
    final provider = LlmProvider.values.firstWhere(
      (candidate) => candidate.name == providerName,
      orElse: () => LlmProvider.anthropic,
    );
    return AppSettings(
      provider: provider,
      apiKey: prefs.getString(_apiKey) ?? '',
      model: prefs.getString(_model) ?? provider.defaultModel,
      maxTokens: prefs.getInt(_maxTokens) ?? 16000,
      githubToken: prefs.getString(_githubToken) ?? '',
      fixRounds: prefs.getInt(_fixRounds) ?? 2,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_provider, settings.provider.name);
    await prefs.setString(_apiKey, settings.apiKey);
    await prefs.setString(_model, settings.model);
    await prefs.setInt(_maxTokens, settings.maxTokens);
    await prefs.setString(_githubToken, settings.githubToken);
    await prefs.setInt(_fixRounds, settings.fixRounds);
  }
}
