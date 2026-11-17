import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../providers/settings_controller.dart';
import 'guide_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late LlmProvider _provider;
  late int _fixRounds;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  late final TextEditingController _githubToken;
  late final TextEditingController _maxTokens;
  bool _hideApiKey = true;
  bool _hideGithubToken = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>().settings;
    _provider = settings.provider;
    _fixRounds = settings.fixRounds;
    _apiKey = TextEditingController(text: settings.apiKey);
    _model = TextEditingController(text: settings.model);
    _githubToken = TextEditingController(text: settings.githubToken);
    _maxTokens = TextEditingController(text: '${settings.maxTokens}');
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _model.dispose();
    _githubToken.dispose();
    _maxTokens.dispose();
    super.dispose();
  }

  void _onProviderChanged(LlmProvider? value) {
    if (value == null) return;
    setState(() {
      final previous = _provider;
      _provider = value;
      final current = _model.text.trim();
      if (current.isEmpty || current == previous.defaultModel) {
        _model.text = value.defaultModel;
      }
    });
  }

  Future<void> _save() async {
    final maxTokens = int.tryParse(_maxTokens.text.trim());
    if (maxTokens == null || maxTokens < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الحد الأقصى للرموز يجب أن يكون 1000 أو أكثر.')),
      );
      return;
    }
    final controller = context.read<SettingsController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await controller.update(
      AppSettings(
        provider: _provider,
        apiKey: _apiKey.text.trim(),
        model: _model.text.trim(),
        maxTokens: maxTokens,
        githubToken: _githubToken.text.trim(),
        fixRounds: _fixRounds,
      ),
    );
    messenger.showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات.')));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        actions: [
          IconButton(
            tooltip: 'دليل الاستخدام',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GuideScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              icon: Icons.psychology_outlined,
              title: 'الذكاء الاصطناعي',
              children: [
                DropdownButtonFormField<LlmProvider>(
                  value: _provider,
                  decoration: const InputDecoration(labelText: 'المزوّد'),
                  items: [
                    for (final provider in LlmProvider.values)
                      DropdownMenuItem(
                        value: provider,
                        child: Text(provider.label),
                      ),
                  ],
                  onChanged: _onProviderChanged,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKey,
                  obscureText: _hideApiKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'مفتاح API',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hideApiKey ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _hideApiKey = !_hideApiKey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _model,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'اسم النموذج',
                    helperText: _provider == LlmProvider.openrouter
                        ? 'مطلوب: انسخ معرّف النموذج من openrouter.ai/models'
                        : 'يمكنك تغييره إلى أي نموذج متاح لحسابك.',
                  ),
                ),
              ],
            ),
            _Section(
              icon: Icons.cloud_outlined,
              title: 'GitHub (لبناء ملف APK)',
              children: [
                TextField(
                  controller: _githubToken,
                  obscureText: _hideGithubToken,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'رمز GitHub (Personal access token)',
                    helperText:
                        'رمز Classic بصلاحيتي repo و workflow. التفاصيل في الدليل.',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hideGithubToken
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _hideGithubToken = !_hideGithubToken,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _Section(
              icon: Icons.tune,
              title: 'إعدادات متقدمة',
              children: [
                TextField(
                  controller: _maxTokens,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الحد الأقصى لرموز الرد',
                    helperText:
                        'زِده إذا انقطع الكود في المنتصف. الافتراضي 16000.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _fixRounds,
                  decoration: const InputDecoration(
                    labelText: 'محاولات الإصلاح التلقائي',
                    helperText:
                        'كم مرة يُطلب من الذكاء الاصطناعي إصلاح الأخطاء.',
                  ),
                  items: [
                    for (var i = 0; i <= 4; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _fixRounds = value);
                  },
                ),
              ],
            ),
            _Section(
              icon: Icons.lock_outline,
              title: 'الخصوصية',
              children: const [
                Text(
                  'تُحفظ المفاتيح داخل مساحة التطبيق الخاصة على هاتفك، ولا '
                  'تُرسل إلا إلى مزوّد الذكاء الاصطناعي وإلى GitHub. '
                  'المستودعات التي ينشئها التطبيق خاصة.',
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ الإعدادات'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
