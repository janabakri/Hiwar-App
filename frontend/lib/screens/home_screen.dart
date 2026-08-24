// مرجع التصميم: نسخة Flutter من speak-app-prototype(2).html؛ RTL، هاتف دافئ، بطاقات بيضاء، بنفسجي #4B3F8F، شاشات home/voice/feedback/explore/progress/profile.
import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
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

const _conversationTopics = <Map<String, String>>[
  {'level': 'A1–A2', 'title': 'Talking about your daily routine'},
  {'level': 'A2–B1', 'title': 'Planning a weekend trip'},
  {'level': 'B1', 'title': 'Ordering food at a restaurant'},
  {'level': 'B1–B2', 'title': 'Discussing a favorite movie'},
  {'level': 'B2', 'title': 'Sharing a work or study goal'},
  {'level': 'A2–B1', 'title': 'Describing your hometown'},
];

TextStyle ar(double size, {FontWeight weight = FontWeight.w400, Color color = ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);
TextStyle en(double size, {FontWeight weight = FontWeight.w400, Color color = ink}) => GoogleFonts.ibmPlexSans(fontSize: size, fontWeight: weight, color: color);
TextStyle mono(double size, {FontWeight weight = FontWeight.w500, Color color = ink}) => GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color);

class HomeScreen extends StatefulWidget {
  final HiwarProfile? profile;
  final Future<void> Function()? onSignOut;
  const HomeScreen({super.key, this.profile, this.onSignOut});
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
      HomeContent(
        api: _api,
        profile: widget.profile,
        onVoice: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoiceScreen(api: _api))),
        onLevelCheck: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LevelCheckScreen(api: _api, userId: widget.profile?.userId, focusSkills: widget.profile?.focusSkills, onComplete: () { _open(0); Navigator.of(context).pop(); }))),
      ),
      ExploreContent(),
      ProgressContent(profile: widget.profile, onLevelCheck: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LevelCheckScreen(api: _api, userId: widget.profile?.userId, focusSkills: widget.profile?.focusSkills, onComplete: () { _open(0); Navigator.of(context).pop(); })))),
      ProfileContent(api: _api, profile: widget.profile, onSignOut: widget.onSignOut),
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
      _NavItem(icon: Icons.bar_chart_outlined, label: 'تقدّم', active: index == 2, onTap: () => onTap(2)),
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

