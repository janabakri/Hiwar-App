// مرجع التصميم: دخول حوار App RTL، لوحة بنفسجية هادئة، بطاقة بيضاء، وتسلسل واضح بين Google وSign up.
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

  InputDecoration fieldDecoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: const Color(0xFF948DA6), size: 20),
      filled: true,
      fillColor: const Color(0xFFF9F7F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFE8E2DB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF4B3F8F), width: 1.4)),
    );
  }

  Future<void> _finishGoogle() async {
    try {
      final account = await google.signIn();
      if (account == null) return;
      setState(() { busy = true; error = null; });
      final profile = await widget.api.signIn(userId: account.id, name: account.displayName ?? account.email.split('@').first, email: account.email, provider: 'google', subject: account.id);
      await widget.api.saveUserId(profile.userId);
      if (mounted) widget.onSignedIn(profile);
    } catch (_) {
      if (mounted) setState(() { busy = false; error = 'لم يكتمل تسجيل Google. تحققي من إعداد OAuth أو استخدمي Sign up.'; });
    }
  }

  Future<void> _manualSignIn() async {
    if (email.text.trim().isEmpty || password.text.length < 8) {
      setState(() => error = 'أدخلي البريد وكلمة المرور الصحيحة.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final profile = await widget.api.passwordSignIn(email: email.text.trim(), password: password.text);
      await widget.api.saveUserId(profile.userId);
      if (mounted) widget.onSignedIn(profile);
    } catch (_) {
      if (mounted) setState(() { busy = false; error = 'البريد أو كلمة المرور غير صحيحة، أو لم يتم تفعيل البريد.'; });
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
      final sent = result['sent'] == true;
      if (mounted) setState(() { busy = false; waitingForCode = sent; error = sent ? null : 'لم يتم إرسال البريد. يجب إعداد SMTP في Backend أولًا.'; });
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

  Widget _socialButton() {
    return SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: busy ? null : _finishGoogle, icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))), label: Text('المتابعة باستخدام Google', style: arabic(13.5, weight: FontWeight.w700)), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF241F38), side: const BorderSide(color: Color(0xFFE1DBD3)), padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))));
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4B3F8F);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F3EF),
        body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(22, 24, 22, 28), children: [
          Center(child: Container(width: 56, height: 56, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(17), boxShadow: [BoxShadow(color: primary.withOpacity(.22), blurRadius: 18, offset: const Offset(0, 8))]), child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 27))),
          const SizedBox(height: 18),
          Center(child: Text(waitingForCode ? 'باقي خطوة واحدة' : (signupMode ? 'أنشئي حسابك في حوار' : 'أهلًا فيك 👋'), textAlign: TextAlign.center, style: arabic(19, weight: FontWeight.w800))),
          const SizedBox(height: 6),
          Center(child: Text(waitingForCode ? 'تحققي من بريدك الإلكتروني لنكمل معًا.' : (signupMode ? 'احفظي تقدمك وخلي تجربتك مصممة لك.' : 'سجّلي دخولك عشان تكملي رحلتك بالإنجليزي'), textAlign: TextAlign.center, style: arabic(12.5, color: const Color(0xFF948DA6)).copyWith(height: 1.6))),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(19), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: const Color(0xFF32265C).withOpacity(.06), blurRadius: 24, offset: const Offset(0, 10))]), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!signupMode && !waitingForCode) ...[
              _socialButton(),
              const SizedBox(height: 16),
              Row(children: [const Expanded(child: Divider(color: Color(0xFFE8E2DB))), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('أو', style: arabic(11, color: const Color(0xFF948DA6)))), const Expanded(child: Divider(color: Color(0xFFE8E2DB)))]),
              const SizedBox(height: 16),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: fieldDecoration('البريد الإلكتروني', icon: Icons.mail_outline)),
              const SizedBox(height: 11),
              TextField(controller: password, obscureText: true, decoration: fieldDecoration('كلمة المرور', hint: '8 أحرف على الأقل', icon: Icons.lock_outline)),
              const SizedBox(height: 14),
              FilledButton(onPressed: busy ? null : _manualSignIn, style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Text('دخول', style: arabic(14, weight: FontWeight.w700, color: Colors.white))),
              const SizedBox(height: 8),
              TextButton(onPressed: busy ? null : () => setState(() { signupMode = true; error = null; }), child: Text('ما عندك حساب؟ إنشاء حساب بالبريد', style: arabic(12.5, weight: FontWeight.w700, color: primary))),
            ],
            if (signupMode || waitingForCode) ...[
              if (!waitingForCode) ...[
                TextField(controller: name, decoration: fieldDecoration('الاسم', icon: Icons.person_outline)),
                const SizedBox(height: 11),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: fieldDecoration('البريد الإلكتروني', icon: Icons.mail_outline)),
                const SizedBox(height: 11),
                TextField(controller: password, obscureText: true, decoration: fieldDecoration('كلمة المرور', hint: '8 أحرف على الأقل', icon: Icons.lock_outline)),
                const SizedBox(height: 15),
                FilledButton(onPressed: busy ? null : _requestSignupCode, style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Text('إنشاء الحساب وإرسال الرمز', style: arabic(13.5, weight: FontWeight.w700, color: Colors.white))),
              ] else ...[
                Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFF0EDF8), borderRadius: BorderRadius.circular(14)), child: Text('أرسلنا رمزًا إلى ${email.text.trim()}', textAlign: TextAlign.center, style: arabic(12.5, color: primary))),
                const SizedBox(height: 14),
                TextField(controller: code, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: fieldDecoration('رمز التحقق', hint: '000000')),
                const SizedBox(height: 15),
                FilledButton(onPressed: busy ? null : _verifySignup, style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Text('تأكيد البريد والدخول', style: arabic(14, weight: FontWeight.w700, color: Colors.white))),
              ],
              TextButton(onPressed: busy ? null : () => setState(() { signupMode = false; waitingForCode = false; error = null; }), child: Text('العودة لتسجيل الدخول', style: arabic(12, color: const Color(0xFF635C7A)))),
            ],
            if (busy) const Padding(padding: EdgeInsets.only(top: 13), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, textAlign: TextAlign.center, style: arabic(12, color: const Color(0xFFB23B3B)))),
          ])),
          const SizedBox(height: 16),
          Text('بالاستمرار، أنتِ توافقين على تجربة تعلم آمنة ومحترمة.', textAlign: TextAlign.center, style: arabic(10.5, color: const Color(0xFF948DA6))),
        ])),
      ),
    );
  }
}
