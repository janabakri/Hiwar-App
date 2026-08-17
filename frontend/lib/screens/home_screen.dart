// مرجع التصميم: نسخة Flutter من speak-app-prototype(2).html؛ RTL، هاتف دافئ، بطاقات بيضاء، بنفسجي #4B3F8F، شاشات home/voice/feedback/explore/progress/profile.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/hiwar_api.dart';

const bg = Color(0xFFF6F3EF);
const paper = Colors.white;
const ink = Color(0xFF241F38);
const inkSoft = Color(0xFF635C7A);
const inkFaint = Color(0xFF948DA6);
const primary = Color(0xFF4B3F8F);
const primaryDark = Color(0xFF332A66);
const primaryTint = Color(0xFFECEAF7);
const coralTint = Color(0xFFFBE7DA);
const rust = Color(0xFFB23B3B);
const rustTint = Color(0xFFF8E7E6);
const line = Color(0xFFE6E1DA);

TextStyle ar(double size, {FontWeight weight = FontWeight.w400, Color color = ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);
TextStyle en(double size, {FontWeight weight = FontWeight.w400, Color color = ink}) => GoogleFonts.ibmPlexSans(fontSize: size, fontWeight: weight, color: color);
TextStyle mono(double size, {FontWeight weight = FontWeight.w500, Color color = ink}) => GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color);

class HomeScreen extends StatefulWidget {
  final HiwarProfile? profile;
  const HomeScreen({super.key, this.profile});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _api = HiwarApi();

  void _open(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeContent(profile: widget.profile, onVoice: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoiceScreen(api: _api)))),
      ExploreContent(),
      ProgressContent(onLevelCheck: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LevelCheckScreen()))),
      ProfileContent(api: _api, profile: widget.profile),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFEEEAE4),
        body: SafeArea(child: pages[_index]),
        bottomNavigationBar: _BottomNav(index: _index, onTap: _open),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: paper, border: Border(top: BorderSide(color: line))),
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _NavItem(icon: Icons.home_outlined, label: 'الرئيسية', active: index == 0, onTap: () => onTap(0)),
      _NavItem(icon: Icons.search, label: 'استكشف', active: index == 1, onTap: () => onTap(1)),
      _NavItem(icon: Icons.bar_chart_outlined, label: 'تقدّمي', active: index == 2, onTap: () => onTap(2)),
      _NavItem(icon: Icons.person_outline, label: 'حسابي', active: index == 3, onTap: () => onTap(3)),
    ]),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 22, color: active ? primary : inkFaint), const SizedBox(height: 3), Text(label, style: ar(11, weight: FontWeight.w600, color: active ? primary : inkFaint))])));
}

class _Card extends StatelessWidget {
  final Widget child; final EdgeInsets padding; final VoidCallback? onTap;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  @override
  Widget build(BuildContext context) { final content = Container(padding: padding, decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)), child: child); return onTap == null ? content : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: content); }
}

class _SectionTitle extends StatelessWidget { final String text; final String? tag; const _SectionTitle(this.text, {this.tag}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(text, style: ar(13, weight: FontWeight.w600, color: inkSoft)), if (tag != null) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(20)), child: Text(tag!, style: ar(11, weight: FontWeight.w600, color: primary)))])); }

class _Ring extends StatelessWidget { final String value; final String label; const _Ring({required this.value, this.label = 'التقدم'}); @override Widget build(BuildContext context) => Container(width: 64, height: 64, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [primary, primary, primaryTint, primaryTint])), child: Center(child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: paper, shape: BoxShape.circle), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('', style: TextStyle(height: 0)), Text(value, style: mono(12, weight: FontWeight.w600)), Text(label, style: ar(8, color: inkFaint))])))); }