class HomeContent extends StatefulWidget {
  final HiwarApi api;
  final HiwarProfile? profile;
  final VoidCallback onVoice;
  final VoidCallback? onLevelCheck;
  const HomeContent({super.key, required this.api, this.profile, required this.onVoice, this.onLevelCheck});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<HiwarError> errors = const [];
  HiwarStats? stats;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    final userId = widget.profile?.userId;
    if (userId == null || userId.trim().isEmpty) return;
    try {
      stats = await widget.api.getStats(userId);
    } catch (_) {}
    try {
      errors = await widget.api.getErrors(userId);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  bool get hasTraining => (stats?.totalSessions ?? 0) > 0 || errors.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final rawLevel = profile?.level.trim().toLowerCase() ?? 'pending';
    final score = profile?.levelScore ?? stats?.levelScore ?? 0;
    final hasLevelResult = score > 0 && rawLevel.isNotEmpty && rawLevel != 'pending';
    final hasManualLevel = rawLevel.isNotEmpty && rawLevel != 'pending' && rawLevel != 'intermediate' && !hasLevelResult;
    final hasKnownLevel = hasLevelResult || hasManualLevel;
    final needsLevelCheck = !hasKnownLevel && (profile?.focusSkills ?? '').contains('ما أعرف');
    final displayLevel = hasKnownLevel ? profile!.level : 'لم يحدد بعد';
    final name = profile?.name.trim().isNotEmpty == true ? profile!.name : 'في حوار';
    final activityTitle = errors.isNotEmpty ? 'راجع ملاحظاتك الأخيرة' : 'ابدأ محادثة جديدة';
    final activitySubtitle = errors.isNotEmpty ? 'تدريب مبني على كلامك الحقيقي' : 'سجّل أول جلسة ليظهر تقدمك هنا';

    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مساء الخير، $name', style: ar(19, weight: FontWeight.w700)),
          Text(hasTraining ? 'جاهز لمحادثة اليوم؟' : 'خلّنا نبدأ خطوتك الأولى', style: ar(12.5, color: inkFaint)),
        ]),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: coralTint, borderRadius: BorderRadius.circular(20)), child: Row(children: [
          const Icon(Icons.calendar_today_outlined, color: Color(0xFFB5451A), size: 14),
          const SizedBox(width: 5),
          Text(profile == null || profile.daysSinceJoined == 0 ? 'عضو جديد' : 'منذ ${profile.daysSinceJoined} يوم', style: ar(12.5, weight: FontWeight.w600, color: const Color(0xFFB5451A))),
        ])),
      ]),
      const SizedBox(height: 18),
      _Card(child: Row(children: [
                  _Ring(value: hasLevelResult ? '$score%' : '—'),

        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(displayLevel, style: ar(14.5, weight: FontWeight.w700)),
          Text(hasLevelResult ? 'نتيجتك من اختبار تحديد المستوى' : hasManualLevel ? 'المستوى الذي اخترته' : 'لم نحدد مستواك بعد', style: ar(12, color: inkFaint)),
          const SizedBox(height: 5),
          Text(hasLevelResult ? '$score نقطة مستوى' : hasManualLevel ? 'يمكنك تغييره من اختبار المستوى' : 'نتيجتك تظهر بعد الاختبار', style: mono(11.5, weight: FontWeight.w600, color: primary)),
        ])),
      ])),
      if (needsLevelCheck) ...[
        const _SectionTitle('خطوتك الأولى'),
        _Card(onTap: widget.onLevelCheck, child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.insights_outlined, color: primary)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('خلّنا نحدد مستواك', style: ar(14, weight: FontWeight.w700)),
            Text('اختبار قصير يختار لك مسارًا مناسبًا', style: ar(11.5, color: inkFaint)),
          ])),
          const Icon(Icons.chevron_left_rounded, color: inkFaint),
        ])),
      ],
      const SizedBox(height: 26),
      Column(children: [
        GestureDetector(onTap: widget.onVoice, child: Container(width: 132, height: 132, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: Alignment(-.35, -.5), colors: [Color(0xFF6459A8), primary])), child: const Icon(Icons.mic_none, size: 44, color: Colors.white))),
        const SizedBox(height: 16),
        Text(hasTraining ? 'كمل محادثتك الصوتية' : 'ابدأ أول محادثة صوتية', style: ar(15.5, weight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text('تحدّث بحرية، والمدرب يستمع ويرد عليك', style: ar(12, color: inkFaint)),
      ]),
      if (hasTraining) ...[
        _SectionTitle('تدريبك التالي', tag: errors.isNotEmpty ? 'من سجلّك' : 'بعد أول جلسة'),
        _Card(onTap: widget.onVoice, child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.record_voice_over_outlined, color: primary)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(activityTitle, style: ar(14, weight: FontWeight.w700)), Text(activitySubtitle, style: ar(12.5, color: inkFaint))])),
          const Icon(Icons.chevron_left_rounded, color: inkFaint),
        ])),
      ],
      if (errors.isNotEmpty) ...[
        const _SectionTitle('ملاحظاتك الأخيرة'),
        SizedBox(height: 92, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final error in errors.take(5)) ...[
            _MistakeChip(wrong: error.wrong, correct: error.correct, category: error.errorType),
            const SizedBox(width: 10),
          ],
        ])),
      ] else ...[
        const _SectionTitle('ملاحظاتك'),
        _Card(child: Column(children: [
          const Icon(Icons.auto_awesome_outlined, color: primary, size: 25),
          const SizedBox(height: 8),
          Text('ستظهر ملاحظاتك هنا بعد أول تدريب', textAlign: TextAlign.center, style: ar(13, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('لا توجد أخطاء مسجلة بعد، وهذا طبيعي في البداية.', textAlign: TextAlign.center, style: ar(11.5, color: inkFaint)),
        ])),
      ],
    ]);
  }
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
  bool showTranscript = false;
  final List<Map<String, String>> corrections = [];
  String reply = '';
  List<String> tips = const [];
  String? analysisError;
  bool analysisCompleted = false;
  int exchanges = 0;
  int? conversationId;
  bool submittedCurrent = false;
  bool openingPlayed = false;
  late final Map<String, String> sessionTopic = _conversationTopics[Random().nextInt(_conversationTopics.length)];

  @override
  void initState() {
    super.initState();
    tts.setErrorHandler((message) {
      if (!mounted) return;
      setState(() => status = 'تعذر تشغيل صوت المدرب من المتصفح. اضغط أيقونة الصوت أو تحقق من مستوى الصوت.');
    });
    _speakOpening();
  }

  Future<void> _speakOpening() async {
    if (openingPlayed) return;
    openingPlayed = true;
    final opening = switch (sessionTopic['title']) {
      'Daily life' => 'Hi! Let\'s talk about your day. What was the best part of it?',
      'Travel' => 'Hi! Let\'s talk about travel. Where would you love to go next?',
      'Work & goals' => 'Hi! Let\'s talk about your goals. What are you working toward right now?',
      'Food & culture' => 'Hi! Let\'s talk about food. What is a dish you really enjoy?',
      'Technology' => 'Hi! Let\'s talk about technology. What app do you use every day?',
      _ => 'Hi! I\'m ready to practice English with you. Tell me something about your day.',
    };
    if (mounted) setState(() => status = 'المدرب يبدأ المحادثة...');
    try {
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      await tts.awaitSpeakCompletion(true);
      if (!mounted) return;
      await tts.speak(opening);
      if (mounted && !listening && !sending) setState(() => status = 'اضغط للبدء بالحديث');
    } catch (_) {
      openingPlayed = false;
      if (mounted) setState(() => status = 'اضغط للبدء بالحديث؛ سيظهر رد المدرب بعد كلامك.');
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    speech.stop();
    tts.stop();
    super.dispose();
  }

  Future<void> toggleListening() async {
    if (sending) return;
    await tts.stop();
    if (listening) {
      await speech.stop();
      if (mounted) setState(() { listening = false; status = 'جاري تحليل كلامك...'; });
      await sendTranscript();
      return;
    }

    final available = await speech.initialize(
      debugLogging: false,
      onStatus: (value) {
        if (!mounted) return;
        final ended = value == 'done' || value == 'notListening';
        final shouldSubmit = ended && !sending && !submittedCurrent && transcript.trim().isNotEmpty;
        setState(() {
          if (ended) listening = false;
          if (shouldSubmit) status = 'جاري تحليل كلامك...';
        });
        if (shouldSubmit) unawaited(sendTranscript());
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          listening = false;
          submittedCurrent = false;
          status = 'تعذر تشغيل المايك: ${error.errorMsg}';
        });
      },
    );
    if (!available) {
      if (mounted) setState(() => status = 'اسمح للمتصفح باستخدام الميكروفون من رمز القفل بجانب localhost ثم حاول مرة أخرى.');
      return;
    }
    setState(() {
      active = true;
      listening = true;
      submittedCurrent = false;
      showTranscript = false;
      status = 'أستمع إليك...';
      transcript = '';
    });
    timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
    try {
      await speech.listen(
        localeId: 'en_US',
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        onResult: (result) {
          if (!mounted) return;
          setState(() => transcript = result.recognizedWords);
          if (result.finalResult) {
            setState(() { listening = false; status = 'جاري تحليل كلامك...'; });
            unawaited(sendTranscript());
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          listening = false;
          submittedCurrent = false;
          status = 'تعذر بدء الاستماع. اسمح بالميكروفون من إعدادات Chrome ثم أعد المحاولة.';
        });
      }
    }
  }

  Future<void> sendTranscript() async {
    if (sending || submittedCurrent) return;
    final message = transcript.trim();
    if (message.isEmpty) {
      if (mounted) setState(() => status = 'حاول قول جملة قصيرة بالإنجليزي');
      return;
    }
    setState(() { sending = true; submittedCurrent = true; status = 'يفكر بالرد...'; });
    try {
      final token = await widget.api.getAccessToken();
      if (token == null || token.isEmpty) throw StateError('AUTH_MISSING');
      final userId = await widget.api.getStoredUserId() ?? await widget.api.getUserId();
      final result = await widget.api.sendChat(userId: userId, message: message, conversationId: conversationId);
      if (!mounted) return;
      setState(() {
        conversationId ??= result.conversationId;
        reply = result.reply;
        corrections
          ..clear()
          ..addAll(result.corrections);
        tips = result.tips;
        analysisCompleted = result.analysisCompleted;
        analysisError = result.analysisMessage;
        exchanges++;
        sending = false;
        active = true;
        status = result.analysisCompleted ? 'يتحدث الآن...' : 'تم حفظ كلامك دون اكتمال التحليل';
      });
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      await tts.awaitSpeakCompletion(true);
      if (result.reply.trim().isNotEmpty) {
        await tts.stop();
        await tts.speak(result.reply);
      }
    } catch (error) {
      if (mounted) {
        final isUnauthorized = error is DioException && error.response?.statusCode == 401;
        final isMissingAuth = error is StateError && error.message == 'AUTH_MISSING';
        final message = isUnauthorized || isMissingAuth
            ? 'انتهت جلسة الدخول. سجّل الخروج ثم ادخل من جديد قبل بدء المحادثة.'
            : 'تعذر الوصول إلى Backend على ${widget.api.baseUrl}. تحقق من تشغيل الخادم وAPI_BASE_URL ثم حاول مرة أخرى.';
        setState(() {
          sending = false;
          submittedCurrent = false;
          analysisCompleted = false;
          analysisError = message;
          status = message;
        });
      }
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
          topic: sessionTopic['title'] ?? 'محادثة إنجليزية',
          analysisCompleted: analysisCompleted,
          analysisMessage: analysisError,
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
        title: Text('${sessionTopic['level']} · ${sessionTopic['title']}', style: ar(12, color: inkFaint)),
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
            if (transcript.isNotEmpty) ...[
              TextButton.icon(onPressed: () => setState(() => showTranscript = !showTranscript), icon: Icon(showTranscript ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 17), label: Text(showTranscript ? 'إخفاء كلامك' : 'إظهار كلامك', style: ar(11.5, color: primary))),
              if (showTranscript) Padding(padding: const EdgeInsets.symmetric(horizontal: 26), child: Text(transcript, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: ar(12, color: inkSoft))),
            ],
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
  final String topic;
  final bool analysisCompleted;
  final String? analysisMessage;
  const FeedbackScreen({super.key, required this.api, this.corrections = const [], this.reply = '', this.tips = const [], this.duration = 0, this.exchanges = 0, this.topic = 'محادثة إنجليزية', this.analysisCompleted = false, this.analysisMessage});
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
    final now = DateTime.now();
    final quizErrors = [...all]
      ..removeWhere((item) {
        final date = item.lastOccurrence;
        final outsideMonth = date != null && (date.year != now.year || date.month != now.month);
        return item.wrong.trim().isEmpty || item.correct.trim().isEmpty || outsideMonth;
      })
      ..sort((a, b) => b.count.compareTo(a.count));
    final quizItems = quizErrors.take(3).toList();
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, elevation: 0, title: Text('مراجعة المحادثة', style: ar(16, weight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
        const _FeedbackCelebration(),
        Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(20)), child: Text('✓ انتهت المحادثة', style: ar(12, weight: FontWeight.w700, color: primaryDark)))),
        Center(child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(!widget.analysisCompleted ? 'لم يكتمل تحليل الجلسة' : all.isEmpty ? 'لم تظهر أخطاء واضحة' : 'أداء جيد اليوم', style: ar(18, weight: FontWeight.w700)))),
        Center(child: Text('${minutes}د ${seconds}ث · ${widget.exchanges} تبادلات · ${widget.topic}', style: ar(12.5, color: inkFaint))),
        if (widget.reply.isNotEmpty) ...[const _SectionTitle('رد المساعد'), _Card(child: Text(widget.reply, style: ar(13, color: inkSoft).copyWith(height: 1.7)))],
        if (widget.tips.isNotEmpty) ...[const _SectionTitle('نصيحة لك'), _Card(child: Text(widget.tips.join('\n'), style: ar(13, color: inkSoft).copyWith(height: 1.7)))],
        if (loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: primary))),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, textAlign: TextAlign.center, style: ar(12, color: rust))),
        if (!widget.analysisCompleted) _Card(child: Text(widget.analysisMessage ?? 'لم يصل تحليل حقيقي لهذه الجلسة. شغّل Backend ومزود AI ثم أعد المحاولة.', textAlign: TextAlign.center, style: ar(13, color: inkSoft).copyWith(height: 1.7))),
        if (!loading && widget.analysisCompleted && all.isNotEmpty) ...[
          _SectionTitle('الأخطاء التي تحتاج مراجعة (${historical.length})'),
          ...all.asMap().entries.map((entry) => _ReviewCard(number: '${entry.key + 1}', wrong: entry.value.wrong, correct: entry.value.correct, explain: '${entry.value.explanation}${entry.value.count > 1 ? ' · تكررت ${entry.value.count} مرات' : ''}')),
        ],
        if (!loading && widget.analysisCompleted && all.isEmpty) _Card(child: Text('ممتاز. لم تظهر أخطاء واضحة في هذه الجلسة، وسيظهر أي خطأ حقيقي هنا بعد تحليله.', textAlign: TextAlign.center, style: ar(13, color: inkSoft).copyWith(height: 1.7))),
        if (!loading && quizItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PersonalizedPracticeCard(
            errors: quizItems,
            onStart: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonalizedErrorQuizScreen(errors: quizItems))),
          ),
        ],
        const SizedBox(height: 22),
        FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.bolt), label: Text('العودة للمحادثة', style: ar(14, weight: FontWeight.w700)), style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.all(16))),
      ]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String number;
  final String wrong;
  final String correct;
  final String explain;

  const _ReviewCard({required this.number, required this.wrong, required this.correct, required this.explain});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, backgroundColor: rustTint, child: Text(number, style: mono(11, color: rust))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('"$wrong"', style: en(13.5, color: rust).copyWith(decoration: TextDecoration.lineThrough)),
                      Text('✓ $correct', style: en(13.5, weight: FontWeight.w600, color: primaryDark)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: line),
            Text(explain, style: ar(12.5, color: inkSoft).copyWith(height: 1.7)),
          ],
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String text;

  const _WordChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(color: paper, border: Border.all(color: line), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: ar(12.5)),
    );
  }
}

class ExploreContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
    const _SectionTitle('استكشف'),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [primaryDark, primary]), borderRadius: BorderRadius.circular(18)), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('✦ اقتراح ذكي لك', style: ar(11, weight: FontWeight.w700, color: Colors.white)), const SizedBox(height: 8), Text('بناءً على محادثاتك الأخيرة، ركّزي هالأسبوع على Present Perfect ونطق حرف th — قبل ما ننتقل لمهارة جديدة.', style: ar(13, color: Colors.white).copyWith(height: 1.6))])),
      const SizedBox(width: 8),
      _SparkleArt(),
    ])),
    const SizedBox(height: 16),
    GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.05, children: [_Skill(title: 'التحدث', english: 'Speaking', value: 70, color: primaryTint), _Skill(title: 'الاستماع', english: 'Listening', value: 55, color: const Color(0xFFE7EEF7)), _Skill(title: 'القراءة', english: 'Reading', value: 48, color: const Color(0xFFF7EEDB)), _Skill(title: 'الكتابة', english: 'Writing', value: 40, color: const Color(0xFFF6E6EB)), _Skill(title: 'القواعد', english: 'Grammar', value: 58, color: const Color(0xFFE9E7F2)), _Skill(title: 'المفردات', english: 'Vocabulary', value: 65, color: const Color(0xFFF8E7E6))],),
  ]);
}
class _Skill extends StatelessWidget {
  final String title;
  final String english;
  final int value;
  final Color color;

