// مرجع التكامل: Hiwar FastAPI تحت /api/v1؛ إحصائيات الحساب من GET /stats/{user_id}.
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
      level: '${json['level'] ?? 'pending'}',
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
  final int? dailyMinutes;
  final String? focusSkills;
  final bool profileComplete;
  final String level;
  final int levelScore;
  final DateTime? createdAt;

  const HiwarProfile({required this.userId, required this.name, this.email, this.age, this.educationLevel, this.certificates, this.learningReason, this.dailyMinutes, this.focusSkills, required this.profileComplete, required this.level, required this.levelScore, this.createdAt});

  int get daysSinceJoined {
    if (createdAt == null) return 0;
    final days = DateTime.now().difference(createdAt!).inDays;
    return days < 0 ? 0 : days;
  }

  factory HiwarProfile.fromJson(Map<String, dynamic> json) => HiwarProfile(
    userId: '${json['user_id'] ?? ''}',
    name: '${json['name'] ?? json['user_name'] ?? ''}',
    email: json['email'] as String?,
    age: (json['age'] as num?)?.toInt(),
    educationLevel: json['education_level'] as String?,
    certificates: json['certificates'] as String?,
    learningReason: json['learning_reason'] as String?,
    dailyMinutes: (json['daily_minutes'] as num?)?.toInt(),
    focusSkills: json['focus_skills'] as String?,
    profileComplete: json['profile_complete'] == true,
    level: '${json['level'] ?? 'pending'}',
    levelScore: (json['level_score'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
  );
}

class HiwarError {
  final int? id;
  final String wrong;
  final String correct;
  final String explanation;
  final String errorType;
  final int count;
  final DateTime? lastOccurrence;
  const HiwarError({this.id, required this.wrong, required this.correct, required this.explanation, required this.errorType, required this.count, this.lastOccurrence});
  factory HiwarError.fromJson(Map<String, dynamic> json) => HiwarError(
    id: (json['id'] as num?)?.toInt(),
    wrong: '${json['wrong'] ?? json['wrong_text'] ?? ''}',
    correct: '${json['correct'] ?? json['correct_text'] ?? ''}',
    explanation: '${json['explanation'] ?? ''}',
    errorType: '${json['error_type'] ?? 'general'}',
    count: (json['count'] as num?)?.toInt() ?? 1,
    lastOccurrence: DateTime.tryParse('${json['last_occurrence'] ?? ''}'),
  );
}

class HiwarJournalResult {
  final int id;
  final String originalText;
  final String correctedText;
  final String followUpQuestion;
  final List<Map<String, String>> corrections;

  const HiwarJournalResult({required this.id, required this.originalText, required this.correctedText, required this.followUpQuestion, required this.corrections});

  factory HiwarJournalResult.fromJson(Map<String, dynamic> json) => HiwarJournalResult(
    id: (json['id'] as num?)?.toInt() ?? 0,
    originalText: '${json['original_text'] ?? ''}',
    correctedText: '${json['corrected_text'] ?? ''}',
    followUpQuestion: '${json['follow_up_question'] ?? ''}',
    corrections: ((json['corrections'] as List?) ?? const []).whereType<Map>().map((item) => <String, String>{
      'wrong': '${item['wrong'] ?? ''}',
      'correct': '${item['correct'] ?? ''}',
      'explanation': '${item['explanation'] ?? ''}',
    }).toList(),
  );
}

class HiwarChatResult {
  final String reply;
  final List<Map<String, String>> corrections;
  final List<String> tips;
  final int? conversationId;
  final int? messageId;
  final bool analysisCompleted;
  final String? analysisMessage;

  const HiwarChatResult({required this.reply, required this.corrections, required this.tips, this.conversationId, this.messageId, this.analysisCompleted = false, this.analysisMessage});

  factory HiwarChatResult.fromJson(Map<String, dynamic> json) {
    final rawCorrections = (json['corrections'] as List?) ?? const [];
    return HiwarChatResult(
      reply: '${json['reply'] ?? ''}',
      corrections: rawCorrections.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return <String, String>{
          'wrong': '${map['wrong'] ?? ''}',
          'correct': '${map['correct'] ?? ''}',
          'explanation': '${map['explanation'] ?? ''}',
        };
      }).toList(),
      tips: ((json['tips'] as List?) ?? const []).map((tip) => '$tip').toList(),
      conversationId: (json['conversation_id'] as num?)?.toInt(),
      messageId: (json['message_id'] as num?)?.toInt(),
      analysisCompleted: json['analysis_completed'] == true,
      analysisMessage: json['analysis_message']?.toString(),
    );
  }
}