class HomeContent extends StatelessWidget {
  final HiwarProfile? profile;
  final VoidCallback onVoice;
  const HomeContent({super.key, this.profile, required this.onVoice});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('مساء الخير، ${profile?.name ?? 'في حوار'}', style: ar(19, weight: FontWeight.w700)), Text('جاهزة لمحادثة اليوم؟', style: ar(12.5, color: inkFaint))]), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: coralTint, borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.local_fire_department, color: Color(0xFFB5451A), size: 15), const SizedBox(width: 5), Text('12 يوم', style: ar(12.5, weight: FontWeight.w600, color: const Color(0xFFB5451A)))]))]),
    const SizedBox(height: 18),
    _Card(child: Row(children: [const _Ring(value: '62%'), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('B1 — متوسط', style: ar(14.5, weight: FontWeight.w700)), Text('أقرب مستوى: B2 · Upper Intermediate', style: ar(12, color: inkFaint)), const SizedBox(height: 5), Text('XP 480 / 780', style: mono(11.5, weight: FontWeight.w600, color: primary))])])),
    const SizedBox(height: 26),
    Column(children: [GestureDetector(onTap: onVoice, child: Container(width: 132, height: 132, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: Alignment(-.35, -.5), colors: [Color(0xFF6459A8), primary])), child: const Icon(Icons.mic_none, size: 44, color: Colors.white))), const SizedBox(height: 16), Text('ابدأ محادثة صوتية', style: ar(15.5, weight: FontWeight.w700)), const SizedBox(height: 3), Text('تحدّث بحرية، الذكاء الاصطناعي يستمع ويرد عليك', style: ar(12, color: inkFaint))]),
    _SectionTitle('مقترح اليوم', tag: 'مبني على أدائك'),
    _Card(onTap: onVoice, child: Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.menu_book_outlined, color: primary)), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('التحدث في المطعم', style: ar(14, weight: FontWeight.w700)), Text('Ordering food at a restaurant', style: en(12.5, color: inkFaint))]), const Spacer(), Text('‹', style: ar(28, color: inkFaint))])),
    const _SectionTitle('أخطاء تحتاج مراجعة'),
    SizedBox(height: 78, child: ListView(scrollDirection: Axis.horizontal, children: const [_MistakeChip(wrong: 'I have went there', correct: 'I have gone there', category: 'الأزمنة — Present Perfect'), SizedBox(width: 10), _MistakeChip(wrong: 'since three years', correct: 'for three years', category: 'since / for'), SizedBox(width: 10), _MistakeChip(wrong: 'think / think', correct: '/θɪŋk/', category: 'نطق حرف th')])),
  ]);
}

class _MistakeChip extends StatelessWidget { final String wrong, correct, category; const _MistakeChip({required this.wrong, required this.correct, required this.category}); @override Widget build(BuildContext context) => Container(width: 158, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: rustTint, border: Border.all(color: const Color(0xFFEAD3CC)), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(wrong, style: en(12.5, weight: FontWeight.w600, color: rust).copyWith(decoration: TextDecoration.lineThrough)), Text(correct, style: en(12.5, weight: FontWeight.w600, color: primaryDark)), const Spacer(), Text(category, style: ar(10.5, color: inkFaint))])); }

class VoiceScreen extends StatefulWidget {
  final HiwarApi api;
  const VoiceScreen({super.key, required this.api});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  Timer? timer;
  int seconds = 0;
  bool active = false;
  bool listening = false;
  bool sending = false;
  String status = 'اضغط للبدء بالحديث';
  String transcript = '';
  final List<Map<String, String>> corrections = [];
  String reply = '';
  List<String> tips = const [];
  int exchanges = 0;

  @override
  void dispose() {
    timer?.cancel();
    speech.stop();
    tts.stop();
    super.dispose();
  }

  Future<void> toggleListening() async {
    if (sending) return;
    if (listening) {
      await speech.stop();
      if (mounted) setState(() { listening = false; status = 'جاري تحليل كلامك...'; });
      await sendTranscript();
      return;
    }

    final available = await speech.initialize(
      onStatus: (value) {
        if (!mounted) return;
        if (value == 'done' && listening) setState(() => listening = false);
      },
      onError: (_) {
        if (mounted) setState(() { listening = false; status = 'تعذر الوصول للميكروفون'; });
      },
    );
    if (!available) {
      if (mounted) setState(() => status = 'اسمحي للتطبيق باستخدام الميكروفون');
      return;
    }
    setState(() {
      active = true;
      listening = true;
      status = 'أنصت إليك...';
      transcript = '';
    });
    timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
    await speech.listen(
      localeId: 'en_US',
      listenMode: stt.ListenMode.dictation,
      onResult: (result) {
        if (!mounted) return;
        setState(() => transcript = result.recognizedWords);
        if (result.finalResult) {
          setState(() { listening = false; status = 'جاري تحليل كلامك...'; });
          sendTranscript();
        }
      },
    );
  }