  const _Skill({required this.title, required this.english, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.auto_awesome_outlined, size: 19, color: primary)),
          const SizedBox(height: 9),
          Text(title, style: ar(13.5, weight: FontWeight.w700)),
          Text(english, style: en(11, color: inkFaint)),
          const Spacer(),
          ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: value / 100, minHeight: 5, backgroundColor: line, color: primary)),
          const SizedBox(height: 5),
          Text('$value%', style: mono(10.5, color: inkFaint)),
        ],
      ),
    );
  }
}

class ProgressContent extends StatelessWidget {
  final HiwarProfile? profile;
  final VoidCallback? onLevelCheck;
  const ProgressContent({super.key, this.profile, this.onLevelCheck});
  @override
  Widget build(BuildContext context) {
    final level = profile?.level.trim().isNotEmpty == true && profile!.level != 'pending' ? profile!.level : 'لم يحدد بعد';
    final days = profile?.daysSinceJoined ?? 0;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
    const _SectionTitle('تقدّم'),
    _Card(child: Row(children: [_Ring(value: '${profile?.levelScore ?? 0}%', label: 'المستوى'), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(level, style: ar(14.5, weight: FontWeight.w700)), Text(days == 0 ? 'ابدأ أول جلسة لك' : 'عضو منذ $days يوم', style: ar(12, color: inkFaint))])])),
    const SizedBox(height: 14),
    _Card(onTap: onLevelCheck, child: Row(children: [const _LevelMeterArt(size: 58), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('حدد مستواك من جديد', style: ar(14, weight: FontWeight.w700)), Text('اختبار قصير يعطيك مسارًا أدق', style: ar(11.5, color: inkFaint))])), const Icon(Icons.chevron_left, color: inkFaint)])),
    const _SectionTitle('سجل الأخطاء المتكررة'),
    _Card(child: ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(radius: 12, backgroundColor: primaryTint, child: Icon(Icons.auto_awesome, size: 15, color: primary)), title: const Text('سجل أخطائك يظهر هنا'), subtitle: Text('بعد أول محادثة ستجد ملاحظاتك الحقيقية هنا', style: ar(11.5, color: inkFaint)))),
  ]);
  }
}

class ProfileContent extends StatefulWidget {
  final HiwarApi api;
  final HiwarProfile? profile;
  final Future<void> Function()? onSignOut;
  const ProfileContent({super.key, required this.api, this.profile, this.onSignOut});
  @override State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  HiwarStats? stats;
  HiwarProfile? editedProfile;
  String? error;
  bool loading = true;
  bool reminderEnabled = true;

  @override
  void initState() {
    super.initState();
    editedProfile = widget.profile;
    _load();
  }

  Future<void> _load() async {
    try {
      final id = widget.profile?.userId ?? await widget.api.getUserId();
      final result = await widget.api.getStats(id);
      if (mounted) setState(() { stats = result; error = null; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; });
    }
  }

  String _value(String? value) => value == null || value.trim().isEmpty ? 'غير محدد' : value;

