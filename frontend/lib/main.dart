// مرجع التصميم: Speak RTL، خلفية دافئة، بنفسجي رئيسي، IBM Plex Sans Arabic/IBM Plex Sans/IBM Plex Mono.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/hiwar_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  runApp(const SpeakReplicaApp());
}

class SpeakReplicaApp extends StatelessWidget {
  const SpeakReplicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4B3F8F);
    return MaterialApp(
      title: 'حوار App',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFEEEAE4),
        colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light),
        textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final api = HiwarApi();
  HiwarProfile? profile;
  bool loading = true;
  bool welcomeSeen = false;
  bool needsLevelCheck = false;

  @override void initState() { super.initState(); _restore(); }

  bool _needsLevel(HiwarProfile value) {
    final level = value.level.trim().toLowerCase();
    final asksAiToAssess = (value.focusSkills ?? '').contains('ما أعرف');
    final hasNoResult = value.levelScore <= 0 || level.isEmpty || level == 'pending';
    return asksAiToAssess && hasNoResult;
  }

  Future<void> _restore() async {
    welcomeSeen = await api.hasSeenWelcome();
    final userId = await api.getStoredUserId();
    if (userId != null && userId.isNotEmpty) {
      try {
        profile = await api.getProfile(userId);
        needsLevelCheck = _needsLevel(profile!);
      } catch (_) { profile = null; }
    }
    if (mounted) setState(() => loading = false);
  }

  void _signedIn(HiwarProfile next) => setState(() { profile = next; needsLevelCheck = _needsLevel(next); });

  void _onOnboardingComplete(HiwarProfile next) => setState(() { profile = next; needsLevelCheck = _needsLevel(next); });

  Future<void> _onLevelComplete() async {
    final id = profile?.userId;
    if (mounted) setState(() => needsLevelCheck = false);
    if (id == null) return;
    try {
      final updated = await api.getProfile(id);
      if (mounted) setState(() { profile = updated; needsLevelCheck = false; });
    } catch (_) {
      // The result was already saved; keep the user in the app even if refresh fails.
      if (mounted) setState(() => needsLevelCheck = false);
    }
  }

  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (profile == null && !welcomeSeen) return WelcomeScreen(onContinue: () async { await api.markWelcomeSeen(); if (mounted) setState(() => welcomeSeen = true); });
    if (profile == null) return AuthScreen(api: api, onSignedIn: _signedIn);
    if (!profile!.profileComplete) return OnboardingScreen(api: api, profile: profile!, onComplete: _onOnboardingComplete);
    if (needsLevelCheck) return LevelCheckScreen(api: api, userId: profile!.userId, focusSkills: profile!.focusSkills, onComplete: _onLevelComplete);
    return HomeScreen(profile: profile);
  }
}

// توافق رجعي مع widget_test.dart القديم في بعض النسخ المحلية.
typedef MyApp = SpeakReplicaApp;