  Future<void> sendTranscript() async {
    final message = transcript.trim();
    if (message.isEmpty) {
      if (mounted) setState(() => status = 'حاولي قول جملة قصيرة بالإنجليزي');
      return;
    }
    setState(() { sending = true; status = 'يفكر بالرد...'; });
    try {
      final userId = await widget.api.getStoredUserId() ?? await widget.api.getUserId();
      final result = await widget.api.sendChat(userId: userId, message: message);
      if (!mounted) return;
      setState(() {
        reply = result.reply;
        corrections
          ..clear()
          ..addAll(result.corrections);
        tips = result.tips;
        exchanges++;
        sending = false;
        active = true;
        status = 'يتحدث الآن...';
      });
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(0.45);
      if (result.reply.trim().isNotEmpty) await tts.speak(result.reply);
    } catch (_) {
      if (mounted) setState(() { sending = false; status = 'تعذر الاتصال بالخادم'; });
    }
  }

  void finishConversation() {
    timer?.cancel();
    speech.stop();
    tts.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(
          api: widget.api,
          corrections: List<Map<String, String>>.from(corrections),
          reply: reply,
          tips: tips,
          duration: seconds,
          exchanges: exchanges,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: ink), onPressed: () => Navigator.pop(context)),
        title: Text('B1 · Ordering food at a restaurant', style: ar(12, color: inkFaint)),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(children: [
            const SizedBox(height: 60),
            Text(status, style: ar(13.5, weight: FontWeight.w600, color: inkSoft)),
            const SizedBox(height: 22),
            Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-.3, -.45),
                  colors: [Color(0xFF6459A8), primary],
                ),
              ),
              child: Center(
                child: sending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : listening
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              6,
                              (i) => Container(
                                width: 5,
                                height: 28 + (i % 3) * 10,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          )
                        : const Icon(Icons.mic_none, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 22),
            if (transcript.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 26), child: Text(transcript, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: ar(12, color: inkSoft))),
            const SizedBox(height: 8),
            Text(elapsed, style: mono(13, color: inkFaint)),
          ]),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Column(children: [IconButton(onPressed: toggleListening, icon: Icon(listening ? Icons.stop_rounded : Icons.mic_none, color: listening ? rust : ink), iconSize: 26, style: IconButton.styleFrom(backgroundColor: paper, side: const BorderSide(color: line), fixedSize: const Size(64, 64))), Text(listening ? 'إيقاف' : 'اضغط وتحدث', style: ar(11.5, color: inkFaint))]),
              const SizedBox(width: 34),
              Column(children: [IconButton(onPressed: finishConversation, icon: const Icon(Icons.close), color: Colors.white, iconSize: 26, style: IconButton.styleFrom(backgroundColor: rust, fixedSize: const Size(64, 64))), Text('إنهاء', style: ar(11.5, color: inkFaint))]),
            ]),
          ),
        ],
      ),
    );
  }
}

class FeedbackScreen extends StatefulWidget {
  final HiwarApi api;
  final List<Map<String, String>> corrections;
  final String reply;
  final List<String> tips;
  final int duration;
  final int exchanges;
  const FeedbackScreen({super.key, required this.api, this.corrections = const [], this.reply = '', this.tips = const [], this.duration = 0, this.exchanges = 0});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  bool loading = true;
  String? error;
  List<HiwarError> historical = const [];

  @override
  void initState() { super.initState(); _loadHistory(); }

  Future<void> _loadHistory() async {
    try {
      final userId = await widget.api.getStoredUserId();
      if (userId != null && userId.isNotEmpty) historical = await widget.api.getErrors(userId);
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'تعذر تحميل سجل الأخطاء السابق.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.duration ~/ 60;
    final seconds = widget.duration % 60;
    final current = widget.corrections.map((item) => HiwarError(wrong: item['wrong'] ?? '', correct: item['correct'] ?? '', explanation: item['explanation'] ?? '', errorType: 'session', count: 1)).toList();
    final all = [...current, ...historical];
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, elevation: 0, title: Text('مراجعة المحادثة', style: ar(16, weight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
        const _FeedbackCelebration(),
        Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(20)), child: Text('✓ انتهت المحادثة', style: ar(12, weight: FontWeight.w700, color: primaryDark)))),
        Center(child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(all.isEmpty ? 'ممتاز، ما فيه ملاحظات هالمرة' : 'أداء جيد اليوم', style: ar(18, weight: FontWeight.w700)))),
        Center(child: Text('${minutes}د ${seconds}ث · ${widget.exchanges} تبادلات · Ordering food at a restaurant', style: ar(12.5, color: inkFaint))),
        if (widget.reply.isNotEmpty) ...[const _SectionTitle('رد المساعد'), _Card(child: Text(widget.reply, style: ar(13, color: inkSoft).copyWith(height: 1.7)))],
        if (widget.tips.isNotEmpty) ...[const _SectionTitle('نصيحة لك'), _Card(child: Text(widget.tips.join('\n'), style: ar(13, color: inkSoft).copyWith(height: 1.7)))],
        if (loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: primary))),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, textAlign: TextAlign.center, style: ar(12, color: rust))),
        if (!loading && all.isNotEmpty) ...[
          _SectionTitle('الأخطاء والملاحظات السابقة (${historical.length})'),
          ...all.asMap().entries.map((entry) => _ReviewCard(number: '${entry.key + 1}', wrong: entry.value.wrong, correct: entry.value.correct, explain: '${entry.value.explanation}${entry.value.count > 1 ? ' · تكررت ${entry.value.count} مرات' : ''}')),
        ],
        if (!loading && all.isEmpty) _Card(child: Text('استمري بالتحدث. سيظهر هنا سجل ملاحظاتك بعد أول تحليل حقيقي.', textAlign: TextAlign.center, style: ar(13, color: inkSoft).copyWith(height: 1.7))),
        const SizedBox(height: 22),
        FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.bolt), label: Text('العودة للمحادثة', style: ar(14, weight: FontWeight.w700)), style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.all(16))),
      ]),
    );
  }
}

