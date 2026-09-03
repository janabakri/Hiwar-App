// تدريب متقطع (Spaced Repetition) على أخطاء المستخدم المستحقة للمراجعة.
import 'package:flutter/material.dart';
import '../services/hiwar_api.dart';

const bg = Color(0xFFF6F3EF);
const paper = Colors.white;
const ink = Color(0xFF241F38);
const inkSoft = Color(0xFF635C7A);
const primary = Color(0xFF4B3F8F);
const primaryDark = Color(0xFF332A66);
const primaryTint = Color(0xFFECEAF7);
const rust = Color(0xFFB23B3B);
const rustTint = Color(0xFFF8E7E6);
const line = Color(0xFFE6E1DA);

TextStyle ar(double size,
        {FontWeight weight = FontWeight.w400, Color color = ink}) =>
    TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFamily: 'IBM Plex Sans Arabic');
TextStyle en(double size,
        {FontWeight weight = FontWeight.w400, Color color = ink}) =>
    TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFamily: 'IBM Plex Sans');

class ReviewScreen extends StatefulWidget {
  final HiwarApi api;
  final String userId;
  const ReviewScreen({super.key, required this.api, required this.userId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<HiwarError> queue = const [];
  int index = 0;
  bool loading = true;
  String? error;
  bool revealed = false;
  int doneCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId.trim().isEmpty) {
      setState(() {
        loading = false;
        error = 'سجّل الدخول لبدء المراجعة.';
      });
      return;
    }
    try {
      final items = await widget.api.getReviewQueue(widget.userId);
      if (mounted)
        setState(() {
          queue = items;
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          error = HiwarApi.describeError(e);
        });
    }
  }

  Future<void> _answer(bool remembered) async {
    if (index >= queue.length) return;
    final current = queue[index];
    try {
      await widget.api.answerReview(
          userId: widget.userId,
          errorId: current.id ?? 0,
          remembered: remembered);
    } catch (_) {
      // لا نوقف التدريب لو فشل الحفظ — المستخدم يكمل ونعيد المحاولة لاحقاً.
    }
    if (!mounted) return;
    setState(() {
      revealed = false;
      index++;
      doneCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            title:
                Text('راجع ملاحظاتك', style: ar(17, weight: FontWeight.w800))),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: primary))
            : error != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(error!,
                            textAlign: TextAlign.center,
                            style: ar(13, color: inkSoft))))
                : index >= queue.length
                    ? _buildDone()
                    : _buildCard(),
      ),
    );
  }

  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.emoji_events_outlined, size: 52, color: primary),
          const SizedBox(height: 14),
          Text(
              doneCount == 0
                  ? 'ما في ملاحظات مستحقة اليوم 🎉'
                  : 'خلصت مراجعة اليوم! راجعت $doneCount ملاحظة.',
              textAlign: TextAlign.center,
              style: ar(15, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('نرجّع لك الملاحظات بعد يوم أو ٣ أيام حسب تقدمك.',
              textAlign: TextAlign.center, style: ar(12.5, color: inkSoft)),
          const SizedBox(height: 22),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 14)),
              child: Text('رجوع',
                  style: ar(14, weight: FontWeight.w700, color: Colors.white))),
        ]),
      ),
    );
  }

  Widget _buildCard() {
    final current = queue[index];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('${index + 1} من ${queue.length}',
              style: ar(12.5, weight: FontWeight.w600, color: inkSoft)),
          const SizedBox(width: 10),
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                      value: index / queue.length,
                      minHeight: 6,
                      backgroundColor: line,
                      color: primary))),
        ]),
        const SizedBox(height: 26),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: line),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 14,
                      offset: Offset(0, 5))
                ]),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: primaryTint,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(current.errorType,
                      style: ar(11, weight: FontWeight.w700, color: primary))),
              const Spacer(),
              Text('كيف تصح هالجملة؟', style: ar(13, color: inkSoft)),
              const SizedBox(height: 8),
              Text('"${current.wrong}"',
                  style: en(20, weight: FontWeight.w700, color: rust)),
              const Spacer(),
              if (revealed) ...[
                Text('✓ ${current.correct}',
                    style: en(20, weight: FontWeight.w700, color: primaryDark)),
                if (current.explanation.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(current.explanation,
                      style: ar(13, color: inkSoft).copyWith(height: 1.7)),
                ],
                const Spacer(),
              ] else
                Center(
                    child: OutlinedButton(
                        onPressed: () => setState(() => revealed = true),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: primary),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 26, vertical: 13)),
                        child: Text('اكشف الإجابة',
                            style: ar(13.5,
                                weight: FontWeight.w700, color: primary)))),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        if (revealed)
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => _answer(false),
                    icon:
                        const Icon(Icons.close_rounded, size: 18, color: rust),
                    label: Text('ما تذكرت',
                        style: ar(13.5, weight: FontWeight.w700, color: rust)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: rustTint),
                        padding: const EdgeInsets.symmetric(vertical: 14)))),
            const SizedBox(width: 12),
            Expanded(
                child: FilledButton.icon(
                    onPressed: () => _answer(true),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('تذكرت!',
                        style: ar(13.5, weight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14)))),
          ]),
      ]),
    );
  }
}
