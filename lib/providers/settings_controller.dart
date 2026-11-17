import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/settings_store.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({SettingsStore? store}) : _store = store ?? SettingsStore();

  final SettingsStore _store;
  AppSettings _settings = const AppSettings();
  bool _loaded = false;

  AppSettings get settings => _settings;

  bool get loaded => _loaded;

  Future<void> load() async {
    _settings = await _store.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AppSettings value) async {
    _settings = value;
    notifyListeners();
    await _store.save(value);
  }
}
