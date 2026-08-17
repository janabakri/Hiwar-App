// مرجع التصميم: onboarding هاتف RTL مطابق لـ speak-app-prototype(8).html؛ خلفية دافئة، blobs هندسية، ثلاث شرائح، نقاط تقدم وزر التالي.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFFF6F3EF);
const _paper = Color(0xFFFFFFFF);
const _ink = Color(0xFF241F38);
const _inkSoft = Color(0xFF635C7A);
const _inkFaint = Color(0xFF948DA6);
const _primary = Color(0xFF4B3F8F);
const _primaryTint = Color(0xFFECEAF7);
const _coral = Color(0xFFD9581F);
const _coralTint = Color(0xFFFBE7DA);
const _amber = Color(0xFFB5842B);
const _amberTint = Color(0xFFF7EEDB);

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const WelcomeScreen({super.key, required this.onContinue});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final controller = PageController();
  int index = 0;

  final slides = const [
    _WelcomeSlide(title: 'تحدّث بحرية بالإنجليزي', text: 'محادثة صوتية طبيعية مع ذكاء اصطناعي يستمع لك ويرد عليك، مو تمارين جامدة.', type: _ArtType.voice),
    _WelcomeSlide(title: 'تصحيح فوري وواضح', text: 'بعد كل محادثة تشوف أخطاءك، التصحيح، وسبب الخطأ بأسلوب مبسّط بدون تعقيد.', type: _ArtType.feedback),
    _WelcomeSlide(title: 'الذكاء الاصطناعي يوجّهك', text: 'يقترح عليك وش تحتاج تتعلمه بناءً على مستواك وأخطائك، بدون ما تحس إنك مجبور تدرس كل شي لحاله.', type: _ArtType.path),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void next() {
    if (index == slides.length - 1) {
      widget.onContinue();
      return;
    }
    controller.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: widget.onContinue, child: Text('تخطي', style: _ar(12.5, color: _inkFaint, weight: FontWeight.w600)))),
                Expanded(child: PageView.builder(controller: controller, itemCount: slides.length, onPageChanged: (value) => setState(() => index = value), itemBuilder: (_, i) => slides[i])),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(slides.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 3), width: i == index ? 18 : 6, height: 6, decoration: BoxDecoration(color: i == index ? _primary : const Color(0xFFE6E1DA), borderRadius: BorderRadius.circular(5))))),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: next, style: FilledButton.styleFrom(backgroundColor: _primary, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(index == slides.length - 1 ? 'ابدئ رحلتك' : 'التالي', style: _ar(14.5, color: Colors.white, weight: FontWeight.w700)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ArtType { voice, feedback, path }

class _WelcomeSlide extends StatelessWidget {
  final String title;
  final String text;
  final _ArtType type;
  const _WelcomeSlide({required this.title, required this.text, required this.type});

  @override
  Widget build(BuildContext context) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    _WelcomeArt(type: type),
    const SizedBox(height: 14),
    Text(title, textAlign: TextAlign.center, style: _ar(18, weight: FontWeight.w800)),
    const SizedBox(height: 8),
    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280), child: Text(text, textAlign: TextAlign.center, style: _ar(13, color: _inkSoft).copyWith(height: 1.7))),
  ]);
}

class _WelcomeArt extends StatelessWidget {
  final _ArtType type;
  const _WelcomeArt({required this.type});

  @override
  Widget build(BuildContext context) {
    final background = type == _ArtType.voice ? _primaryTint : type == _ArtType.feedback ? const Color(0xFFF6E6EB) : const Color(0xFFE9E7F2);
    return SizedBox(width: 240, height: 200, child: Stack(alignment: Alignment.center, children: [
      Container(width: 190, height: 168, decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(78))),
      if (type == _ArtType.voice) ...[
        Container(width: 92, height: 92, decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle), child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 42)),
        const Positioned(right: 24, top: 30, child: Icon(Icons.chat_bubble_outline_rounded, color: _coral, size: 42)),
        const Positioned(right: 66, top: 15, child: Icon(Icons.circle, color: _coral, size: 8)),
        const Positioned(right: 46, top: 8, child: Icon(Icons.circle, color: _amber, size: 5)),
        Positioned(left: 34, bottom: 32, child: Row(children: [Container(width: 42, height: 3, color: _coral.withOpacity(.55)), const SizedBox(width: 5), Container(width: 4, height: 4, decoration: const BoxDecoration(color: _coral, shape: BoxShape.circle))])),
      ] else if (type == _ArtType.feedback) ...[
        Container(width: 126, height: 98, decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEFDBE2), width: 1.4)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 76, height: 8, decoration: BoxDecoration(color: const Color(0xFFF8E7E6), borderRadius: BorderRadius.circular(4))), const SizedBox(height: 10), Container(width: 88, height: 8, decoration: BoxDecoration(color: _primaryTint, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 10), Container(width: 54, height: 8, decoration: BoxDecoration(color: _primaryTint, borderRadius: BorderRadius.circular(4)))])),
        const Positioned(right: 28, top: 25, child: CircleAvatar(radius: 22, backgroundColor: _primary, child: Icon(Icons.check_rounded, color: Colors.white, size: 28))),
        const Positioned(left: 28, bottom: 20, child: Icon(Icons.edit_outlined, color: _amber, size: 38)),
      ] else ...[
        Positioned(bottom: 28, left: 44, right: 44, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 24, height: 42, decoration: BoxDecoration(color: const Color(0xFFB9B4D6), borderRadius: BorderRadius.circular(6))), const SizedBox(width: 12), Container(width: 24, height: 64, decoration: BoxDecoration(color: const Color(0xFF8C82BE), borderRadius: BorderRadius.circular(6))), const SizedBox(width: 12), Container(width: 24, height: 88, decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(6)))])),
        const Positioned(right: 46, top: 25, child: Icon(Icons.star_rounded, color: _amber, size: 30)),
        const Positioned(left: 34, top: 44, child: Icon(Icons.circle, color: _coral, size: 7)),
      ],
    ]));
  }
}

TextStyle _ar(double size, {FontWeight weight = FontWeight.w400, Color color = _ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);
