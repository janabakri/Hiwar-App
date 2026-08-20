import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/hiwar_api.dart';
import '../speaking/smart_speaking_screen.dart';
import '../tutor/tutor_models.dart';

const _bg = Color(0xFFEEEAE4);
const _paper = Color(0xFFFFFDF9);
const _primary = Color(0xFF4B3F8F);
const _primaryTint = Color(0xFFE9E7F2);
const _ink = Color(0xFF27252E);
const _inkSoft = Color(0xFF625E6B);
const _line = Color(0xFFE2DDD5);
const _green = Color(0xFF4C7A66);
const _rust = Color(0xFFA75442);

class SmartReadingScreen extends StatefulWidget {
  final HiwarApi api;
  final String? level;
  final String? topic;
  final String? sourceText;

  const SmartReadingScreen({super.key, required this.api, this.level, this.topic, this.sourceText});

  @override
  State<SmartReadingScreen> createState() => _SmartReadingScreenState();
}

class _SmartReadingScreenState extends State<SmartReadingScreen> {
  final FlutterTts tts = FlutterTts();
  final TextEditingController openAnswer = TextEditingController();
  ReadingSessionData? session;
  ReadingAnswerData? answerResult;
  ReadingSummaryData? summary;
  int questionIndex = 0;
  bool loading = true;
  bool submitting = false;
  bool showQuestions = false;
  String? selectedAnswer;
  String? error;

