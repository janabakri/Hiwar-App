import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';

void main() async {
  await dotenv.load();
  runApp(const SpeakReplicaApp());
}

class SpeakReplicaApp extends StatelessWidget {
  const SpeakReplicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speak Replica',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.tajawal().fontFamily,
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF2A93B),
          secondary: Color(0xFF2DD4BF),
          surface: Color(0xFF1C1C2E),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