class _ReviewCard extends StatelessWidget {final String number,wrong,correct,explain;const _ReviewCard({required this.number,required this.wrong,required this.correct,required this.explain});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:12),child:_Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[CircleAvatar(radius:12,backgroundColor:rustTint,child:Text(number,style:mono(11,color:rust))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('"$wrong"',style:en(13.5,color:rust).copyWith(decoration:TextDecoration.lineThrough)),Text('✓ $correct',style:en(13.5,weight:FontWeight.w600,color:primaryDark))]))]),const Divider(height:20,color:line),Text(explain,style:ar(12.5,color:inkSoft).copyWith(height:1.7))])));}
class _WordChip extends StatelessWidget {final String text;const _WordChip(this.text);@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:8),decoration:BoxDecoration(color:paper,border:Border.all(color:line),borderRadius:BorderRadius.circular(20)),child:Text(text,style:ar(12.5)));}

class ExploreContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
    const _SectionTitle('استكشف'),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [primaryDark, primary]), borderRadius: BorderRadius.circular(18)), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('✦ اقتراح ذكي لكِ', style: ar(11, weight: FontWeight.w700, color: Colors.white)), const SizedBox(height: 8), Text('بناءً على محادثاتك الأخيرة، ركّزي هالأسبوع على Present Perfect ونطق حرف th — قبل ما ننتقل لمهارة جديدة.', style: ar(13, color: Colors.white).copyWith(height: 1.6))])),
      const SizedBox(width: 8),
      const _SparkleArt(),
    ])),
    const SizedBox(height: 16),
    GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.05, children: const [_Skill(title: 'التحدث', english: 'Speaking', value: 70, color: primaryTint), _Skill(title: 'الاستماع', english: 'Listening', value: 55, color: Color(0xFFE7EEF7)), _Skill(title: 'القراءة', english: 'Reading', value: 48, color: Color(0xFFF7EEDB)), _Skill(title: 'الكتابة', english: 'Writing', value: 40, color: Color(0xFFF6E6EB)), _Skill(title: 'القواعد', english: 'Grammar', value: 58, color: Color(0xFFE9E7F2)), _Skill(title: 'المفردات', english: 'Vocabulary', value: 65, color: const Color(0xFFF8E7E6))],),
  ]);
}
class _Skill extends StatelessWidget {final String title,english;final int value;final Color color;const _Skill({required this.title,required this.english,required this.value,required this.color});@override Widget build(BuildContext context)=>_Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:38,height:38,decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.auto_awesome_outlined,size:19,color:primary)),const SizedBox(height:9),Text(title,style:ar(13.5,weight:FontWeight.w700)),Text(english,style:en(11,color:inkFaint)),const Spacer(),ClipRRect(borderRadius:BorderRadius.circular(5),child:LinearProgressIndicator(value:value/100,minHeight:5,backgroundColor:line,color:primary)),const SizedBox(height:5),Text('$value%',style:mono(10.5,color:inkFaint))]));}

