// مرجع التكامل: Hiwar FastAPI تحت /api/v1؛ إحصائيات الحساب من GET /stats/{user_id}.
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HiwarStats {
  final String userId;
  final String userName;
  final String level;
  final int levelScore;
  final int totalSessions;
  final int streakDays;
  final int totalErrors;
  final double masteryRate;

  const HiwarStats({
    required this.userId,
    required this.userName,
    required this.level,
    required this.levelScore,
    required this.totalSessions,
    required this.streakDays,
    required this.totalErrors,
    required this.masteryRate,
  });

  factory HiwarStats.fromJson(Map<String, dynamic> json) {
    final statistics = (json['statistics'] as Map?)?.cast<String, dynamic>() ?? {};
    return HiwarStats(
      userId: '${json['user_id'] ?? ''}',
      userName: '${json['user_name'] ?? 'معلوماتي في Hiwar'}',
      level: '${json['level'] ?? 'intermediate'}',
      levelScore: (json['level_score'] as num?)?.toInt() ?? 0,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      totalErrors: (statistics['total_errors'] as num?)?.toInt() ?? 0,
      masteryRate: (statistics['mastery_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HiwarApi {
  HiwarApi()
      : _dio = Dio(BaseOptions(
          baseUrl: (dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000').replaceFirst(RegExp(r'/$'), ''),
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Content-Type': 'application/json'},
        ));

  final Dio _dio;

  String get baseUrl => _dio.options.baseUrl;

  Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString('hiwar_user_id');
    if (userId == null || userId.trim().isEmpty) {
      userId = 'flutter-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      await prefs.setString('hiwar_user_id', userId);
    }
    return userId;
  }

  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hiwar_user_id', userId.trim());
  }

  Future<HiwarStats> getStats(String userId) async {
    try {
      final response = await _dio.get('/api/v1/stats/${Uri.encodeComponent(userId)}');
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['error'] != null) throw Exception('${data['error']}');
      return HiwarStats.fromJson(data);
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      if (code == 404) throw Exception('لم يتم العثور على هذا المستخدم في قاعدة البيانات.');
      throw Exception('تعذر الاتصال بالـ Backend. تأكدي من تشغيل Hiwar وإعداد API_BASE_URL.');
    }
  }
}