  TableRow _profileTableRow(String label, String? value) => TableRow(children: [
    Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Text(label, style: ar(12, color: inkFaint))),
    Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Text(_value(value), style: ar(12.5, weight: FontWeight.w600, color: inkSoft))),
  ]);

  Future<void> _editProfile() async {
    final current = editedProfile ?? widget.profile;
    if (current == null) return;
    final updated = await Navigator.push<HiwarProfile>(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditScreen(api: widget.api, profile: current)),
    );
    if (updated != null && mounted) setState(() => editedProfile = updated);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تسجيل الخروج', style: ar(17, weight: FontWeight.w800)),
          content: Text('هل أنت متأكد أنك تريد تسجيل الخروج؟', style: ar(13, color: inkSoft)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('لا، إلغاء', style: ar(13, weight: FontWeight.w700, color: inkSoft))),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: rust, foregroundColor: Colors.white),
              child: Text('نعم، تسجيل الخروج', style: ar(13, weight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final onSignOut = widget.onSignOut;
      if (onSignOut != null) {
        await onSignOut();
      } else {
        await widget.api.signOut();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الخروج بنجاح.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تسجيل الخروج، حاول مرة أخرى.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = editedProfile ?? widget.profile;
    final score = profile?.levelScore ?? stats?.levelScore ?? 0;
    final level = score > 0 ? (profile?.level ?? stats?.level ?? 'لم يحدد بعد') : 'لم يحدد بعد';
    final name = profile?.name ?? stats?.userName ?? 'معلوماتي في حوار';
    final initial = name.trim().isEmpty ? 'ح' : name.trim().substring(0, 1);
    return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 32), children: [
      Align(alignment: Alignment.centerRight, child: Text('حسابي', style: ar(21, weight: FontWeight.w800))),
      const SizedBox(height: 14),
      _Card(child: Column(children: [
        Row(children: [
          Container(width: 64, height: 64, decoration: const BoxDecoration(color: primary, shape: BoxShape.circle), child: Center(child: Text(initial, style: ar(24, weight: FontWeight.w800, color: Colors.white)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: ar(19, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_value(profile?.email), style: en(12, color: inkFaint)),
            const SizedBox(height: 9),
            Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5), decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(16)), child: Text(level, style: ar(11, weight: FontWeight.w700, color: primary))),
          ])),
          IconButton(onPressed: _editProfile, tooltip: 'تعديل المعلومات', icon: const Icon(Icons.edit_outlined, color: inkSoft, size: 20)),
        ]),
      ])),
      const SizedBox(height: 14),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _MetricTile(value: profile?.dailyMinutes == null ? '—' : '${profile!.dailyMinutes}', label: 'دقيقة يومية'),
        _MetricTile(value: '${stats?.totalSessions ?? 0}', label: 'محادثة'),
        _MetricTile(value: score > 0 ? '$score' : '—', label: 'نقطة المستوى'),
        _MetricTile(value: '${stats?.streakDays ?? 0}', label: 'يوم متتالٍ'),
      ])),
      const _SectionTitle('الإنجازات'),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _Badge(icon: Icons.local_fire_department_outlined, label: 'أيام متتالية', unlocked: (stats?.streakDays ?? 0) > 0),
        const SizedBox(width: 9),
        _Badge(icon: Icons.record_voice_over_outlined, label: 'أول محادثة', unlocked: (stats?.totalSessions ?? 0) > 0),
        const SizedBox(width: 9),
        _Badge(icon: Icons.emoji_events_outlined, label: 'مستوى محدد', unlocked: score > 0),
      ])),
      const _SectionTitle('التدريب'),
      _Card(child: Column(children: [
        _TrainingRow(icon: Icons.access_time_rounded, title: 'الهدف اليومي', value: profile?.dailyMinutes == null ? 'غير محدد' : '${profile!.dailyMinutes} دقيقة', onTap: _editProfile),
        const Divider(height: 1, color: line),
        _TrainingRow(icon: Icons.mic_none_rounded, title: 'لهجة الذكاء الاصطناعي', value: 'American', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('إعداد اللهجة سيتوفر قريبًا.')))),
        const Divider(height: 1, color: line),
        _TrainingRow(icon: Icons.notifications_none_rounded, title: 'تذكير المحادثة اليومية', value: reminderEnabled ? 'مفعّل' : 'متوقف', trailing: Switch(value: reminderEnabled, onChanged: (value) => setState(() => reminderEnabled = value)), onTap: () => setState(() => reminderEnabled = !reminderEnabled)),
      ])),
      const _SectionTitle('معلوماتي الشخصية'),
      _Card(child: Table(
        columnWidths: const {0: FixedColumnWidth(116)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _profileTableRow('العمر', profile?.age?.toString()),
          _profileTableRow('المرحلة الدراسية', profile?.educationLevel),
          _profileTableRow('أهداف التعلم', profile?.learningReason),
          _profileTableRow('المهارات المطلوبة', profile?.focusSkills),
          _profileTableRow('البريد الإلكتروني', profile?.email),
        ],
      )),
      if (loading) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator(color: primary))),
      if (!loading && error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text('تعذر تحميل الإحصاءات: $error', style: ar(11, color: rust))),
      const SizedBox(height: 26),
      _Card(
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout_rounded, color: rust, size: 19),
            label: Text(
              'تسجيل الخروج',
              style: ar(13.5, weight: FontWeight.w700, color: rust),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: rust,
              side: const BorderSide(color: Color(0xFFE8BFC3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class ProfileEditScreen extends StatefulWidget {
  final HiwarApi api;
  final HiwarProfile profile;
  const ProfileEditScreen({super.key, required this.api, required this.profile});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController name;
  late final TextEditingController age;
  late final TextEditingController learningReason;
  late final TextEditingController focusSkills;
  late final TextEditingController dailyMinutes;
  late String education;
  bool saving = false;

  static const levels = ['مبتدئ', 'أساسي', 'متوسط', 'متقدم'];

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    name = TextEditingController(text: profile.name);
    age = TextEditingController(text: profile.age?.toString() ?? '');
    learningReason = TextEditingController(text: profile.learningReason ?? '');
    focusSkills = TextEditingController(text: profile.focusSkills ?? '');
    dailyMinutes = TextEditingController(text: profile.dailyMinutes?.toString() ?? '');
    education = levels.contains(profile.educationLevel) ? profile.educationLevel! : 'متوسط';
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _save() async {
    if (name.text.trim().isEmpty || saving) return;
    setState(() => saving = true);
    try {
      final updated = await widget.api.updateProfile(
        userId: widget.profile.userId,
        name: name.text.trim(),
        age: int.tryParse(age.text.trim()),
        educationLevel: education,
        learningReason: _optional(learningReason.text),
        dailyMinutes: int.tryParse(dailyMinutes.text.trim()),
        focusSkills: _optional(focusSkills.text),
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ معلوماتك، حاول مرة أخرى.')));
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    learningReason.dispose();
    focusSkills.dispose();
    dailyMinutes.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label) => InputDecoration(labelText: label, filled: true, fillColor: paper, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primary, width: 1.5)));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg, elevation: 0, title: Text('تعديل معلوماتي', style: ar(17, weight: FontWeight.w800))),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 30), children: [
          _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('بياناتك الشخصية', style: ar(15, weight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: _decoration('الاسم')),
            const SizedBox(height: 11),
            TextField(controller: age, keyboardType: TextInputType.number, decoration: _decoration('العمر')),
            const SizedBox(height: 11),
            DropdownButtonFormField<String>(value: education, decoration: _decoration('المرحلة الدراسية'), items: levels.map((item) => DropdownMenuItem(value: item, child: Text(item, style: ar(13)))).toList(), onChanged: (value) { if (value != null) setState(() => education = value); }),
            const SizedBox(height: 11),
            TextField(controller: dailyMinutes, keyboardType: TextInputType.number, decoration: _decoration('كم دقيقة تتعلم يوميًا؟')),
            const SizedBox(height: 11),
            TextField(controller: learningReason, maxLines: 2, decoration: _decoration('لماذا تريد تعلم الإنجليزية؟')),
            const SizedBox(height: 11),
            TextField(controller: focusSkills, maxLines: 2, decoration: _decoration('المهارات التي تريد تطويرها')),
          ])),
          const SizedBox(height: 18),
          FilledButton(onPressed: saving ? null : _save, style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 16)), child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('حفظ التعديلات', style: ar(14, weight: FontWeight.w700, color: Colors.white))),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  const _InfoRow({required this.label, this.value});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 112, child: Text(label, style: ar(12, color: inkFaint))), Expanded(child: Text(value == null || value!.trim().isEmpty ? 'غير محدد' : value!, style: ar(12.5, weight: FontWeight.w600, color: inkSoft)))]));
}

class _AccountStat extends StatelessWidget {final String value,label;const _AccountStat({required this.value,required this.label});@override Widget build(BuildContext context)=>_Card(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(value,style:mono(17,weight:FontWeight.w600,color:primary)),Text(label,style:ar(11,color:inkFaint))]));}

class _MetricTile extends StatelessWidget {
  final String value;
  final String label;
  const _MetricTile({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    height: 84,
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(value, style: mono(17, weight: FontWeight.w700, color: ink)),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center, style: ar(10, color: inkFaint)),
    ]),
  );
}

class _TrainingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _TrainingRow({required this.icon, required this.title, required this.value, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
    height: 62,
    child: Row(children: [
      Icon(icon, color: inkSoft, size: 21),
      const SizedBox(width: 12),
      Expanded(child: Text(title, style: ar(13, weight: FontWeight.w600))),
      if (trailing != null) trailing! else Text(value, style: en(12, color: inkSoft)),
      const SizedBox(width: 8),
      const Icon(Icons.chevron_left_rounded, color: inkFaint, size: 20),
    ]),
  ));
}


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

class _AnalysisRow extends StatelessWidget {
  final String label;
  final String value;
  const _AnalysisRow({required this.label, required this.value});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: ar(12, color: inkSoft)), Text(value, style: mono(12, weight: FontWeight.w700, color: primary))]));
}

class LevelCheckScreen extends StatefulWidget {
  final HiwarApi? api;
  final String? userId;
  final String? focusSkills;
  final VoidCallback? onComplete;
  const LevelCheckScreen({super.key, this.api, this.userId, this.focusSkills, this.onComplete});
  @override
  State<LevelCheckScreen> createState() => _LevelCheckScreenState();
}

