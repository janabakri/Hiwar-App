import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2140), Color(0xFF1C1C2E)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        color: Color(0xFF2DD4BF),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '62%',
                        style: GoogleFonts.tajawal(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFF2A93B),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'التقدم',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'B1 — متوسط',
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'أقرب مستوى: B2 · Upper Intermediate',
                    style: GoogleFonts.tajawal(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  Text(
                    'XP 480 / 780',
                    style: GoogleFonts.tajawal(
                      fontSize: 10,
                      color: const Color(0xFFF2A93B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: 0.62,
            backgroundColor: Colors.grey.shade800,
            color: const Color(0xFFF2A93B),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