  TextStyle ar(double size, {FontWeight weight = FontWeight.w400, Color color = _ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);
  TextStyle en(double size, {FontWeight weight = FontWeight.w400, Color color = _ink}) => GoogleFonts.ibmPlexSans(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    tts.stop();
    openAnswer.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final value = await widget.api.startTutorReading(level: widget.level, topic: widget.topic, sourceText: widget.sourceText);
      if (mounted) setState(() { session = value; loading = false; });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'تعذر إنشاء درس Reading. تأكد من تسجيل الدخول وتشغيل الـBackend.'; });
    }
  }

  Future<void> _speak(String value) async {
    if (value.trim().isEmpty) return;
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.38);
    await tts.stop();
    await tts.speak(value);
  }

  Future<void> _answer(String value) async {
    if (submitting || session == null || value.trim().isEmpty) return;
    final question = session!.questions[questionIndex];
    setState(() { submitting = true; selectedAnswer = value; error = null; });
    try {
      final result = await widget.api.submitTutorReadingAnswer(sessionId: session!.sessionId, questionId: question.id, answer: value.trim());
      if (mounted) setState(() { answerResult = result; submitting = false; });
    } catch (_) {
      if (mounted) setState(() { submitting = false; selectedAnswer = null; error = 'تعذر تقييم الإجابة. حاول مرة أخرى.'; });
    }
  }

  Future<void> _next() async {
    if (session == null) return;
    final isLast = questionIndex >= session!.questions.length - 1;
    if (isLast || answerResult?.nextAction == 'finish') {
      await _finish();
      return;
    }
    setState(() {
      questionIndex++;
      selectedAnswer = null;
      answerResult = null;
      openAnswer.clear();
    });
  }

  Future<void> _finish() async {
    if (session == null || submitting) return;
    setState(() => submitting = true);
    try {
      final value = await widget.api.finishTutorReading(session!.sessionId);
      if (mounted) setState(() { summary = value; submitting = false; });
    } catch (_) {
      if (mounted) setState(() { submitting = false; error = 'تعذر حفظ ملخص القراءة.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator(color: _primary)));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(backgroundColor: _bg, elevation: 0, title: Text('Reading Coach', style: ar(16, weight: FontWeight.w800))),
        body: error != null && session == null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center, style: ar(13, color: _rust))))
            : summary != null
                ? _summaryView()
                : _lessonView(),
      ),
    );
  }

  Widget _lessonView() {
    final lesson = session!;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _primaryTint, borderRadius: BorderRadius.circular(18)), child: Text(lesson.level, style: en(12, weight: FontWeight.w800, color: _primary))),
        const SizedBox(width: 8),
        Expanded(child: Text(lesson.topic, textAlign: TextAlign.left, textDirection: TextDirection.ltr, style: en(12, color: _inkSoft))),
      ]),
      const SizedBox(height: 12),
      Text(lesson.title, textAlign: TextAlign.left, textDirection: TextDirection.ltr, style: en(22, weight: FontWeight.w800)),
      const SizedBox(height: 12),
      _card(SelectableText(lesson.passage, textDirection: TextDirection.ltr, textAlign: TextAlign.left, style: en(15, color: _inkSoft).copyWith(height: 1.85))),
      const SizedBox(height: 16),
      Text('الكلمات المستهدفة', style: ar(14, weight: FontWeight.w800)),
      const SizedBox(height: 9),
      Wrap(spacing: 8, runSpacing: 8, children: lesson.targetWords.map((word) => ActionChip(
        avatar: const Icon(Icons.volume_up_outlined, size: 17, color: _primary),
        label: Text(word.word, style: en(12, weight: FontWeight.w600, color: _primary)),
        backgroundColor: _paper,
        side: const BorderSide(color: _line),
        onPressed: () => _showWord(word),
      )).toList()),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => setState(() => showQuestions = true),
        icon: const Icon(Icons.quiz_outlined),
        label: Text(showQuestions ? 'الأسئلة ظاهرة بالأسفل' : 'ابدأ أسئلة الفهم', style: ar(13, weight: FontWeight.w700)),
        style: FilledButton.styleFrom(backgroundColor: _primary, padding: const EdgeInsets.all(15)),
      ),
      if (showQuestions) ...[
        const SizedBox(height: 18),
        _questionCard(),
      ],
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: ar(12, color: _rust))),
    ]);
  }

  Widget _questionCard() {
    final question = session!.questions[questionIndex];
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('السؤال ${questionIndex + 1} من ${session!.questions.length}', style: ar(11.5, color: _inkSoft)),
        const Spacer(),
        Text(_questionTypeLabel(question.type), style: ar(11, weight: FontWeight.w700, color: _primary)),
      ]),
      const SizedBox(height: 12),
      Text(question.question, textDirection: TextDirection.ltr, textAlign: TextAlign.left, style: en(16, weight: FontWeight.w700).copyWith(height: 1.5)),
      const SizedBox(height: 14),
      if (question.options.isNotEmpty)
        ...question.options.map((option) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SizedBox(width: double.infinity, child: OutlinedButton(
                onPressed: answerResult == null && !submitting ? () => _answer(option) : null,
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(13),
                  side: BorderSide(color: selectedAnswer == option ? _primary : _line),
                  backgroundColor: selectedAnswer == option ? _primaryTint : _paper,
                ),
                child: Text(option, textAlign: TextAlign.left, textDirection: TextDirection.ltr, style: en(13, color: _ink)),
              )),
            ))
      else ...[
        TextField(controller: openAnswer, textDirection: TextDirection.ltr, enabled: answerResult == null, maxLines: 3, decoration: const InputDecoration(hintText: 'Write your answer in English', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: submitting || answerResult != null ? null : () => _answer(openAnswer.text), child: const Text('Submit answer'))),
      ],
      if (submitting) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: _primary))),
      if (answerResult != null) ...[
        const Divider(height: 24, color: _line),
        Text(answerResult!.correct ? '✓ إجابة صحيحة' : 'تحتاج مراجعة', style: ar(13.5, weight: FontWeight.w800, color: answerResult!.correct ? _green : _rust)),
        const SizedBox(height: 5),
        Text(answerResult!.feedbackAr, style: ar(12.5, color: _inkSoft).copyWith(height: 1.65)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: _next, style: FilledButton.styleFrom(backgroundColor: _primary), child: Text(questionIndex == session!.questions.length - 1 ? 'إنهاء الدرس' : 'السؤال التالي', style: ar(12.5, weight: FontWeight.w700, color: Colors.white)))),
      ],
    ]));
  }

  void _showWord(TargetWordData word) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(textDirection: TextDirection.rtl, child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(word.word, textDirection: TextDirection.ltr, style: en(24, weight: FontWeight.w800, color: _primary))),
            IconButton(onPressed: () => _speak(word.word), icon: const Icon(Icons.volume_up_rounded, color: _primary)),
          ]),
          if (word.ipa.isNotEmpty) Text(word.ipa, textDirection: TextDirection.ltr, style: en(13, color: _inkSoft)),
          const SizedBox(height: 12),
          Text(word.meaningAr, style: ar(15, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(word.example, textDirection: TextDirection.ltr, textAlign: TextAlign.left, style: en(13, color: _inkSoft).copyWith(height: 1.6)),
        ]),
      )),
    );
  }

  Widget _summaryView() => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
    Icon(Icons.menu_book_rounded, size: 58, color: _primary),
    const SizedBox(height: 12),
    Text('ملخص جلسة Reading', textAlign: TextAlign.center, style: ar(20, weight: FontWeight.w800)),
    const SizedBox(height: 14),
    _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${summary!.correctAnswers} من ${summary!.totalAnswers} · ${summary!.score}%', style: ar(18, weight: FontWeight.w800, color: _primary)),
      const SizedBox(height: 12),
      if (summary!.strengths.isNotEmpty) ...[
        Text('نقاط القوة', style: ar(13.5, weight: FontWeight.w800)),
        ...summary!.strengths.map((item) => Text('✓ $item', style: ar(12.5, color: _inkSoft))),
        const SizedBox(height: 12),
      ],
      Text('نقطة المراجعة', style: ar(13.5, weight: FontWeight.w800)),
      Text(summary!.reviewFocus, style: ar(12.5, color: _inkSoft).copyWith(height: 1.6)),
    ])),
    const SizedBox(height: 12),
    Text(summary!.messageAr, textAlign: TextAlign.center, style: ar(12, color: _inkSoft).copyWith(height: 1.7)),
    const SizedBox(height: 18),
    FilledButton.icon(
      onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SmartSpeakingScreen(api: widget.api, topic: session!.topic, goal: 'Summarize and discuss the reading passage'))),
      icon: const Icon(Icons.record_voice_over_outlined),
      label: Text('ناقش النص في Speaking', style: ar(13.5, weight: FontWeight.w700)),
      style: FilledButton.styleFrom(backgroundColor: _primary, padding: const EdgeInsets.all(16)),
    ),
    TextButton(onPressed: () => Navigator.pop(context), child: Text('العودة للرئيسية', style: ar(12.5, color: _primary))),
  ]);

  String _questionTypeLabel(String value) => {
    'main_idea': 'الفكرة الرئيسية',
    'detail': 'التفاصيل',
    'inference': 'الاستنتاج',
    'vocabulary': 'المفردات',
  }[value] ?? value;

  Widget _card(Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: child);
}