class ProgressContent extends StatelessWidget {
  final VoidCallback? onLevelCheck;
  const ProgressContent({super.key, this.onLevelCheck});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
    const _SectionTitle('تقدّمي'),
    _Card(child: Row(children: [const _Ring(value: '480', label: 'XP'), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('B1 — متوسط', style: ar(14.5, weight: FontWeight.w700)), Text('12 يوم متتالي · 34 محادثة', style: ar(12, color: inkFaint))])])),
    const SizedBox(height: 14),
    _Card(onTap: onLevelCheck, child: Row(children: [const _LevelMeterArt(size: 58), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('حددي مستواك من جديد', style: ar(14, weight: FontWeight.w700)), Text('اختبار قصير يعطيك مسارًا أدق', style: ar(11.5, color: inkFaint))])), const Icon(Icons.chevron_left, color: inkFaint)])),
    const _SectionTitle('سجل الأخطاء المتكررة'),
    const _Card(child: ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 12, backgroundColor: rustTint, child: Text('×7', style: TextStyle(color: rust, fontSize: 11))), title: Text('Present Perfect vs Past Simple'), subtitle: Text('أكثر خطأ تكرر معك هذا الشهر'))),
    const SizedBox(height: 12),
    const _Card(child: ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 12, backgroundColor: rustTint, child: Text('×4', style: TextStyle(color: rust, fontSize: 11))), title: Text('نطق حرف th'), subtitle: Text('تحسّن ملحوظ عن الشهر الماضي'))),
  ]);
}

class ProfileContent extends StatefulWidget { final HiwarApi api; final HiwarProfile? profile; const ProfileContent({super.key,required this.api, this.profile}); @override State<ProfileContent> createState()=>_ProfileContentState(); }
class _ProfileContentState extends State<ProfileContent> { HiwarStats? stats; String? error; bool loading=true; final controller=TextEditingController(); @override void initState(){super.initState();_load();} Future<void> _load() async {setState(()=>loading=true); final id=await widget.api.getUserId(); controller.text=id; try{final result=await widget.api.getStats(id); if(mounted)setState((){stats=result;error=null;loading=false;});}catch(e){if(mounted)setState((){error=e.toString().replaceFirst('Exception: ','');loading=false;});}} Future<void> _connect() async {await widget.api.saveUserId(controller.text);_load();} @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.fromLTRB(20,12,20,28),children:[Row(children:[Container(width:58,height:58,decoration:BoxDecoration(color:primaryTint,borderRadius:BorderRadius.circular(20)),child:const Icon(Icons.person_outline,color:primary,size:28)),const SizedBox(width:12),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('حسابي',style:ar(11,color:inkFaint)),Text(stats?.userName??'معلوماتي في Hiwar',style:ar(19,weight:FontWeight.w700)),Text(controller.text,style:mono(10,color:inkFaint))])]),const SizedBox(height:14),if(widget.profile != null) _Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('معلوماتي',style:ar(13,weight:FontWeight.w700,color:inkSoft)),const SizedBox(height:10),Text('العمر: ${widget.profile!.age ?? 'غير محدد'}',style:ar(12.5)),Text('المرحلة: ${widget.profile!.educationLevel ?? 'غير محددة'}',style:ar(12.5)),Text('الشهادات: ${widget.profile!.certificates?.isNotEmpty == true ? widget.profile!.certificates : 'لا توجد'}',style:ar(12.5)),Text('الهدف: ${widget.profile!.learningReason?.isNotEmpty == true ? widget.profile!.learningReason : 'لم تتم إضافته'}',style:ar(12.5))])),const SizedBox(height:14),const _ProfileExtras(),const SizedBox(height:14),_Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('معرّف المستخدم',style:ar(12,weight:FontWeight.w700,color:inkSoft)),const SizedBox(height:8),Row(children:[Expanded(child:TextField(controller:controller,textDirection:TextDirection.ltr,style:mono(11),decoration:InputDecoration(hintText:'أدخلي user_id من Hiwar',hintStyle:ar(11,color:inkFaint),isDense:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:line))))),const SizedBox(width:8),FilledButton(onPressed:_connect,style:FilledButton.styleFrom(backgroundColor:primary),child:Text('تحديث',style:ar(12,weight:FontWeight.w700,color:Colors.white)))])])),if(loading)const Padding(padding:EdgeInsets.only(top:14),child:_Card(child:Text('جارٍ تحميل معلوماتك...'))),if(!loading&&error!=null)Padding(padding:const EdgeInsets.only(top:14),child:_Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('تعذر جلب المعلومات',style:ar(13,weight:FontWeight.w700,color:rust)),const SizedBox(height:6),Text(error!,style:ar(11,color:inkSoft)),const SizedBox(height:10),FilledButton(onPressed:_load,style:FilledButton.styleFrom(backgroundColor:primary),child:Text('إعادة المحاولة',style:ar(12,color:Colors.white))),const SizedBox(height:5),Text('API: ${widget.api.baseUrl}',style:mono(9,color:inkFaint))]))),if(!loading&&error==null&&stats!=null) ...[_Card(child:Row(children:[_Ring(value:'${stats!.levelScore}%',label:'المستوى'),const SizedBox(width:16),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(stats!.level,style:ar(14.5,weight:FontWeight.w700)),Text('تقدمك الحالي في التعلم',style:ar(12,color:inkFaint)),Text('${stats!.levelScore} نقطة مستوى',style:mono(11,color:primary))])])),const SizedBox(height:12),GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.5,children:[_AccountStat(value:'${stats!.totalSessions}',label:'محادثة'),_AccountStat(value:'${stats!.streakDays}',label:'يوم متتالي'),_AccountStat(value:'${stats!.totalErrors}',label:'خطأ مسجل'),_AccountStat(value:'${stats!.masteryRate}%',label:'نسبة الإتقان')])]]); }
class _AccountStat extends StatelessWidget {final String value,label;const _AccountStat({required this.value,required this.label});@override Widget build(BuildContext context)=>_Card(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(value,style:mono(17,weight:FontWeight.w600,color:primary)),Text(label,style:ar(11,color:inkFaint))]));}


