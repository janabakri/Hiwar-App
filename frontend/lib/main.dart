// مرجع التصميم: Speak RTL، خلفية دافئة، بنفسجي رئيسي، IBM Plex Sans Arabic/IBM Plex Sans/IBM Plex Mono.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // يعمل التطبيق بالقيمة الافتراضية داخل HiwarApi عند غياب .env.
  }
  runApp(const SpeakReplicaApp());
}

class SpeakReplicaApp extends StatelessWidget {
  const SpeakReplicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4B3F8F);
    return MaterialApp(
      title: 'Speak Replica',
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
