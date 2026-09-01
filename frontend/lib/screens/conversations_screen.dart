// شاشة المحادثات السابقة — قائمة الجلسات وقراءة أي جلسة كاملة.
import 'package:flutter/material.dart';
import '../services/hiwar_api.dart';

const bg = Color(0xFFF6F3EF);
const paper = Colors.white;
const ink = Color(0xFF241F38);
const inkSoft = Color(0xFF635C7A);
const inkFaint = Color(0xFF948DA6);
const primary = Color(0xFF4B3F8F);
const primaryTint = Color(0xFFECEAF7);
const line = Color(0xFFE6E1DA);

TextStyle ar(double size, {FontWeight weight = FontWeight.w400, Color color = ink}) => TextStyle(fontSize: size, fontWeight: weight, color: color, fontFamily: 'IBM Plex Sans Arabic');

class ConversationsScreen extends StatefulWidget {
  final HiwarApi api;
  final String userId;
  const ConversationsScreen({super.key, required this.api, required this.userId});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Map<String, dynamic>> conversations = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId.trim().isEmpty) {
      setState(() { loading = false; error = 'سجّل الدخول لعرض محادثاتك.'; });
      return;
    }
    try {
      final items = await widget.api.getConversations(widget.userId);
      if (mounted) setState(() { conversations = items; loading = false; });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = HiwarApi.describeError(e); });
    }
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year}/${local.month}/${local.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg, elevation: 0, title: Text('محادثاتك السابقة', style: ar(17, weight: FontWeight.w800))),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: primary))
            : error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center, style: ar(13, color: inkSoft))))
                : conversations.isEmpty
                    ? Center(child: Text('لا توجد محادثات بعد — ابدأ أول جلسة!', style: ar(13, color: inkSoft)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: CircleAvatar(backgroundColor: primaryTint, child: Text('${conversation['conversation_id'] ?? index + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primary))),
                              title: Text('${conversation['title'] ?? 'محادثة'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ar(13.5, weight: FontWeight.w600)),
                              subtitle: Text('${_formatDate('${conversation['updated_at'] ?? ''}')} · ${conversation['message_count'] ?? 0} رسالة', style: ar(11.5, color: inkFaint)),
                              trailing: const Icon(Icons.chevron_left_rounded, color: inkFaint),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationDetailScreen(api: widget.api, userId: widget.userId, conversationId: (conversation['conversation_id'] as num?)?.toInt() ?? 0, title: '${conversation['title'] ?? 'محادثة'}'))),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class ConversationDetailScreen extends StatefulWidget {
  final HiwarApi api;
  final String userId;
  final int conversationId;
  final String title;
  const ConversationDetailScreen({super.key, required this.api, required this.userId, required this.conversationId, required this.title});

  @override
  State<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  List<Map<String, dynamic>> messages = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.getConversationMessages(widget.userId, widget.conversationId);
      if (mounted) setState(() { messages = items; loading = false; });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = HiwarApi.describeError(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg, elevation: 0, title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ar(15, weight: FontWeight.w800))),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: primary))
            : error != null
                ? Center(child: Text(error!, style: ar(13, color: inkSoft)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isUser = message['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          decoration: BoxDecoration(
                            color: isUser ? primaryTint : paper,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: line),
                          ),
                          child: Text('${message['content'] ?? ''}', style: TextStyle(fontSize: 13.5, height: 1.6, color: isUser ? ink : inkSoft)),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
