// مرجع التصميم: onboarding حوار App RTL، خطوات شخصية داخل بطاقات بيضاء ومساحات مريحة.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/hiwar_api.dart';

class OnboardingScreen extends StatefulWidget {
  final HiwarApi api; final HiwarProfile profile; final ValueChanged<HiwarProfile> onComplete;
  const OnboardingScreen({super.key, required this.api, required this.profile, required this.onComplete});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}
class _OnboardingScreenState extends State<OnboardingScreen> {
  late final name = TextEditingController(text: widget.profile.name);
  final age = TextEditingController(); final certificates = TextEditingController(); final reason = TextEditingController();
  String level = 'مبتدئ'; bool busy = false; String? error;
  Future<void> save() async { setState(() { busy = true; error = null; }); try { final updated = await widget.api.updateProfile(userId: widget.profile.userId, name: name.text.trim(), age: int.tryParse(age.text.trim()), educationLevel: level, certificates: certificates.text.trim(), learningReason: reason.text.trim()); if (mounted) widget.onComplete(updated); } catch (_) { if (mounted) setState(() { busy = false; error = 'تعذر حفظ معلوماتك. تأكدي من تشغيل Backend.'; }); } }
  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: const Color(0xFFF6F3EF), appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text('خلّينا نتعرف عليك', style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, fontWeight: FontWeight.w700))), body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
    Text('هذه المعلومات تساعدنا نبني تجربة تناسب هدفك.', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: const Color(0xFF948DA6))), const SizedBox(height: 20),
    TextField(controller: name, decoration: InputDecoration(labelText: 'اسمك', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), const SizedBox(height: 12),
    TextField(controller: age, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'العمر', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), const SizedBox(height: 12),
    DropdownButtonFormField<String>(value: level, decoration: InputDecoration(labelText: 'مرحلتك في الإنجليزية', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: ['مبتدئ', 'متوسط', 'متقدم'].map((item) => DropdownMenuItem(value: item, child: Text(item, style: GoogleFonts.ibmPlexSansArabic()))).toList(), onChanged: (value) => setState(() => level = value ?? level)), const SizedBox(height: 12),
    TextField(controller: certificates, maxLines: 2, decoration: InputDecoration(labelText: 'شهاداتك أو دوراتك (اختياري)', hintText: 'مثال: IELTS، دورة محادثة...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), const SizedBox(height: 12),
    TextField(controller: reason, maxLines: 3, decoration: InputDecoration(labelText: 'ليش تبين تتعلمين إنجليزي؟', hintText: 'دراسة، عمل، سفر، ثقة في التحدث...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), const SizedBox(height: 20),
    FilledButton(onPressed: busy ? null : save, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4B3F8F), padding: const EdgeInsets.all(16)), child: Text(busy ? 'جارٍ الحفظ...' : 'حفظ والدخول للتطبيق', style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700))),
    if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFFB23B3B), fontSize: 12))),
  ]));
}
