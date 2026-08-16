// مرجع التصميم: شاشة دخول حوار App RTL، خلفية دافئة، بنفسجي Speak، واجهة مختصرة وواضحة.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/hiwar_api.dart';

class AuthScreen extends StatefulWidget {
  final HiwarApi api;
  final ValueChanged<HiwarProfile> onSignedIn;
  const AuthScreen({super.key, required this.api, required this.onSignedIn});
  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  bool busy = false;
  String? error;
  final google = GoogleSignIn(scopes: ['email', 'profile']);

  Future<void> _finish({required String userId, required String displayName, String? address, String provider = 'manual', String? subject}) async {
    setState(() { busy = true; error = null; });
    try {
      final profile = await widget.api.signIn(userId: userId, name: displayName, email: address, provider: provider, subject: subject);
      await widget.api.saveUserId(profile.userId);
      if (mounted) widget.onSignedIn(profile);
    } catch (e) {
      if (mounted) setState(() { error = 'تعذر تسجيل الدخول. تأكدي من تشغيل Backend.'; busy = false; });
    }
  }

  Future<void> _googleSignIn() async {
    try {
      final account = await google.signIn();
      if (account == null) return;
      await _finish(userId: account.id, displayName: account.displayName ?? account.email.split('@').first, address: account.email, provider: 'google', subject: account.id);
    } catch (_) {
      if (mounted) setState(() => error = 'لم يكتمل تسجيل Google. يمكنك استخدام الدخول اليدوي مؤقتًا.');
    }
  }

  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: const Color(0xFFF6F3EF), body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(24, 48, 24, 24), children: [
    Center(child: Container(width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFF4B3F8F), shape: BoxShape.circle), child: const Icon(Icons.forum_outlined, color: Colors.white, size: 34))),
    const SizedBox(height: 20),
    Text('حوار App', textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSansArabic(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF241F38))),
    const SizedBox(height: 6), Text('تعلّمي الإنجليزية بطريقة تناسبك', textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: const Color(0xFF948DA6))),
    const SizedBox(height: 38),
    FilledButton.icon(onPressed: busy ? null : _googleSignIn, icon: const Icon(Icons.g_mobiledata, size: 28), label: Text('تسجيل الدخول باستخدام Google', style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700)), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4B3F8F), padding: const EdgeInsets.all(16))),
    const SizedBox(height: 18), Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('أو', style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF948DA6)))), const Expanded(child: Divider())]),
    const SizedBox(height: 18),
    TextField(controller: name, decoration: InputDecoration(labelText: 'الاسم', labelStyle: GoogleFonts.ibmPlexSansArabic(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 12), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'البريد الإلكتروني (اختياري)', labelStyle: GoogleFonts.ibmPlexSansArabic(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 14), OutlinedButton(onPressed: busy ? null : () { if (name.text.trim().isEmpty) { setState(() => error = 'اكتبي اسمك أولًا.'); return; } _finish(userId: 'manual-${email.text.trim().isEmpty ? name.text.trim().toLowerCase().replaceAll(' ', '-') : email.text.trim()}', displayName: name.text.trim(), address: email.text.trim().isEmpty ? null : email.text.trim()); }, child: Text('دخول', style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700))),
    if (busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
    if (error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(error!, textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFFB23B3B), fontSize: 12))),
  ]))));
}