class _LevelCheckScreenState extends State<LevelCheckScreen> {
  int section = 0;
  int question = 0;
  int score = 0;
  int answeredQuestions = 0;
  bool showResult = false;
  int resultScore = 0;
  int resultKnowledgeScore = 0;
  String resultLevel = '';
  bool listening = false;
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  bool playingListening = false;
  String spokenText = '';
  bool showSpokenText = false;
  bool analyzing = false;
  Map<String, dynamic> speakingAnalysis = const {};
  late final VideoPlayerController videoController;
  bool videoReady = false;
  bool videoFailed = false;
  late List<String> listeningOptions;

  bool get aiChoosesSkill => (widget.focusSkills ?? '').contains('ما أعرف');

  Future<void> submitReading(String answer) async {
    answeredQuestions++;
    score += answer.startsWith('Small') ? 1 : 0;
    if (widget.api != null && widget.userId != null) {
      try {
        await widget.api!.assessReading(userId: widget.userId!, passage: 'Learning a language takes practice. Small daily conversations can help you become more confident and understand people from different cultures.', answer: answer);
      } catch (_) {}
    }
    if (mounted) setState(() => section++);
  }

  final grammar = <Map<String, Object>>[
    {'q': 'She ___ to work every day.', 'a': ['go', 'goes', 'going'], 'correct': 1},
    {'q': 'I have lived here ___ 2020.', 'a': ['for', 'since', 'during'], 'correct': 1},
    {'q': 'They ___ dinner when I called.', 'a': ['had', 'were having', 'have'], 'correct': 1},
    {'q': 'If I had time, I ___ more.', 'a': ['study', 'studied', 'would study'], 'correct': 2},
    {'q': 'This is the book ___ I told you about.', 'a': ['who', 'where', 'that'], 'correct': 2},
    {'q': 'He ___ already finished the report.', 'a': ['has', 'have', 'having'], 'correct': 0},
    {'q': 'We ___ to the museum last weekend.', 'a': ['go', 'went', 'gone'], 'correct': 1},
    {'q': 'There ___ many ways to practice English.', 'a': ['is', 'are', 'be'], 'correct': 1},
  ];
  final vocabulary = <Map<String, Object>>[
    {'q': 'What does “accurate” mean?', 'a': ['correct', 'fast', 'difficult'], 'correct': 0},
    {'q': 'The opposite of “borrow” is…', 'a': ['lend', 'keep', 'buy'], 'correct': 0},
    {'q': 'A “deadline” is…', 'a': ['a final time', 'a conversation', 'a holiday'], 'correct': 0},
    {'q': '“Improve” means to…', 'a': ['get better', 'get smaller', 'stop'], 'correct': 0},
    {'q': 'A person who travels is a…', 'a': ['traveler', 'listener', 'writer'], 'correct': 0},
    {'q': 'If you are “reliable”, people can…', 'a': ['trust you', 'avoid you', 'forget you'], 'correct': 0},
    {'q': '“Brief” means…', 'a': ['short', 'expensive', 'noisy'], 'correct': 0},
    {'q': 'A “habit” is something you…', 'a': ['do regularly', 'buy once', 'never remember'], 'correct': 0},
  ];

  @override
  void initState() {
    super.initState();
    grammar.shuffle();
    vocabulary.shuffle();
    listeningOptions = aiChoosesSkill
        ? ['They are practicing ordering coffee.', 'They are discussing a flight cancellation.', 'They are watching a football match.']
        : ['They are practicing ordering coffee.', 'A butterfly is flying over the flowers.', 'The room is completely empty.'];
    videoController = VideoPlayerController.asset('assets/hiwar-english-conversation.mp4');
    videoController.setLooping(false);
    videoController.initialize().then((_) {
      if (mounted) setState(() => videoReady = true);
    }).catchError((_) {
      if (mounted) setState(() => videoFailed = true);
    });
  }

  @override
  void dispose() { speech.stop(); tts.stop(); videoController.dispose(); super.dispose(); }

  List<Map<String, Object>> get currentQuestions => section == 0 ? grammar : vocabulary;

  void answer(int index) {
    answeredQuestions++;
    if (index == currentQuestions[question]['correct']) score++;
    if (question < currentQuestions.length - 1) { setState(() => question++); return; }
    setState(() { section++; question = 0; });
  }