class HiwarApi {
  HiwarApi()
      : _dio = Dio(BaseOptions(
          baseUrl: _apiBaseUrl().replaceFirst(RegExp(r'/$'), ''),
          connectTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 45),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final path = options.path;
      if (!path.contains('/auth/')) {
        final token = await getAccessToken();
        if (token != null && token.isNotEmpty) options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    }));
  }

  final Dio _dio;
  static const _secureStorage = FlutterSecureStorage();

  static String _apiBaseUrl() {
    final configured = dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
    if (configured != null && configured.trim().isNotEmpty) return configured.trim();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  String get baseUrl => _dio.options.baseUrl;

  Future<HiwarProfile> passwordSignIn({required String email, required String password}) async {
    final response = await _dio.post('/api/v1/auth/password-sign-in', data: {'email': email, 'password': password});
    final data = Map<String, dynamic>.from(response.data as Map);
    final token = data['access_token']?.toString();
    if (token != null && token.isNotEmpty) await saveAccessToken(token);
    return HiwarProfile.fromJson(data);
  }

  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: 'hiwar_access_token', value: token);
  }

  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: 'hiwar_access_token');
  }

  Future<void> signOut() async {
    await _secureStorage.delete(key: 'hiwar_access_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hiwar_user_id');
  }

  /// Permanently deletes the authenticated account on the server.
  /// Local credentials are cleared only after Dio receives a successful response.
  Future<void> deleteAccount() async {
    await _dio.delete('/api/v1/account');
    await signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hiwar_voice_timeline');
    await prefs.remove('hiwar_voice_preference');
  }

  Future<void> saveVoiceTimelineEntry({required String text, required int durationSeconds}) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList('hiwar_voice_timeline') ?? <String>[];
    final stamp = DateTime.now().toIso8601String();
    entries.add('$stamp|$durationSeconds|${text.replaceAll('|', ' ')}');
    await prefs.setStringList('hiwar_voice_timeline', entries.take(20).toList());
  }

  Future<List<Map<String, String>>> getVoiceTimeline() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('hiwar_voice_timeline') ?? const <String>[]).map((entry) {
      final parts = entry.split('|');
      return <String, String>{
        'date': parts.isNotEmpty ? parts[0] : '',
        'duration': parts.length > 1 ? parts[1] : '0',
        'text': parts.length > 2 ? parts.sublist(2).join('|') : '',
      };
    }).where((entry) => (entry['text'] ?? '').trim().isNotEmpty).toList().reversed.toList();
  }

  Future<String> getVoicePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('hiwar_voice_preference') ?? 'female';
  }

  Future<void> saveVoicePreference(String preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hiwar_voice_preference', preference);
  }

  Future<Map<String, dynamic>> signUp({required String name, required String email, required String password}) async {
    final response = await _dio.post('/api/v1/auth/sign-up', data: {'name': name, 'email': email, 'password': password});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<HiwarProfile> verifyEmail({required String email, required String code}) async {
    final response = await _dio.post('/api/v1/auth/verify-email', data: {'email': email, 'code': code});
    final data = Map<String, dynamic>.from(response.data as Map);
    final token = data['access_token']?.toString();
    if (token != null && token.isNotEmpty) await saveAccessToken(token);
    return HiwarProfile.fromJson(data);
  }

  Future<HiwarProfile> signIn({required String userId, required String name, String? email, String provider = 'manual', String? subject, String? idToken}) async {
    final response = await _dio.post('/api/v1/auth/sign-in', data: {'user_id': userId, 'name': name, 'email': email, 'auth_provider': provider, 'auth_subject': subject, 'id_token': idToken});
    final data = Map<String, dynamic>.from(response.data as Map);
    final token = data['access_token']?.toString();
    if (token != null && token.isNotEmpty) await saveAccessToken(token);
    return HiwarProfile.fromJson(data);
  }

  Future<Map<String, dynamic>> assessReading({required String userId, required String passage, required String answer}) async {
    final response = await _dio.post('/api/v1/assessment/reading', data: {'user_id': userId, 'passage': passage, 'answer': answer});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> assessSpeaking({required String userId, required String prompt, required String transcript}) async {
    final response = await _dio.post('/api/v1/assessment/speaking', data: {'user_id': userId, 'prompt': prompt, 'transcript': transcript});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> saveLevelResult({required String userId, required String level, required int score}) async {
    await _dio.post('/api/v1/assessment/level', data: {'user_id': userId, 'level': level, 'score': score});
  }

  Future<List<HiwarError>> getErrors(String userId) async {
    final response = await _dio.get('/api/v1/errors/${Uri.encodeComponent(userId)}');
    final data = Map<String, dynamic>.from(response.data as Map);
    return ((data['errors'] as List?) ?? const []).map((item) => HiwarError.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<HiwarChatResult> sendChat({required String userId, required String message, int? conversationId, String? tutorInstruction}) async {
    final response = await _dio.post('/api/v1/chat', data: {
      'message': message,
      'user_id': userId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (tutorInstruction != null && tutorInstruction.trim().isNotEmpty) 'tutor_instruction': tutorInstruction.trim(),
    });
    return HiwarChatResult.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<HiwarJournalResult> analyzeJournal({required String userId, required String text}) async {
    final response = await _dio.post('/api/v1/journal/analyze', data: {'user_id': userId, 'text': text});
    return HiwarJournalResult.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<Map<String, dynamic>>> getJournal(String userId) async {
    final response = await _dio.get('/api/v1/journal/${Uri.encodeComponent(userId)}');
    final data = Map<String, dynamic>.from(response.data as Map);
    return ((data['entries'] as List?) ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<HiwarProfile> getProfile(String userId) async {
    final response = await _dio.get('/api/v1/profile/${Uri.encodeComponent(userId)}');
    return HiwarProfile.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<HiwarProfile> updateProfile({required String userId, required String name, int? age, String? educationLevel, String? certificates, String? learningReason, int? dailyMinutes, String? focusSkills}) async {
    final response = await _dio.put('/api/v1/profile', data: {'user_id': userId, 'name': name, 'age': age, 'education_level': educationLevel, 'certificates': certificates, 'learning_reason': learningReason, 'daily_minutes': dailyMinutes, 'focus_skills': focusSkills});
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

  static const _welcomeVersion = 2;

  Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hiwar_welcome_seen') == true && prefs.getInt('hiwar_welcome_version') == _welcomeVersion;
  }

  Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hiwar_welcome_seen', true);
    await prefs.setInt('hiwar_welcome_version', _welcomeVersion);
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
