// مرجع التصميم: onboarding جوال RTL مطابق لهوية حوار؛ بطاقات بيضاء، بنفسجي #4B3F8F، blobs دافئة، وخطوات قصيرة واضحة.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/hiwar_api.dart';

const _bg = Color(0xFFF6F3EF);
const _ink = Color(0xFF241F38);
const _soft = Color(0xFF635C7A);
const _faint = Color(0xFF948DA6);
const _primary = Color(0xFF4B3F8F);
const _tint = Color(0xFFECEAF7);
const _line = Color(0xFFE6E1DA);

class OnboardingScreen extends StatefulWidget {
  final HiwarApi api;
  final HiwarProfile profile;
  final ValueChanged<HiwarProfile> onComplete;
  const OnboardingScreen({super.key, required this.api, required this.profile, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController pages = PageController();
  late final TextEditingController name = TextEditingController(text: widget.profile.name);
  final age = TextEditingController();
  int step = 0;
  bool busy = false;
  String? error;
  String education = 'متوسط';
  int? dailyMinutes = 20;
  final Set<String> goals = {};
  final Set<String> skills = {};

  static const goalOptions = <String>[
    'التحدث بطلاقة',
    'العمل والترقية',
    'الدراسة',
    'السفر',
    'المقابلات الوظيفية',
    'تطوير اللغة بشكل عام',
    'أخرى',
  ];
  static const skillOptions = <String>[
    'Speaking',
    'Listening',
    'Grammar',
    'Vocabulary',
    'Pronunciation',
    'Writing',
    'ما أعرف، خل الـAI يحدد لي',
  ];

  @override
  void dispose() {
    pages.dispose();
    name.dispose();
    age.dispose();
    super.dispose();
  }

  TextStyle ar(double size, {FontWeight weight = FontWeight.w400, Color color = _ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);

  void goNext() {
    if (step == 0 && name.text.trim().isEmpty) {
      setState(() => error = 'اكتب اسمك أولًا.');
      return;
    }
    if (step == 1 && goals.isEmpty) {
      setState(() => error = 'اختار هدفًا واحدًا على الأقل.');
      return;
    }
    if (step == 3 && skills.isEmpty) {
      setState(() => error = 'اختار مهارة واحدة على الأقل.');
      return;
    }
    if (step == 3) {
      save();
      return;
    }
    setState(() => error = null);
    pages.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  Future<void> save() async {
    setState(() { busy = true; error = null; });
    try {
      final updated = await widget.api.updateProfile(
        userId: widget.profile.userId,
        name: name.text.trim(),
        age: int.tryParse(age.text.trim()),
        educationLevel: education,
        learningReason: goals.join('، '),
        dailyMinutes: dailyMinutes,
        focusSkills: skills.join('، '),
      );
      if (mounted) widget.onComplete(updated);
    } catch (_) {
      if (mounted) setState(() { busy = false; error = 'تعذر حفظ معلوماتك. تأكد من تشغيل Backend.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text('خلّينا نتعرف عليك', style: ar(16, weight: FontWeight.w700))),
        body: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
            Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 5,
                    margin: EdgeInsets.only(left: i == 3 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: i <= step ? _primary : _line,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: Text('الخطوة ${step + 1} من 4', style: ar(11, color: _faint))),
          ])),
          Expanded(child: PageView(controller: pages, physics: const NeverScrollableScrollPhysics(), onPageChanged: (value) => setState(() { step = value; error = null; }), children: [
            _BasicStep(name: name, age: age, education: education, onEducation: (value) => setState(() => education = value)),
            _OptionsStep(title: 'ليش تبي تتعلم إنجليزي؟', subtitle: 'اختار كل الأشياء اللي تناسبك.', options: goalOptions, selected: goals, onToggle: (value) => setState(() { goals.contains(value) ? goals.remove(value) : goals.add(value); })),
            _MinutesStep(value: dailyMinutes, onChanged: (value) => setState(() => dailyMinutes = value)),
            _OptionsStep(title: 'وش أكثر شيء تحتاج تطوره؟', subtitle: 'اختار أكثر من مهارة، أو خلي الذكاء الاصطناعي يحدد لك.', options: skillOptions, selected: skills, onToggle: (value) => setState(() { skills.contains(value) ? skills.remove(value) : skills.add(value); })),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), child: Column(children: [
            if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, textAlign: TextAlign.center, style: ar(12, color: const Color(0xFFB23B3B)))),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : goNext, style: FilledButton.styleFrom(backgroundColor: _primary, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Text(busy ? 'جارٍ الحفظ...' : step == 3 ? 'احفظ وابدأ تحديد مستواك' : 'التالي', style: ar(14, weight: FontWeight.w700, color: Colors.white)))),
          ])),
        ]),
      ),
    );
  }
}

