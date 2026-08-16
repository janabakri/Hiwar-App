// مرجع التصميم: شاشة دخول حوار App RTL، خلفية دافئة، بنفسجي Speak، وتدفق Sign up موثّق بالبريد.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/hiwar_api.dart';

class AuthScreen extends StatefulWidget {
  final HiwarApi api;
  final ValueChanged<HiwarProfile> onSignedIn;
  const AuthScreen({super.key, required this.api, required this.onSignedIn});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  final google = GoogleSignIn(scopes: ['email', 'profile']);
  bool busy = false;
  bool signupMode = false;
  bool waitingForCode = false;
  String? error;
  String? devCode;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  TextStyle arabic(double size, {FontWeight weight = FontWeight.w400, Color color = const Color(0xFF241F38)}) {
    return GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);
  }

  Future<void> _finishGoogle() async {
    try {
      final account = await google.signIn();
      if (account == null) return;
      setState(() { busy = true; error = null; });
      final profile = await widget.api.signIn(
        userId: account.id,
        name: account.displayName ?? account.email.split('@').first,
        email: account.email,
        provider: 'google',
        subject: account.id,
      );
      await widget.api.saveUserId(profile.userId);
      if (mounted) widget.onSignedIn(profile);
    } catch (_) {
      if (mounted) setState(() { busy = false; error = 'لم يكتمل تسجيل Google. تحققي من إعداد OAuth أو استخدمي Sign up.'; });
    }
  }

  Future<void> _manualSignIn() async {
    if (name.text.trim().isEmpty) {
      setState(() => error = 'اكتبي اسمك أولًا.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final address = email.text.trim().isEmpty ? null : email.text.trim();
      final userId = 'manual-${(address ?? name.text.trim()).toLowerCase().replaceAll(' ', '-')}';
      final profile = await widget.api.signIn(userId: userId, name: name.text.trim(), email: address);
      await widget.api.saveUserId(profile.userId);
      if (mounted) widget.onSignedIn(profile);
    } catch (_) {
      if (mounted) setState(() { busy = false; error = 'تعذر تسجيل الدخول. تأكدي من تشغيل Backend.'; });
    }
  }

  Future<void> _requestSignupCode() async {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty || password.text.length < 8) {
      setState(() => error = 'أدخلي الاسم والبريد وكلمة مرور من 8 أحرف على الأقل.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final result = await widget.api.signUp(name: name.text.trim(), email: email.text.trim(), password: password.text);
      if (mounted) {
        setState(() {
          busy = false;
          waitingForCode = true;
          devCode = result['dev_code']?.toString();
        });
      }
    } catch (_) {
      if (mounted) setState(() { busy = false; error = 'تعذر إنشاء الحساب. تحققي من البريد أو تشغيل Backend.'; });
    }
  }

  Future<void> _verifySignup() async {
    if (code.text.trim().length != 6) {
      setState(() => error = 'أدخلي رمز التحقق المكوّن من 6 أرقام.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final profile = await widget.api.verifyEmail(email: email.text.trim(), code: code.text.trim());
      await widget.api.saveUserId(profile.userId);
      if (mounted) widget.onSignedIn(profile);
    } catch (_) {
      if (mounted) setState(() { busy = false; error = 'رمز التحقق غير صحيح أو منتهي.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F3EF),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              Center(child: Container(width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFF4B3F8F), shape: BoxShape.circle), child: const Icon(Icons.forum_outlined, color: Colors.white, size: 34))),
              const SizedBox(height: 20),
              Text('حوار App', textAlign: TextAlign.center, style: arabic(28, weight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(signupMode ? 'أنشئي حسابك وابدئي رحلتك' : 'تعلّمي الإنجليزية بطريقة تناسبك', textAlign: TextAlign.center, style: arabic(13, color: const Color(0xFF948DA6))),
              const SizedBox(height: 32),
              if (!signupMode && !waitingForCode) ...[
                FilledButton.icon(onPressed: busy ? null : _finishGoogle, icon: const Icon(Icons.g_mobiledata, size: 28), label: Text('تسجيل الدخول باستخدام Google', style: arabic(14, weight: FontWeight.w700)), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4B3F8F), padding: const EdgeInsets.all(16))),
                const SizedBox(height: 14),
                TextButton(onPressed: busy ? null : () => setState(() { signupMode = true; error = null; }), child: Text('إنشاء حساب جديد بالبريد الإلكتروني', style: arabic(13, weight: FontWeight.w700, color: const Color(0xFF4B3F8F)))),
                const SizedBox(height: 8),
                Text('أو تسجيل دخول يدوي', textAlign: TextAlign.center, style: arabic(12, color: const Color(0xFF948DA6))),
              ],
              if (signupMode || waitingForCode) ...[
                if (!waitingForCode) ...[
                  TextField(controller: name, decoration: InputDecoration(labelText: 'الاسم', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 12),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: 'كلمة المرور', hintText: '8 أحرف على الأقل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: busy ? null : _requestSignupCode, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4B3F8F), padding: const EdgeInsets.all(16)), child: Text('إنشاء الحساب وإرسال رمز التحقق', style: arabic(13, weight: FontWeight.w700))),
                ] else ...[
                  Text('أرسلنا رمز تحقق إلى ${email.text.trim()}', textAlign: TextAlign.center, style: arabic(13, color: const Color(0xFF635C7A))),
                  const SizedBox(height: 14),
                  TextField(controller: code, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(labelText: 'رمز التحقق', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  if (devCode != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('رمز التطوير: $devCode', textAlign: TextAlign.center, style: arabic(12, color: const Color(0xFFB23B3B)))),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: busy ? null : _verifySignup, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4B3F8F), padding: const EdgeInsets.all(16)), child: Text('تأكيد البريد والدخول', style: arabic(14, weight: FontWeight.w700))),
                ],
                TextButton(onPressed: busy ? null : () => setState(() { signupMode = false; waitingForCode = false; error = null; }), child: Text('العودة لتسجيل الدخول', style: arabic(12, color: const Color(0xFF635C7A)))),
              ] else ...[
                const SizedBox(height: 12),
                TextField(controller: name, decoration: InputDecoration(labelText: 'الاسم', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'البريد الإلكتروني (اختياري)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 14),
                OutlinedButton(onPressed: busy ? null : _manualSignIn, child: Text('دخول', style: arabic(14, weight: FontWeight.w700))),
              ],
              if (busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(error!, textAlign: TextAlign.center, style: arabic(12, color: const Color(0xFFB23B3B)))),
            ],
          ),
        ),
      ),
    );
  }
}