class _FeedbackCelebration extends StatelessWidget {
  const _FeedbackCelebration();
  @override
  Widget build(BuildContext context) => SizedBox(height: 142, child: Stack(alignment: Alignment.center, children: [
    Container(width: 112, height: 112, decoration: BoxDecoration(color: const Color(0xFFF7EEDB), borderRadius: BorderRadius.circular(42))),
    Container(width: 68, height: 68, decoration: const BoxDecoration(color: primary, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 40)),
    const Positioned(top: 22, left: 52, child: Icon(Icons.star_rounded, color: Color(0xFFD9581F), size: 17)),
    const Positioned(top: 46, right: 48, child: Icon(Icons.auto_awesome, color: Color(0xFFB5842B), size: 15)),
    const Positioned(bottom: 20, right: 68, child: Icon(Icons.star_rounded, color: Color(0xFFD9581F), size: 12)),
    Positioned(bottom: 26, left: 62, child: Container(width: 7, height: 7, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(2)))),
  ]));
}

class _SparkleArt extends StatelessWidget {
  const _SparkleArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(color: Colors.white.withOpacity(.08), shape: BoxShape.circle)),
          Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withOpacity(.14), shape: BoxShape.circle)),
          const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
          Positioned(top: 2, right: 4, child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle))),
          Positioned(bottom: 8, left: 2, child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle))),
        ],
      ),
    );
  }
}

class _LevelMeterArt extends StatelessWidget {
  final double size;
  const _LevelMeterArt({this.size = 82});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: size * .16,
            left: size * .15,
            right: size * .12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: size * .16, height: size * .30, decoration: BoxDecoration(color: const Color(0xFFD9D3EE), borderRadius: BorderRadius.circular(5))),
                SizedBox(width: size * .07),
                Container(width: size * .16, height: size * .47, decoration: BoxDecoration(color: const Color(0xFF9D94C9), borderRadius: BorderRadius.circular(5))),
                SizedBox(width: size * .07),
                Container(width: size * .16, height: size * .66, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(5))),
              ],
            ),
          ),
          Positioned(bottom: size * .10, left: size * .12, right: size * .12, child: Container(height: 2, color: primaryDark.withOpacity(.35))),
          Positioned(top: 2, right: size * .18, child: Icon(Icons.star_rounded, color: const Color(0xFFD9581F), size: size * .26)),
        ],
      ),
    );
  }
}

class _ProfileExtras extends StatelessWidget {
  const _ProfileExtras();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SectionTitle('إنجازاتي'),
    Row(children: [
      Expanded(child: _Badge(icon: Icons.local_fire_department_outlined, label: '7 أيام', unlocked: true)),
      const SizedBox(width: 8),
      Expanded(child: _Badge(icon: Icons.record_voice_over_outlined, label: 'أول محادثة', unlocked: true)),
      const SizedBox(width: 8),
      Expanded(child: _Badge(icon: Icons.emoji_events_outlined, label: 'متقدم', unlocked: false)),
    ]),
  ]);
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool unlocked;
  const _Badge({required this.icon, required this.label, required this.unlocked});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5), decoration: BoxDecoration(color: unlocked ? const Color(0xFFF7EEDB) : paper, border: Border.all(color: unlocked ? const Color(0xFFEAD9C4) : line), borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(icon, size: 22, color: unlocked ? const Color(0xFFB5842B) : inkFaint), const SizedBox(height: 5), Text(label, textAlign: TextAlign.center, style: ar(9.5, weight: FontWeight.w600, color: inkSoft))]));
}

