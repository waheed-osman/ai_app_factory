import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دليل الاستخدام')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _GuideSection(
              icon: Icons.lightbulb_outline,
              title: 'كيف يعمل المصنع؟',
              initiallyExpanded: true,
              paragraphs: [
                'تكتب فكرة التطبيق، فيكتب الذكاء الاصطناعي كل ملفات مشروع '
                    'Flutter كاملة.',
                'يفحص التطبيق الكود تلقائياً (الملفات الأساسية، الاستيرادات، '
                    'المكتبات) ويطلب من الذكاء الاصطناعي إصلاح أي خلل.',
                'ثم يضغط المشروع في ملف ZIP. وإن فعّلت خيار البناء يرفعه إلى '
                    'مستودع GitHub خاص، ويبني ملف APK هناك، وينزّله إلى هاتفك.',
              ],
            ),
            _GuideSection(
              icon: Icons.flag_outlined,
              title: 'البدء السريع',
              paragraphs: [
                '١. افتح الإعدادات وأدخل مفتاح الذكاء الاصطناعي.',
                '٢. إذا أردت ملف APK، أدخل أيضاً رمز GitHub.',
                '٣. اكتب فكرة التطبيق في الشاشة الرئيسية واضغط "ابدأ التوليد".',
                '٤. انتظر اكتمال السجل، ثم شارك ملف ZIP أو APK من بطاقة النتيجة.',
              ],
            ),
            _GuideSection(
              icon: Icons.vpn_key_outlined,
              title: 'الحصول على مفتاح الذكاء الاصطناعي',
              paragraphs: [
                'Anthropic (Claude): أنشئ حساباً وأنشئ مفتاح API من '
                    'console.anthropic.com.',
                'Google Gemini: أنشئ مفتاحاً من aistudio.google.com/apikey. '
                    'قد تتوفر حصة مجانية، وشروطها تتغير فراجعها.',
                'OpenRouter: أنشئ مفتاحاً من openrouter.ai/keys، ثم انسخ '
                    'معرّف النموذج من openrouter.ai/models والصقه في خانة '
                    'اسم النموذج.',
                'المفتاح سرّي، لا تشاركه مع أحد. والاستخدام يُحاسَب على '
                    'حسابك لدى المزوّد، وكل توليد أو إصلاح يستهلك رصيداً.',
              ],
            ),
            _GuideSection(
              icon: Icons.cloud_outlined,
              title: 'الحصول على رمز GitHub',
              paragraphs: [
                'ضروري فقط لبناء ملف APK. بدونه تحصل على ZIP.',
                '١. ادخل إلى github.com/settings/tokens.',
                '٢. اختر Generate new token ثم (classic).',
                '٣. فعّل الصلاحيتين: repo و workflow. الأولى لإنشاء '
                    'المستودع ورفع الملفات، والثانية لرفع ملف البناء.',
                '٤. حدّد مدة صلاحية مناسبة، انسخ الرمز والصقه في الإعدادات.',
                'لا تستخدم الرمز الدقيق (fine-grained)، فهو لا يستطيع إنشاء '
                    'مستودعات جديدة لحسابك الشخصي.',
              ],
            ),
            _GuideSection(
              icon: Icons.edit_note,
              title: 'كيف تكتب فكرة جيدة؟',
              paragraphs: [
                'كلما كانت الفكرة محددة كانت النتيجة أدق. اذكر: الشاشات، '
                    'البيانات التي تُخزَّن، لغة الواجهة، والألوان إن أردت.',
                'مثال: تطبيق لتتبع المصروفات اليومية. شاشة لإضافة مصروف '
                    'بالمبلغ والفئة والتاريخ، وقائمة بالمصروفات، وإجمالي '
                    'الشهر، مع حفظ محلي وواجهة عربية.',
                'ابدأ بفكرة بسيطة وتأكد أنها تعمل، ثم أضف الميزات تدريجياً.',
              ],
            ),
            _GuideSection(
              icon: Icons.download_outlined,
              title: 'الحصول على النتائج وتثبيت الـ APK',
              paragraphs: [
                'ملف ZIP: اضغط مشاركة ثم احفظه في الملفات أو Drive. يمكنك '
                    'فتحه على الكمبيوتر أو رفعه إلى GitHub يدوياً.',
                'ملف APK: اضغط مشاركة واحفظه في الملفات، ثم افتحه من تطبيق '
                    'الملفات. اسمح بالتثبيت من هذا المصدر عندما يطلب الهاتف.',
                'قد يعرض Play Protect تحذيراً لأن التطبيق غير منشور على '
                    'المتجر. هذا متوقع في التطبيقات التي تبنيها بنفسك.',
              ],
            ),
            _GuideSection(
              icon: Icons.build_circle_outlined,
              title: 'حل المشاكل الشائعة',
              paragraphs: [
                'خطأ 401 أو 403 من المزوّد: المفتاح خاطئ أو الرصيد منتهٍ.',
                'الكود ينقطع أو يظهر "ملف مقطوع": ارفع "الحد الأقصى لرموز '
                    'الرد" في الإعدادات المتقدمة.',
                'فشل البناء بعد المحاولات: افتح "التفاصيل التقنية" لقراءة '
                    'سجل البناء، أو ارفع عدد محاولات الإصلاح، أو بسّط الفكرة.',
                'خطأ من GitHub: تأكد أن الرمز غير منتهٍ ويحمل صلاحيتي repo '
                    'و workflow.',
                'البناء يستغرق عدة دقائق، ويمكنك ترك التطبيق مفتوحاً '
                    'أثناء الانتظار.',
              ],
            ),
            _GuideSection(
              icon: Icons.shield_outlined,
              title: 'الأمان والتكلفة',
              paragraphs: [
                'تُحفظ المفاتيح داخل مساحة التطبيق الخاصة ولا تُرسل إلا إلى '
                    'المزوّد وGitHub.',
                'المستودعات التي ينشئها التطبيق خاصة، ويمكنك حذفها من '
                    'إعدادات المستودع على GitHub عند الانتهاء.',
                'الكود الذي يولّده الذكاء الاصطناعي يحتاج مراجعة واختباراً '
                    'قبل نشره للناس.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.icon,
    required this.title,
    required this.paragraphs,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final List<String> paragraphs;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon),
        title: Text(title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paragraph in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText(
                paragraph,
                style: const TextStyle(height: 1.6),
              ),
            ),
        ],
      ),
    );
  }
}
