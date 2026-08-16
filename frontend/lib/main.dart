// مرجع التصميم: Speak RTL، خلفية دافئة، بنفسجي رئيسي، IBM Plex Sans Arabic/IBM Plex Sans/IBM Plex Mono.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const HomeScreen(),
    );
  }
}

// توافق رجعي مع widget_test.dart القديم في بعض النسخ المحلية.
typedef MyApp = SpeakReplicaApp;
