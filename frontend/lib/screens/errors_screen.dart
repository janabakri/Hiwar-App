import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

class ErrorsScreen extends StatefulWidget {
  const ErrorsScreen({super.key});

  @override
  State<ErrorsScreen> createState() => _ErrorsScreenState();
}

class _ErrorsScreenState extends State<ErrorsScreen> {
  List<Map<String, dynamic>> _errors = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  final Dio _dio = Dio();
  final String _userId = 'sarah_123';

  @override
  void initState() {
    super.initState();
    _fetchErrors();
  }

  Future<void> _fetchErrors() async {
    try {
      final response = await _dio.get(
        'http://localhost:8000/api/v1/errors/$_userId',
      );

      if (response.statusCode == 200) {
        setState(() {
          _errors = List<Map<String, dynamic>>.from(response.data['errors']);
          _stats = response.data['statistics'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: Text(
          'أخطائي وتقدمي',
          style: GoogleFonts.tajawal(),
        ),
        backgroundColor: const Color(0xFF1C1C2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C2E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('${_stats['total'] ?? 0}', 'إجمالي الأخطاء'),
                      _statItem('${_stats['mastered'] ?? 0}', 'تم إتقانها'),
                      _statItem('${_stats['unmastered'] ?? 0}', 'تحتاج مراجعة'),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _errors.length,
                    itemBuilder: (context, index) {
                      final error = _errors[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
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
                                  error['wrong'] ?? '',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFEF6461),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2A93B)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'تكررت ${error['count'] ?? 0} مرات',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 10,
                                      color: const Color(0xFFF2A93B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              error['correct'] ?? '',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF2DD4BF),
                              ),
                            ),
                            if (error['explanation'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                error['explanation'],
                                style: GoogleFonts.tajawal(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.tajawal(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFF2A93B),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 10,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}
