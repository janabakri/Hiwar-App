import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ErrorCard extends StatelessWidget {
  final String wrong;
  final String correct;
  final String explanation;

  const ErrorCard({
    super.key,
    required this.wrong,
    required this.correct,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                wrong,
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFEF6461),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: const Color(0xFFEF6461).withOpacity(0.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2A93B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'تحتاج مراجعة',
                  style: GoogleFonts.tajawal(
                    fontSize: 10,
                    color: const Color(0xFFF2A93B),
                  ),
                ),
              ),
            ],
          ),
          Text(
            correct,
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2DD4BF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: GoogleFonts.tajawal(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
