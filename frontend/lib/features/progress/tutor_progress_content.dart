import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/hiwar_api.dart';
import '../reading/smart_reading_screen.dart';
import '../speaking/smart_speaking_screen.dart';
import '../tutor/tutor_models.dart';

const _paper = Color(0xFFFFFDF9);
const _primary = Color(0xFF4B3F8F);
const _primaryTint = Color(0xFFE9E7F2);
const _ink = Color(0xFF27252E);
const _inkSoft = Color(0xFF625E6B);
const _line = Color(0xFFE2DDD5);
const _rust = Color(0xFFA75442);

class TutorProgressContent extends StatefulWidget {
  final HiwarApi api;
  final HiwarProfile? profile;
  final VoidCallback? onLevelCheck;

  const TutorProgressContent({
    super.key,
    required this.api,
    this.profile,
    this.onLevelCheck,
  });

  @override
  State<TutorProgressContent> createState() => _TutorProgressContentState();
}

class _TutorProgressContentState extends State<TutorProgressContent> {
  TutorProgressData? progress;
  TodayLearningPlanData? plan;
  bool loading = true;
  String? error;

  TextStyle ar(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _ink,
  }) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  TextStyle en(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _ink,
  }) =>
      GoogleFonts.ibmPlexSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final values = await Future.wait<dynamic>([
        widget.api.getTutorProgress(),
        widget.api.getTodayLearningPlan(),
      ]);
      if (!mounted) return;
      setState(() {
        progress = values[0] as TutorProgressData;
        plan = values[1] as TodayLearningPlanData;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذر تحميل تقدّمك الآن. تأكد من الاتصال ثم حاول مرة أخرى.';
      });
    }
  }

  void _openRecommendedActivity() {
    final value = plan;
    if (value == null) return;
    final Widget screen = value.recommendedSkill == 'reading'
        ? SmartReadingScreen(api: widget.api)
        : SmartSpeakingScreen(api: widget.api, goal: value.goal);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (loading && progress == null) {
      return const Center(
        child: CircularProgressIndicator(color: _primary),
      );
    }

    if (error != null && progress == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44, color: _rust),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center, style: ar(13, color: _inkSoft)),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: Text('إعادة المحاولة', style: ar(13, color: Colors.white))),
            ],
          ),
        ),
      );
    }

    final value = progress!;
    final levelHasEvidence = value.levelConfidence > 0;
    final levelLabel = levelHasEvidence
        ? value.level
        : (widget.profile?.levelScore ?? 0) > 0
            ? widget.profile!.level
            : 'قيد التحديد';

    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('تقدّمك الحقيقي', style: ar(20, weight: FontWeight.w800)),
              IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded, color: _primary)),
            ],
          ),
          const SizedBox(height: 12),
          _card(
            Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(color: _primaryTint, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(levelLabel, textDirection: TextDirection.ltr, style: en(18, weight: FontWeight.w800, color: _primary)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(levelHasEvidence ? 'المستوى المدعوم بأدلة' : 'نحتاج جلسات أكثر لتأكيد المستوى', style: ar(13.5, weight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        levelHasEvidence
                            ? 'ثقة الدليل ${(value.levelConfidence * 100).round()}% · ${value.totalSessions} جلسات مكتملة'
                            : 'لن نعطيك حكمًا دقيقًا قبل وجود أدلة كافية.',
                        style: ar(11.5, color: _inkSoft).copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _metricCard(value.speaking, 'التحدث', Icons.record_voice_over_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _metricCard(value.reading, 'القراءة', Icons.menu_book_outlined)),
            ],
          ),
          const SizedBox(height: 18),
          Text('خطة اليوم', style: ar(14, weight: FontWeight.w800, color: _inkSoft)),
          const SizedBox(height: 9),
          if (plan != null)
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: _primary),
                      const SizedBox(width: 8),
                      Text(_skillLabel(plan!.recommendedSkill), style: ar(13.5, weight: FontWeight.w800)),
                      const Spacer(),
                      Text('${plan!.suggestedMinutes} دقيقة', style: ar(11.5, color: _primary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(plan!.goal, textDirection: TextDirection.ltr, textAlign: TextAlign.left, style: en(14, weight: FontWeight.w700).copyWith(height: 1.5)),
                  const SizedBox(height: 7),
                  Text(plan!.reasonAr, style: ar(12, color: _inkSoft).copyWith(height: 1.65)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _openRecommendedActivity,
                      style: FilledButton.styleFrom(backgroundColor: _primary, padding: const EdgeInsets.all(14)),
                      child: Text('ابدأ النشاط المقترح', style: ar(13, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _card(
            Row(
              children: [
                const Icon(Icons.event_repeat_outlined, color: _primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value.dueReviews == 0
                        ? 'لا توجد مراجعات مستحقة الآن.'
                        : 'لديك ${value.dueReviews} نقاط حان وقت مراجعتها.',
                    style: ar(12.5, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (widget.onLevelCheck != null) ...[
            const SizedBox(height: 12),
            _card(
              InkWell(
                onTap: widget.onLevelCheck,
                child: Row(
                  children: [
                    const Icon(Icons.fact_check_outlined, color: _primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text('إعادة اختبار تحديد المستوى', style: ar(12.5, weight: FontWeight.w700))),
                    const Icon(Icons.chevron_left, color: _inkSoft),
                  ],
                ),
              ),
            ),
          ],
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, textAlign: TextAlign.center, style: ar(11.5, color: _rust))),
        ],
      ),
    );
  }

  Widget _metricCard(TutorProgressMetric metric, String label, IconData icon) {
    final score = metric.masteryScore;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary),
          const SizedBox(height: 9),
          Text(label, style: ar(13.5, weight: FontWeight.w800)),
          const SizedBox(height: 7),
          if (score == null) ...[
            Text('نحتاج أدلة أكثر', style: ar(11.5, weight: FontWeight.w700, color: _inkSoft)),
            const SizedBox(height: 5),
            Text('ابدأ أول جلسة', style: ar(10.5, color: _inkSoft)),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6,
                backgroundColor: _line,
                color: _primary,
              ),
            ),
            const SizedBox(height: 6),
            Text('$score% · ${metric.evidenceCount} أدلة', style: ar(10.5, color: _inkSoft)),
          ],
        ],
      ),
    );
  }

  String _skillLabel(String value) => value == 'reading' ? 'Reading' : 'Speaking';

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: child,
      );
}