class LevelCheckScreen extends StatefulWidget {
  final HiwarApi? api;
  final String? userId;
  final VoidCallback? onComplete;
  const LevelCheckScreen({super.key, this.api, this.userId, this.onComplete});
  @override
  State<LevelCheckScreen> createState() => _LevelCheckScreenState();
}

class _LevelCheckScreenState extends State<LevelCheckScreen> {
  int section = 0;
  int question = 0;
  int score = 0;
  bool listening = false;
  final stt.SpeechToText speech = stt.SpeechToText();
  String spokenText = '';
  bool analyzing = false;
  Map<String, dynamic> speakingAnalysis = const {};

  Future<void> submitReading(String answer) async {
    score += answer.startsWith('Small') ? 1 : 0;
    if (widget.api != null && widget.userId != null) {
      try {
        await widget.api!.assessReading(userId: widget.userId!, passage: 'Learning a language takes practice. Small daily conversations can help you become more confident and understand people from different cultures.', answer: answer);
      } catch (_) {}
    }
    if (mounted) setState(() => section++);
  }

  final grammar = const [
    {'q': 'She ___ to work every day.', 'a': ['go', 'goes', 'going'], 'correct': 1},
    {'q': 'I have lived here ___ 2020.', 'a': ['for', 'since', 'during'], 'correct': 1},
    {'q': 'They ___ dinner when I called.', 'a': ['had', 'were having', 'have'], 'correct': 1},
    {'q': 'If I had time, I ___ more.', 'a': ['study', 'studied', 'would study'], 'correct': 2},
    {'q': 'This is the book ___ I told you about.', 'a': ['who', 'where', 'that'], 'correct': 2},
  ];
  final vocabulary = const [
    {'q': 'What does “accurate” mean?', 'a': ['correct', 'fast', 'difficult'], 'correct': 0},
    {'q': 'The opposite of “borrow” is…', 'a': ['lend', 'keep', 'buy'], 'correct': 0},
    {'q': 'A “deadline” is…', 'a': ['a final time', 'a conversation', 'a holiday'], 'correct': 0},
    {'q': '“Improve” means to…', 'a': ['get better', 'get smaller', 'stop'], 'correct': 0},
    {'q': 'A person who travels is a…', 'a': ['traveler', 'listener', 'writer'], 'correct': 0},
  ];

  @override
  void dispose() { speech.stop(); super.dispose(); }

  List<Map<String, Object>> get currentQuestions => section == 0 ? grammar : vocabulary;

  void answer(int index) {
    if (index == currentQuestions[question]['correct']) score++;
    if (question < currentQuestions.length - 1) { setState(() => question++); return; }
    setState(() { section++; question = 0; });
  }

  Future<void> startSpeaking() async {
    if (listening) { await speech.stop(); setState(() => listening = false); return; }
    final ready = await speech.initialize();
    if (!ready) return;
    setState(() { listening = true; spokenText = ''; });
    await speech.listen(localeId: 'en_US', listenMode: stt.ListenMode.dictation, onResult: (result) {
      if (!mounted) return;
      setState(() => spokenText = result.recognizedWords);
      if (result.finalResult) setState(() => listening = false);
    });
  }