class _BasicStep extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController age;
  final String education;
  final ValueChanged<String> onEducation;
  const _BasicStep({required this.name, required this.age, required this.education, required this.onEducation});
  @override
  Widget build(BuildContext context) {
    final ar = (double size, {FontWeight weight = FontWeight.w400, Color color = _ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
      Text('أول خطوة، نعرفك أكثر', style: ar(20, weight: FontWeight.w800)),
      const SizedBox(height: 7),
      Text('معلومات بسيطة تساعدنا نخلي التجربة مناسبة لك.', style: ar(13, color: _faint)),
      const SizedBox(height: 24),
      _Field(controller: name, label: 'اسمك', hint: 'مثال: نورة'),
      const SizedBox(height: 12),
      _Field(controller: age, label: 'العمر', hint: 'اختياري', keyboard: TextInputType.number),
      const SizedBox(height: 18),
      Text('كيف تصف مستواك بشكل مبدئي؟', style: ar(13, weight: FontWeight.w700)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: ['مبتدئ', 'متوسط', 'متقدم'].map((item) => ChoiceChip(label: Text(item, style: ar(12)), selected: item == education, selectedColor: _tint, onSelected: (_) => onEducation(item))).toList()),
    ]);
  }
}

class _OptionsStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _OptionsStep({required this.title, required this.subtitle, required this.options, required this.selected, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final ar = (double size, {FontWeight weight = FontWeight.w400, Color color = _ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
      Text(title, style: ar(20, weight: FontWeight.w800)),
      const SizedBox(height: 7),
      Text(subtitle, style: ar(13, color: _faint)),
      const SizedBox(height: 20),
      ...options.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(onTap: () => onToggle(item), borderRadius: BorderRadius.circular(15), child: AnimatedContainer(duration: const Duration(milliseconds: 160), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14), decoration: BoxDecoration(color: selected.contains(item) ? _tint : Colors.white, border: Border.all(color: selected.contains(item) ? _primary : _line, width: selected.contains(item) ? 1.5 : 1), borderRadius: BorderRadius.circular(15)), child: Row(children: [Expanded(child: Text(item, style: ar(13, weight: FontWeight.w600))), Icon(selected.contains(item) ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected.contains(item) ? _primary : _faint)]))))),
    ]);
  }
}

class _MinutesStep extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;
  const _MinutesStep({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final ar = (double size, {FontWeight weight = FontWeight.w400, Color color = _ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);
    const options = <Map<String, dynamic>>[
      {'label': '5–10 دقائق', 'value': 10, 'icon': Icons.bolt_outlined},
      {'label': '10–20 دقيقة', 'value': 20, 'icon': Icons.timer_outlined},
      {'label': '20–30 دقيقة', 'value': 30, 'icon': Icons.local_fire_department_outlined},
      {'label': 'أكثر من 30 دقيقة', 'value': 45, 'icon': Icons.rocket_launch_outlined},
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
      Text('كم دقيقة تقدر تتعلم يوميًا؟', style: ar(20, weight: FontWeight.w800)),
      const SizedBox(height: 7),
      Text('نستخدمها عشان نبني لك خطة واقعية وما تضغط عليك.', style: ar(13, color: _faint)),
      const SizedBox(height: 22),
      ...options.map((item) {
        final selected = value == item['value'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => onChanged(item['value'] as int),
            borderRadius: BorderRadius.circular(15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: selected ? _tint : Colors.white,
                border: Border.all(
                  color: selected ? _primary : _line,
                  width: selected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(item['icon'] as IconData, color: selected ? _primary : _faint),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item['label'] as String, style: ar(13, weight: FontWeight.w600))),
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? _primary : _faint),
                ],
              ),
            ),
          ),
        );
      }),
    ]);
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboard;
  const _Field({required this.controller, required this.label, required this.hint, this.keyboard = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(controller: controller, keyboardType: keyboard, decoration: InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line))));
}
