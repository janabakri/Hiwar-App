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

class HiwarProfile {
  final String userId;
  final String name;
  final String? email;
  final int? age;
  final String? educationLevel;
  final String? certificates;
  final String? learningReason;
  final bool profileComplete;
  final String level;
  final int levelScore;

  const HiwarProfile({required this.userId, required this.name, this.email, this.age, this.educationLevel, this.certificates, this.learningReason, required this.profileComplete, required this.level, required this.levelScore});

  factory HiwarProfile.fromJson(Map<String, dynamic> json) => HiwarProfile(
    userId: '${json['user_id'] ?? ''}',
    name: '${json['name'] ?? json['user_name'] ?? ''}',
    email: json['email'] as String?,
    age: (json['age'] as num?)?.toInt(),
    educationLevel: json['education_level'] as String?,
    certificates: json['certificates'] as String?,
    learningReason: json['learning_reason'] as String?,
    profileComplete: json['profile_complete'] == true,
    level: '${json['level'] ?? 'intermediate'}',
    levelScore: (json['level_score'] as num?)?.toInt() ?? 0,
  );
}

class HiwarApi {
  HiwarApi()
      : _dio = Dio(BaseOptions(
          baseUrl: _apiBaseUrl().replaceFirst(RegExp(r'/$'), ''),
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Content-Type': 'application/json'},
        ));

  final Dio _dio;

  static String _apiBaseUrl() {
    final configured = dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
    return configured == null || configured.trim().isEmpty ? 'http://localhost:8000' : configured.trim();
  }

  String get baseUrl => _dio.options.baseUrl;

  Future<HiwarProfile> signIn({required String userId, required String name, String? email, String provider = 'manual', String? subject}) async {
    final response = await _dio.post('/api/v1/auth/sign-in', data: {'user_id': userId, 'name': name, 'email': email, 'auth_provider': provider, 'auth_subject': subject});
    return HiwarProfile.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<HiwarProfile> getProfile(String userId) async {
    final response = await _dio.get('/api/v1/profile/${Uri.encodeComponent(userId)}');
    return HiwarProfile.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<HiwarProfile> updateProfile({required String userId, required String name, int? age, String? educationLevel, String? certificates, String? learningReason}) async {
    final response = await _dio.put('/api/v1/profile', data: {'user_id': userId, 'name': name, 'age': age, 'education_level': educationLevel, 'certificates': certificates, 'learning_reason': learningReason});
    return HiwarProfile.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('hiwar_user_id');
  }

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