  Future<void> startSpeaking() async {
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    final ready = await speech.initialize(
      debugLogging: false,
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') setState(() => listening = false);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => listening = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تشغيل المايك: ${error.errorMsg}')));
      },
    );
    if (!ready) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسمح للمتصفح باستخدام الميكروفون من رمز القفل بجانب localhost ثم حاول مرة أخرى.')));
      return;
    }
    if (mounted) setState(() { listening = true; showSpokenText = false; spokenText = ''; });
    await speech.listen(
      localeId: 'en_US',
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      onResult: (result) {
        if (!mounted) return;
        setState(() => spokenText = result.recognizedWords);
        if (result.finalResult) setState(() => listening = false);
      },
    );
  }

  Future<void> playListeningClip() async {
    if (!videoReady) return;
    if (videoController.value.isPlaying) {
      await videoController.pause();
      if (mounted) setState(() => playingListening = false);
      return;
    }
    await videoController.play();
    if (mounted) setState(() => playingListening = true);
  }

  String levelFromScore(int value) {
    if (value < 25) return 'A1 — مبتدئ';
    if (value < 45) return 'A2 — ابتدائي';
    if (value < 65) return 'B1 — متوسط';
    if (value < 82) return 'B2 — فوق المتوسط';
    return 'C1 — متقدم';
  }

  Future<void> finish() async {
    if (widget.api == null || widget.userId == null) return;
    setState(() => analyzing = true);
    try {
      speakingAnalysis = await widget.api!.assessSpeaking(userId: widget.userId!, prompt: 'Tell me about yourself.', transcript: spokenText);
    } catch (_) {
      speakingAnalysis = {'estimated_level': 'pending', 'overall_score': score * 10, 'feedback': 'تعذر الاتصال بتحليل AI. يمكنك إعادة المحاولة بعد تشغيل Backend.'};
    }
    final remoteLevel = '${speakingAnalysis['estimated_level'] ?? ''}'.trim().toUpperCase();
    final speakingScore = (speakingAnalysis['overall_score'] as num?)?.toInt();
    final knowledgeScore = ((score / 12) * 100).round().clamp(0, 100).toInt();
    final finalScore = speakingScore == null || speakingScore <= 0 ? knowledgeScore : ((knowledgeScore * .5) + (speakingScore * .5)).round().clamp(0, 100).toInt();
    final computedLevel = levelFromScore(finalScore);
    final aiLevelIsValid = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].any((level) => remoteLevel.startsWith(level));
    final estimated = aiLevelIsValid ? remoteLevel : computedLevel;
    try { await widget.api!.saveLevelResult(userId: widget.userId!, level: estimated, score: finalScore); } catch (_) {}
    if (!mounted) return;
    setState(() {
      analyzing = false;
      resultScore = finalScore;
      resultKnowledgeScore = knowledgeScore;
      resultLevel = estimated;
      showResult = true;
    });
  }

  TextStyle ar(double size, {FontWeight weight = FontWeight.w400, Color color = ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);

  Widget _resultMetric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
        child: Column(children: [
          Text(value, style: mono(16, color: primary)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: ar(11, color: inkFaint)),
        ]),
      ),
    );
  }

  Widget _buildResultView() {
    final percent = resultScore.clamp(0, 100);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      children: [
      Row(children: [
        IconButton(onPressed: () => widget.onComplete?.call(), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: ink)),
        Expanded(child: Text('نتيجة تحديد المستوى', textAlign: TextAlign.center, style: ar(17, weight: FontWeight.w800))),
        const SizedBox(width: 48),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
        decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(28), border: Border.all(color: line)),
        child: Column(children: [
          Container(width: 104, height: 104, decoration: BoxDecoration(color: primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primary.withOpacity(.25), blurRadius: 22, offset: const Offset(0, 10))]), child: Center(child: Text('$percent%', style: ar(24, weight: FontWeight.w800, color: Colors.white)))),
          const SizedBox(height: 16),
          Text('مستواك التقديري', style: ar(12, color: inkFaint)),
          const SizedBox(height: 4),
          Text('$resultLevel', style: ar(22, weight: FontWeight.w800, color: primary)),
          const SizedBox(height: 10),
          Text('نتيجتك مبنية على إجاباتك في الاختبار وتحليل Speaking بالذكاء الاصطناعي.', textAlign: TextAlign.center, style: ar(12.5, color: inkSoft).copyWith(height: 1.7)),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        _resultMetric('أسئلة أجبت عنها', '$answeredQuestions / 12'),
        const SizedBox(width: 10),
        _resultMetric('إجابات صحيحة', '$score / 12'),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _resultMetric('نسبة المعرفة', '$resultKnowledgeScore%'),
        const SizedBox(width: 10),
        _resultMetric('Speaking', spokenText.trim().isEmpty ? 'غير مكتمل' : 'مكتمل'),
      ]),
      const SizedBox(height: 16),
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ملخص الاختبار', style: ar(14, weight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text('${speakingAnalysis['feedback'] ?? 'تحليل AI جاهز.'}', style: ar(12.5, color: inkSoft).copyWith(height: 1.7)),
        const SizedBox(height: 8),
        Text('تم احتساب النتيجة من Grammar وVocabulary وReading وListening، مع تحليل إجابة Speaking.', style: ar(11, color: inkFaint).copyWith(height: 1.6)),
      ])),
      const SizedBox(height: 18),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: widget.onComplete, style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text('ابدأ التعلم', style: ar(14, weight: FontWeight.w800, color: Colors.white)))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (showResult) {
      return Scaffold(backgroundColor: bg, body: _buildResultView());
    }
    final isReading = section == 2;
    final isListening = section == 3;
    final isSpeaking = section == 4;
    final totalSections = 5;
    return Scaffold(backgroundColor: bg, appBar: AppBar(backgroundColor: bg, elevation: 0, title: Text('تحديد المستوى', style: ar(16, weight: FontWeight.w700))), body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 30), children: [
      Row(
        children: List.generate(
          totalSections,
          (index) => Expanded(
            child: Container(
              margin: EdgeInsets.only(
                left: index == totalSections - 1 ? 0 : 4,
              ),
              height: 5,
              decoration: BoxDecoration(
                color: index <= section ? primary : line,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text('المرحلة ${section + 1} من $totalSections', textAlign: TextAlign.center, style: ar(11.5, color: inkFaint, weight: FontWeight.w600)),
      const SizedBox(height: 18),
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
        Text('اقرأ القطعة ثم أجب عن السؤال.', style: ar(14, weight: FontWeight.w700)), const SizedBox(height: 12), _Card(child: Text('Learning a language takes practice. Small daily conversations can help you become more confident and understand people from different cultures.', style: en(15, color: inkSoft).copyWith(height: 1.7))), const SizedBox(height: 14), _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('What helps you become more confident?', style: en(15, weight: FontWeight.w700)), const SizedBox(height: 12), ...['Small daily conversations', 'Watching no videos', 'Avoiding practice'].map((item) => ListTile(contentPadding: EdgeInsets.zero, title: Text(item, style: en(13)), onTap: () => submitReading(item)))])),
      ] else if (isListening) ...[
        Text('استمع إلى المقطع ثم اختر المعنى الأقرب.', style: ar(14, weight: FontWeight.w700)),
        const SizedBox(height: 12),
        _Card(child: Column(children: [
          Text(aiChoosesSkill ? 'اختار لك الـAI سؤالًا مختلفًا يناسب تقييمك. شاهد المقطع ثم اختر المعنى الأقرب.' : 'شاهد المقطع ثم اختر الجملة التي تصف ما سمعته في الحوار.', textAlign: TextAlign.center, style: ar(13, color: inkSoft).copyWith(height: 1.6)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: videoReady
                ? AspectRatio(
                    aspectRatio: videoController.value.aspectRatio == 0 ? 16 / 9 : videoController.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(videoController),
                        DecoratedBox(
                          decoration: BoxDecoration(color: Colors.black.withOpacity(.24), shape: BoxShape.circle),
                          child: IconButton(
                            onPressed: playListeningClip,
                            icon: Icon(playingListening ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 34),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(height: 190, color: primaryTint, child: Center(child: videoFailed ? Text('تعذر تحميل الفيديو. تحققي من اتصال الإنترنت.', textAlign: TextAlign.center, style: ar(12, color: rust)) : const CircularProgressIndicator(color: primary))),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: videoReady ? playListeningClip : null, icon: Icon(playingListening ? Icons.pause_rounded : Icons.play_arrow_rounded), label: Text(playingListening ? 'إيقاف الفيديو' : 'تشغيل الفيديو', style: ar(12, weight: FontWeight.w700)), style: FilledButton.styleFrom(backgroundColor: primaryTint, foregroundColor: primary)),
          const SizedBox(height: 10),
          ...listeningOptions.map((item) => ListTile(contentPadding: EdgeInsets.zero, title: Text(item, style: en(13)), onTap: () { answeredQuestions++; score += item == listeningOptions.first ? 1 : 0; setState(() => section++); })),
        ])),
      ] else if (isSpeaking) ...[
        Text('تحدث لمدة 30–60 ثانية عن نفسك.', style: ar(14, weight: FontWeight.w700)), const SizedBox(height: 12), _Card(child: Column(children: [Text('Tell me about yourself.', textAlign: TextAlign.center, style: en(22, weight: FontWeight.w700, color: primary)), const SizedBox(height: 16), IconButton(onPressed: startSpeaking, icon: Icon(listening ? Icons.stop_circle : Icons.mic_rounded, color: listening ? rust : primary, size: 58)), if (spokenText.isNotEmpty) ...[
          TextButton.icon(onPressed: () => setState(() => showSpokenText = !showSpokenText), icon: Icon(showSpokenText ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 17), label: Text(showSpokenText ? 'إخفاء كلامك' : 'إظهار كلامك', style: ar(11.5, color: primary))),
          if (showSpokenText) Text(spokenText, textAlign: TextAlign.center, style: en(13, color: inkSoft).copyWith(height: 1.6)),
        ], const SizedBox(height: 8), Text('Grammar · Vocabulary · Fluency · Pronunciation · Naturalness', textAlign: TextAlign.center, style: ar(11, color: inkFaint))])),
        const SizedBox(height: 18), FilledButton(onPressed: analyzing || spokenText.trim().isEmpty ? null : finish, style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.all(16)), child: Text(analyzing ? 'جارٍ تحليل إجابتك...' : 'حلّل مستواي بالـAI', style: ar(14, weight: FontWeight.w700, color: Colors.white))),
      ] else ...[],
    ]));
  }
}


