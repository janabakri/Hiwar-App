import 'package:flutter/material.dart';
import '../services/hiwar_api.dart';

class LevelHistoryScreen extends StatefulWidget {
  final HiwarApi api;
  final String userId;

  const LevelHistoryScreen(
      {super.key, required this.api, required this.userId});

  @override
  State<LevelHistoryScreen> createState() => _LevelHistoryScreenState();
}

class _LevelHistoryScreenState extends State<LevelHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<LevelHistoryEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.api.getLevelHistory(widget.userId);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = HiwarApi.describeError(e);
        _loading = false;
      });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقدمي عبر الوقت'),
        backgroundColor: cs.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : _entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.show_chart, size: 64, color: cs.primary),
                            const SizedBox(height: 16),
                            const Text(
                              'ما عندك نتائج اختبار بعد. سوي اختبار المستوى ورجع هنا — كل محاولة تنحفظ تلقائيًا وبتشوف تقدمك الحقيقي.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final first = _entries.first;
    final last = _entries.last;
    final delta = last.score - first.score;
    final hasProgress = delta > 0;
    final summaryColor =
        hasProgress ? Colors.green : (delta < 0 ? Colors.red : cs.primary);
    final summaryIcon = hasProgress
        ? Icons.trending_up
        : (delta < 0 ? Icons.trending_down : Icons.trending_flat);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card: first vs last attempt
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _attemptColumn('أول محاولة', first.score, first.level,
                        _fmtDate(first.createdAt)),
                    Icon(summaryIcon, size: 40, color: summaryColor),
                    _attemptColumn('آخر محاولة', last.score, last.level,
                        _fmtDate(last.createdAt)),
                  ],
                ),
                if (_entries.length > 1) ...[
                  const SizedBox(height: 16),
                  Text(
                    switch (delta) {
                      0 => 'نفس النتيجة — كمّل جهدك',
                      > 0 => 'تحسّنت +$delta% بين أول وآخر محاولة',
                      _ => 'تراجعت $delta% — بداية جديدة، كمّل جهدك',
                    },
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: summaryColor),
                  ),
                ],
                if (_entries.length == 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    'محاولة وحدة بس الحين — سوي اختبار ثاني عشان نشوف التقدم الفعلي.',
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('كل المحاولات (${_entries.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._entries.reversed.map((entry) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Text(
                  '${entry.score}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer),
                ),
              ),
              title: Text('المستوى ${entry.level} — ${entry.score}%'),
              subtitle: Text(_fmtDate(entry.createdAt)),
            ),
          );
        }),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _attemptColumn(String label, int score, String level, String date) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text('$score%',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(level, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 2),
        Text(date, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
