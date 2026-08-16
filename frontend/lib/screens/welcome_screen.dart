// مرجع التصميم: صفحة ترحيبية حوار App RTL، مساحة دافئة، بنفسجي عميق، ورسالة قصيرة تقود للدخول.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onContinue;
  const WelcomeScreen({super.key, required this.onContinue});

  TextStyle arabic(double size, {FontWeight weight = FontWeight.w400, Color color = const Color(0xFF241F38)}) {
    return GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4B3F8F);
    const inkSoft = Color(0xFF635C7A);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F3EF),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 38, 24, 28),
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(width: 46, height: 46, decoration: const BoxDecoration(color: primary, shape: BoxShape.circle), child: const Icon(Icons.forum_outlined, color: Colors.white, size: 24)),
                Text('حوار App', style: arabic(15, weight: FontWeight.w700, color: inkSoft)),
              ]),
              const SizedBox(height: 44),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
                decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: primary.withOpacity(.22), blurRadius: 28, offset: const Offset(0, 14))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 28)),
                  const SizedBox(height: 24),
                  Text('كل محادثة\nتقربك أكثر.', style: arabic(29, weight: FontWeight.w800, color: Colors.white).copyWith(height: 1.25)),
                  const SizedBox(height: 12),
                  Text('مارسي الإنجليزية بصوتك، خذي ملاحظاتك، وشوفي تقدمك بطريقة تشبهك.', style: arabic(14, color: Colors.white.withOpacity(.82)).copyWith(height: 1.65)),
                ]),
              ),
              const SizedBox(height: 26),
              Text('تجربة تعلم أهدأ وأوضح', style: arabic(16, weight: FontWeight.w700)),
              const SizedBox(height: 14),
              _Benefit(icon: Icons.mic_none_rounded, title: 'تحدثي بلا تردد', text: 'محادثات صوتية تساعدك على بناء الثقة يومًا بعد يوم.'),
              _Benefit(icon: Icons.auto_awesome_outlined, title: 'اقتراحات تناسب مستواك', text: 'محتوى عملي يركز على ما تحتاجينه الآن.'),
              _Benefit(icon: Icons.insights_outlined, title: 'شاهدي تقدمك', text: 'ملف شخصي واضح يحفظ أهدافك وتطورك.'),
              const SizedBox(height: 18),
              FilledButton(onPressed: onContinue, style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.all(17), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text('ابدئي رحلتك', style: arabic(15, weight: FontWeight.w700, color: Colors.white))),
              const SizedBox(height: 10),
              Text('يأخذ أقل من دقيقة للبدء', textAlign: TextAlign.center, style: arabic(11, color: inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Benefit({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.ibmPlexSansArabic;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFE8E3F4), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFF4B3F8F), size: 21)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: style(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF241F38))), const SizedBox(height: 2), Text(text, style: style(fontSize: 11.5, color: const Color(0xFF948DA6)))])),
    ]));
  }
}
