import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../services/hiwar_api.dart';
import '../tutor/tutor_models.dart';

const _bg = Color(0xFFEEEAE4);
const _paper = Color(0xFFFFFDF9);
const _primary = Color(0xFF4B3F8F);
const _primaryTint = Color(0xFFE9E7F2);
const _ink = Color(0xFF27252E);
const _inkSoft = Color(0xFF625E6B);
const _line = Color(0xFFE2DDD5);
const _rust = Color(0xFFA75442);

class SmartSpeakingScreen extends StatefulWidget {
  final HiwarApi api;
  final String mode;
  final String? topic;
  final String? goal;

  const SmartSpeakingScreen({super.key, required this.api, this.mode = 'conversation', this.topic, this.goal});

  @override
  State<SmartSpeakingScreen> createState() => _SmartSpeakingScreenState();
}

class _SmartSpeakingScreenState extends State<SmartSpeakingScreen> {
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  SpeakingSessionData? session;
  SpeakingTurnData? turn;
  SpeakingRetryData? retry;
  SpeakingSummaryData? summary;
  bool loading = true;
  bool listening = false;
  bool sending = false;
  bool retryMode = false;
  bool submittedCurrent = false;
  bool showTranscript = false;
  String transcript = '';
  String status = 'نجهّز هدف الجلسة...';
  String? error;
  Timer? timer;
  int seconds = 0;