  Future<void> finish() async {
    if (widget.api != null && widget.userId != null) {
      setState(() => analyzing = true);
      try {
        speakingAnalysis = await widget.api!.assessSpeaking(userId: widget.userId!, prompt: 'Tell me about yourself.', transcript: spokenText);
      } catch (_) {}
    }
    final remoteLevel = '${speakingAnalysis['estimated_level'] ?? ''}';
    final estimated = remoteLevel.isNotEmpty && remoteLevel != 'pending' ? remoteLevel : score >= 9 ? 'B2' : score >= 6 ? 'B1' : score >= 3 ? 'A2' : 'A1';
    final finalScore = (speakingAnalysis['overall_score'] as num?)?.toInt() ?? (score * 10).clamp(0, 100);
    if (widget.api != null && widget.userId != null) {
      try { await widget.api!.saveLevelResult(userId: widget.userId!, level: estimated, score: finalScore); } catch (_) {}
    }
    if (mounted) setState(() => analyzing = false);
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      title: Text('مستواك التقديري $estimated', style: ar(18, weight: FontWeight.w800)),
          content: Text('${speakingAnalysis['feedback'] ?? 'نتيجتك مبنية على إجاباتك وتحليل التحدث. النطق يحتاج تسجيل صوتي مخصص لتحليله بدقة.'}', style: ar(13, color: inkSoft).copyWith(height: 1.7)),
      actions: [TextButton(onPressed: () { Navigator.pop(context); widget.onComplete?.call(); if (widget.onComplete == null) Navigator.pop(context); }, child: Text('ابدئي التعلم', style: ar(13, color: primary, weight: FontWeight.w700)))],
    ));
  }

  TextStyle ar(double size, {FontWeight weight = FontWeight.w400, Color color = ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) {
    final isReading = section == 2;
    final isListening = section == 3;
    final isSpeaking = section == 4;
    final totalSections = 5;
    return Scaffold(backgroundColor: bg, appBar: AppBar(backgroundColor: bg, elevation: 0, title: Text('تحديد المستوى', style: ar(16, weight: FontWeight.w700))), body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 30), children: [
      LinearProgressIndicator(value: (section + (question / 5)) / totalSections, backgroundColor: line, color: primary, minHeight: 6, borderRadius: BorderRadius.circular(6)),
      const SizedBox(height: 24),
      Center(child: Text(isReading ? 'Reading' : isListening ? 'Listening' : isSpeaking ? 'Speaking ⭐' : section == 0 ? 'Grammar' : 'Vocabulary', style: en(18, weight: FontWeight.w800, color: primary))),
      const SizedBox(height: 14),
      if (section < 2) ...[
        Text('السؤال ${question + 1} من 5', textAlign: TextAlign.center, style: ar(12, color: inkFaint)),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            children: [
              Text(
                '${currentQuestions[question]['q']}',
                textAlign: TextAlign.center,
                style: en(18, weight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              ...List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => answer(i),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(14),
                        side: const BorderSide(color: line),
                      ),
                      child: Text(
                        '${(currentQuestions[question]['a'] as List)[i]}',
                        style: en(14, color: ink),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ] else if (isReading) ...[
        Text('اقرئي القطعة ثم أجيبي عن السؤال.', style: ar(14, weight: FontWeight.w700)), const SizedBox(height: 12), _Card(child: Text('Learning a language takes practice. Small daily conversations can help you become more confident and understand people from different cultures.', style: en(15, color: inkSoft).copyWith(height: 1.7))), const SizedBox(height: 14), _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('What helps you become more confident?', style: en(15, weight: FontWeight.w700)), const SizedBox(height: 12), ...['Small daily conversations', 'Watching no videos', 'Avoiding practice'].map((item) => ListTile(contentPadding: EdgeInsets.zero, title: Text(item, style: en(13)), onTap: () => submitReading(item)))])),
      ] else if (isListening) ...[
        Text('اسمعي الجملة ثم اختاري معناها.', style: ar(14, weight: FontWeight.w700)), const SizedBox(height: 12), _Card(child: Column(children: [IconButton(onPressed: () {}, icon: const Icon(Icons.volume_up_rounded, color: primary, size: 36)), Text('She has been working here for two years.', textAlign: TextAlign.center, style: en(15, color: inkSoft)), const SizedBox(height: 12), ...['هي تعمل هنا منذ سنتين', 'هي ستعمل غدًا', 'هي لم تعمل من قبل'].map((item) => ListTile(contentPadding: EdgeInsets.zero, title: Text(item, style: ar(13)), onTap: () { score += item.startsWith('هي تعمل') ? 1 : 0; setState(() => section++); }))])),
      ] else if (isSpeaking) ...[
        Text('تحدثي لمدة 30–60 ثانية عن نفسك.', style: ar(14, weight: FontWeight.w700)), const SizedBox(height: 12), _Card(child: Column(children: [Text('Tell me about yourself.', textAlign: TextAlign.center, style: en(22, weight: FontWeight.w700, color: primary)), const SizedBox(height: 16), IconButton(onPressed: startSpeaking, icon: Icon(listening ? Icons.stop_circle : Icons.mic_rounded, color: listening ? rust : primary, size: 58)), if (spokenText.isNotEmpty) Text(spokenText, textAlign: TextAlign.center, style: en(13, color: inkSoft).copyWith(height: 1.6)), const SizedBox(height: 8), Text('Grammar · Vocabulary · Fluency · Pronunciation · Naturalness', textAlign: TextAlign.center, style: ar(11, color: inkFaint))])),
        const SizedBox(height: 18), FilledButton(onPressed: analyzing || spokenText.trim().isEmpty ? null : finish, style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.all(16)), child: Text(analyzing ? 'جارٍ تحليل إجابتك...' : 'عرض مستواي', style: ar(14, weight: FontWeight.w700, color: Colors.white))),
      ] else ...[],
    ]));
  }
}