class _PersonalizedPracticeCard extends StatelessWidget {
  final List<HiwarError> errors;
  final VoidCallback onStart;

  const _PersonalizedPracticeCard({required this.errors, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final top = errors.first;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.auto_awesome, color: primary)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('مبني على أخطائك المتكررة', style: ar(14, weight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('تمرين مخصص لك', style: ar(12, color: inkFaint)),
              ])),
            ],
          ),
          const SizedBox(height: 12),
          Text('${errors.length} ${errors.length == 1 ? 'سؤال اختاره' : 'أسئلة اختارها'} لك النظام من أكثر أخطائك تكرارًا هذا الشهر.', style: ar(12.5, color: inkSoft).copyWith(height: 1.6)),
          const SizedBox(height: 8),
          Text('من: ${_practiceTypeLabel(top.errorType)} ×${top.count}', style: ar(11.5, color: primary, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.play_arrow_rounded), label: Text('ابدأ التمرين', style: ar(12.5, weight: FontWeight.w700)), style: FilledButton.styleFrom(backgroundColor: primary, minimumSize: const Size.fromHeight(44))),
        ],
      ),
    );
  }
}

String _practiceTypeLabel(String type) {
  switch (type.toLowerCase()) {
    case 'grammar':
      return 'Grammar';
    case 'vocabulary':
      return 'Vocabulary';
    case 'pronunciation':
      return 'Pronunciation';
    case 'sentence_structure':
      return 'Sentence structure';
    case 'naturalness':
      return 'Naturalness';
    default:
      return type.isEmpty ? 'ملاحظة من المحادثة' : type;
  }
}

class PersonalizedErrorQuizScreen extends StatefulWidget {
  final List<HiwarError> errors;

  const PersonalizedErrorQuizScreen({super.key, required this.errors});

  @override
  State<PersonalizedErrorQuizScreen> createState() => _PersonalizedErrorQuizScreenState();
}

class _PersonalizedErrorQuizScreenState extends State<PersonalizedErrorQuizScreen> {
  int index = 0;
  int correctAnswers = 0;
  String? selected;

  HiwarError get current => widget.errors[index];

  List<String> get options {
    final values = <String>[current.correct, current.wrong];
    if (values[0].trim() == values[1].trim()) values[1] = '${current.wrong} (كما قلتها سابقًا)';
    return values;
  }

  void answer(String value) {
    if (selected != null) return;
    final isCorrect = value == current.correct;
    setState(() {
      selected = value;
      if (isCorrect) correctAnswers++;
    });
  }

  void next() {
    if (index == widget.errors.length - 1) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text('خلصت التمرين', style: ar(17, weight: FontWeight.w800)),
          content: Text('أجبت صح على $correctAnswers من ${widget.errors.length} أسئلة.', style: ar(14, color: inkSoft)),
          actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: Text('تم', style: ar(13, color: primary, weight: FontWeight.w700)))],
        ),
      );
      return;
    }
    setState(() { index++; selected = null; });
  }

  @override
  Widget build(BuildContext context) {
    final item = current;
    final answered = selected != null;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, elevation: 0, title: Text('تمرين مخصص لك', style: ar(16, weight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          Row(children: List.generate(widget.errors.length, (i) => Expanded(child: Container(margin: EdgeInsets.only(left: i == widget.errors.length - 1 ? 0 : 5), height: 6, decoration: BoxDecoration(color: i <= index ? primary : line, borderRadius: BorderRadius.circular(6)))))),
          const SizedBox(height: 22),
          Text('السؤال ${index + 1} من ${widget.errors.length}', style: ar(12, color: inkFaint)),
          const SizedBox(height: 10),
          _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('من: ${_practiceTypeLabel(item.errorType)} ×${item.count}', style: ar(12, color: primary, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('اختر التصحيح الصحيح للجملة أو العبارة:', style: ar(14, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('"${item.wrong}"', style: en(18, color: inkSoft).copyWith(fontStyle: FontStyle.italic)),
          ])),
          const SizedBox(height: 14),
          ...options.map((option) {
            final isSelected = selected == option;
            final isCorrect = option == item.correct;
            final color = !answered ? line : isCorrect ? const Color(0xFFBFE8D1) : isSelected ? const Color(0xFFF4C3C0) : line;
            return Padding(padding: const EdgeInsets.only(bottom: 10), child: OutlinedButton(onPressed: answered ? null : () => answer(option), style: OutlinedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15), side: BorderSide(color: isSelected || (answered && isCorrect) ? primary : line)), child: Align(alignment: Alignment.centerRight, child: Text(option, style: en(14, color: ink)))));
          }),
          if (answered) ...[
            const SizedBox(height: 4),
            _Card(child: Text(selected == item.correct ? 'صح! ${item.explanation.isEmpty ? 'ممتاز، استمر على هذا الاستخدام.' : item.explanation}' : 'راجعها مرة ثانية: ${item.explanation.isEmpty ? 'حاول استخدام الصياغة الصحيحة في محادثتك القادمة.' : item.explanation}', style: ar(13, color: inkSoft).copyWith(height: 1.7))),
            const SizedBox(height: 14),
            FilledButton(onPressed: next, style: FilledButton.styleFrom(backgroundColor: primary, minimumSize: const Size.fromHeight(48)), child: Text(index == widget.errors.length - 1 ? 'إنهاء التمرين' : 'السؤال التالي', style: ar(13.5, weight: FontWeight.w700, color: Colors.white))),
          ],
        ],
      ),
    );
  }
}
