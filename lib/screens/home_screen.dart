import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/factory_controller.dart';
import '../providers/settings_controller.dart';
import 'guide_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _idea = TextEditingController();
  bool _buildApk = true;

  @override
  void dispose() {
    _idea.dispose();
    super.dispose();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _start() async {
    final settings = context.read<SettingsController>().settings;
    if (!settings.llmReady) {
      _toast('أدخل مفتاح الذكاء الاصطناعي من الإعدادات أولاً.');
      return;
    }
    if (_buildApk && !settings.githubReady) {
      _toast('لبناء الـ APK أدخل رمز GitHub من الإعدادات، أو أوقف خيار البناء.');
      return;
    }
    if (_idea.text.trim().isEmpty) {
      _toast('اكتب فكرة التطبيق أولاً.');
      return;
    }
    FocusScope.of(context).unfocus();
    await context.read<FactoryController>().start(
          idea: _idea.text,
          settings: settings,
          build: _buildApk,
        );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FactoryController>();
    final settings = context.watch<SettingsController>().settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مصنع التطبيقات'),
        actions: [
          IconButton(
            tooltip: 'دليل الاستخدام',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => _open(const GuideScreen()),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _open(const SettingsScreen()),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!settings.llmReady)
              _SetupBanner(
                onSettings: () => _open(const SettingsScreen()),
                onGuide: () => _open(const GuideScreen()),
              ),
            TextField(
              controller: _idea,
              minLines: 5,
              maxLines: 10,
              enabled: !controller.running,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'فكرة التطبيق',
                hintText:
                    'مثال: تطبيق لتتبع المصروفات اليومية بالمبلغ والفئة مع '
                    'إجمالي الشهر وحفظ محلي وواجهة عربية.',
                alignLabelWithHint: true,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ابنِ ملف APK عبر GitHub'),
              subtitle: const Text(
                'يحتاج رمز GitHub. بدونه تحصل على ملف ZIP فقط.',
              ),
              value: _buildApk,
              onChanged:
                  controller.running ? null : (v) => setState(() => _buildApk = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: controller.running ? null : _start,
              icon: controller.running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(controller.running ? 'جاري العمل...' : 'ابدأ التوليد'),
            ),
            if (controller.logs.isNotEmpty) ...[
              const SizedBox(height: 16),
              _LogCard(lines: controller.logs),
            ],
            if (controller.errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(
                message: controller.errorMessage!,
                details: controller.errorDetails,
              ),
            ],
            if (controller.result != null) ...[
              const SizedBox(height: 16),
              _ResultCard(controller: controller, onCopied: _toast),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.onSettings, required this.onGuide});

  final VoidCallback onSettings;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ابدأ من هنا',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'أدخل مفتاح الذكاء الاصطناعي في الإعدادات قبل أول استخدام. '
              'يشرح الدليل كل خطوة بالتفصيل.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: onSettings,
                  child: const Text('فتح الإعدادات'),
                ),
                OutlinedButton(
                  onPressed: onGuide,
                  child: const Text('دليل الاستخدام'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سجل العمل', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $line'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.details});

  final String message;
  final String details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (details.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'التفاصيل التقنية',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      details,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.controller, required this.onCopied});

  final FactoryController controller;
  final void Function(String message) onCopied;

  @override
  Widget build(BuildContext context) {
    final result = controller.result!;
    final repoUrl = result.repoUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'النتيجة: ${result.projectName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('${result.files.length} ملفاً في المشروع.'),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'ملاحظات لم تُحل تلقائياً (${result.warnings.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final warning in result.warnings)
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('- $warning', style: const TextStyle(fontSize: 12)),
                ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: controller.shareZip,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('مشاركة ملف ZIP'),
                ),
                if (result.apkBytes != null)
                  FilledButton.icon(
                    onPressed: controller.shareApk,
                    icon: const Icon(Icons.android),
                    label: const Text('مشاركة ملف APK'),
                  ),
              ],
            ),
            if (repoUrl != null) ...[
              const SizedBox(height: 12),
              const Text('المستودع الخاص على GitHub:'),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    Expanded(child: SelectableText(repoUrl)),
                    IconButton(
                      tooltip: 'نسخ الرابط',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: repoUrl));
                        onCopied('تم نسخ الرابط.');
                      },
                    ),
                  ],
                ),
              ),
            ],
            if (result.apkBytes != null) ...[
              const SizedBox(height: 8),
              const Text(
                'لتثبيت الـ APK: شاركه واحفظه في الملفات، ثم افتحه من تطبيق '
                'الملفات واسمح بالتثبيت عند الطلب.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