  TextStyle ar(double size, {FontWeight weight = FontWeight.w400, Color color = _ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);
  TextStyle en(double size, {FontWeight weight = FontWeight.w400, Color color = _ink}) => GoogleFonts.ibmPlexSans(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    timer?.cancel();
    speech.stop();
    tts.stop();
    super.dispose();
  }

  Future<void> _startSession() async {
    try {
      final value = await widget.api.startTutorSpeaking(mode: widget.mode, topic: widget.topic, goal: widget.goal);
      if (!mounted) return;
      setState(() {
        session = value;
        loading = false;
        status = 'اسمع السؤال ثم ابدأ الحديث';
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && summary == null) setState(() => seconds++);
      });
      await _speak(value.openingPrompt);
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'تعذر بدء جلسة Speaking. تأكد من تسجيل الدخول وتشغيل الـBackend.'; });
    }
  }

  Future<void> _toggleListening() async {
    if (sending || loading || summary != null) return;
    if (listening) {
      await speech.stop();
      if (mounted) setState(() { listening = false; status = 'جاري تحليل كلامك...'; });
      await _submitTranscript();
      return;
    }
    final available = await speech.initialize(
      onStatus: (value) {
        if (mounted && value == 'done') setState(() => listening = false);
      },
      onError: (_) {
        if (mounted) setState(() { listening = false; status = 'تعذر الوصول للميكروفون'; });
      },
    );
    if (!available) {
      if (mounted) setState(() => status = 'اسمح للتطبيق باستخدام الميكروفون');
      return;
    }
    await tts.stop();
    setState(() {
      listening = true;
      submittedCurrent = false;
      transcript = '';
      status = retryMode ? 'أعد الجملة المصححة' : 'أنا أستمع لك...';
    });
    await speech.listen(
      localeId: 'en_US',
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
      onResult: (result) {
        if (!mounted) return;
        setState(() => transcript = result.recognizedWords);
        if (result.finalResult && !submittedCurrent) {
          setState(() { listening = false; status = 'جاري التحليل...'; });
          _submitTranscript();
        }
      },
    );
  }

  Future<void> _submitTranscript() async {
    final message = transcript.trim();
    if (message.isEmpty || submittedCurrent || sending || session == null) {
      if (message.isEmpty && mounted) setState(() => status = 'حاول قول جملة قصيرة بالإنجليزي');
      return;
    }
    setState(() { sending = true; submittedCurrent = true; error = null; });
    try {
      if (retryMode && turn != null) {
        final value = await widget.api.retryTutorSpeakingTurn(turnId: turn!.turnId, transcript: message);
        if (!mounted) return;
        setState(() {
          retry = value;
          sending = false;
          retryMode = value.nextAction == 'retry_again';
          status = value.successful
              ? 'تحسنت المحاولة — نكمل المحادثة'
              : retryMode
                  ? 'حاول مرة أخرى'
                  : 'سجلنا المحاولة — نكمل المحادثة';
        });
        await _speak(retryMode ? turn!.retryPhrase : turn!.reply);
      } else {
        final value = await widget.api.submitTutorSpeakingTurn(sessionId: session!.sessionId, transcript: message);
        if (!mounted) return;
        setState(() {
          turn = value;
          retry = null;
          sending = false;
          retryMode = value.retryRequired;
          status = value.retryRequired ? 'اسمع التصحيح ثم أعد الجملة' : 'دورك الآن';
        });
        await _speak(value.retryRequired && value.retryPhrase.isNotEmpty ? value.retryPhrase : value.reply);
      }
    } catch (_) {
      if (mounted) setState(() { sending = false; submittedCurrent = false; error = 'تعذر إرسال كلامك إلى المعلم. حاول مرة أخرى.'; status = 'تعذر الاتصال بالخادم'; });
    }
  }

  Future<void> _speak(String value) async {
    if (value.trim().isEmpty) return;
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.44);
    await tts.setPitch(1.0);
    await tts.awaitSpeakCompletion(true);
    await tts.stop();
    await tts.speak(value);
  }

  Future<void> _finish() async {
    if (session == null || sending) return;
    timer?.cancel();
    await speech.stop();
    await tts.stop();
    setState(() { sending = true; listening = false; });
    try {
      final value = await widget.api.finishTutorSpeaking(session!.sessionId);
      if (mounted) setState(() { summary = value; sending = false; status = 'انتهت الجلسة'; });
    } catch (_) {
      if (mounted) setState(() { sending = false; error = 'تعذر إنهاء الجلسة وحفظ ملخصها.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator(color: _primary)));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          title: Text('Speaking Coach', style: ar(16, weight: FontWeight.w800)),
          actions: [if (summary == null) TextButton(onPressed: _finish, child: Text('إنهاء', style: ar(12, weight: FontWeight.w700, color: _rust)))],
        ),
        body: summary != null ? _summaryView() : _sessionView(),
      ),
    );
  }

  Widget _sessionView() {
    final elapsed = '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('${session?.level ?? 'A1'} · ${session?.mode ?? ''}', style: en(12, weight: FontWeight.w700, color: _primary)), const Spacer(), Text(elapsed, style: en(12, color: _inkSoft))]),
          const SizedBox(height: 8),
          Text(session?.topic ?? '', style: en(18, weight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('هدف الجلسة: ${session?.goal ?? ''}', style: ar(12, color: _inkSoft).copyWith(height: 1.6)),
        ])),
        const SizedBox(height: 18),
        Center(child: Text(status, style: ar(13, weight: FontWeight.w700, color: _inkSoft))),
        const SizedBox(height: 14),
        if (turn == null) _englishBubble(session?.openingPrompt ?? '') else ...[
          _englishBubble(turn!.reply),
          if (turn!.feedback.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...turn!.feedback.map(_feedbackCard),
          ],
          if (retry != null) ...[
            const SizedBox(height: 10),
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(retry!.successful ? '✓ تحسنت المحاولة' : 'أعد المحاولة', style: ar(13, weight: FontWeight.w800, color: retry!.successful ? _primary : _rust)),
              const SizedBox(height: 5),
              Text('${retry!.feedbackAr}\nدرجة المطابقة: ${retry!.similarityScore}% · التحسن: ${retry!.improvement >= 0 ? '+' : ''}${retry!.improvement}', style: ar(12, color: _inkSoft).copyWith(height: 1.6)),
            ])),
          ],
        ],
        if (transcript.isNotEmpty) ...[
          const SizedBox(height: 10),
          TextButton.icon(onPressed: () => setState(() => showTranscript = !showTranscript), icon: Icon(showTranscript ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18), label: Text(showTranscript ? 'إخفاء كلامك' : 'إظهار كلامك', style: ar(12, color: _primary))),
          if (showTranscript) _card(Directionality(textDirection: TextDirection.ltr, child: Text(transcript, textAlign: TextAlign.left, style: en(14, color: _inkSoft).copyWith(height: 1.6)))),
        ],
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, textAlign: TextAlign.center, style: ar(12, color: _rust))),
        const SizedBox(height: 28),
        Center(
          child: IconButton(
            onPressed: sending ? null : _toggleListening,
            icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 40),
            style: IconButton.styleFrom(backgroundColor: listening ? _rust : _primary, fixedSize: const Size(92, 92)),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text(retryMode ? 'اضغط وأعد الجملة المصححة' : 'اضغط وتحدث، ثم توقف عند نهاية الجملة', style: ar(11.5, color: _inkSoft))),
      ],
    );
  }

  Widget _summaryView() => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
        Icon(Icons.auto_awesome_rounded, size: 58, color: _primary),
        const SizedBox(height: 12),
        Text('ملخص جلسة Speaking', textAlign: TextAlign.center, style: ar(20, weight: FontWeight.w800)),
        const SizedBox(height: 16),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ما أنجزته', style: ar(14, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...summary!.achievements.map((item) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('✓ $item', style: ar(12.5, color: _inkSoft)))),
          const Divider(height: 24, color: _line),
          Text('المراجعة القادمة', style: ar(14, weight: FontWeight.w800)),
          Text(summary!.reviewFocus, style: ar(12.5, color: _inkSoft).copyWith(height: 1.6)),
          const SizedBox(height: 8),
          Text('الأدلة المسجلة: ${summary!.evidenceCount}', style: ar(11.5, color: _primary)),
        ])),
        const SizedBox(height: 12),
        Text(summary!.messageAr, textAlign: TextAlign.center, style: ar(12, color: _inkSoft).copyWith(height: 1.7)),
        const SizedBox(height: 18),
        FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(backgroundColor: _primary, padding: const EdgeInsets.all(16)), child: Text('العودة للرئيسية', style: ar(14, weight: FontWeight.w700, color: Colors.white))),
      ]);

  Widget _englishBubble(String value) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _primaryTint, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD9D5E9))),
        child: Directionality(textDirection: TextDirection.ltr, child: Text(value, textAlign: TextAlign.left, style: en(16, color: _ink).copyWith(height: 1.6))),
      );

  Widget _feedbackCard(TutorFeedback item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${item.wrong} → ${item.corrected}', textDirection: TextDirection.ltr, style: en(14, weight: FontWeight.w700, color: _rust)),
          const SizedBox(height: 5),
          Text(item.explanationAr, style: ar(12, color: _inkSoft).copyWith(height: 1.6)),
          if (turn?.retryPhrase.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 8), child: Text(turn!.retryPhrase, textDirection: TextDirection.ltr, style: en(13, weight: FontWeight.w600, color: _primary))),
        ])),
      );

  Widget _card(Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: child);
}
