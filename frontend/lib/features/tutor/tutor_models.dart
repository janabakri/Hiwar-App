class TutorFeedback {
  final String type;
  final String code;
  final String wrong;
  final String corrected;
  final String explanationAr;
  final double confidence;

  const TutorFeedback({required this.type, required this.code, required this.wrong, required this.corrected, required this.explanationAr, required this.confidence});

  factory TutorFeedback.fromJson(Map<String, dynamic> json) => TutorFeedback(
        type: '${json['type'] ?? 'general'}',
        code: '${json['code'] ?? ''}',
        wrong: '${json['wrong'] ?? ''}',
        corrected: '${json['corrected'] ?? ''}',
        explanationAr: '${json['explanation_ar'] ?? ''}',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );
}

class SpeakingSessionData {
  final String sessionId;
  final String level;
  final String mode;
  final String topic;
  final String goal;
  final String openingPrompt;

  const SpeakingSessionData({required this.sessionId, required this.level, required this.mode, required this.topic, required this.goal, required this.openingPrompt});

  factory SpeakingSessionData.fromJson(Map<String, dynamic> json) {
    final plan = Map<String, dynamic>.from((json['plan'] as Map?) ?? const {});
    return SpeakingSessionData(
      sessionId: '${json['session_id'] ?? ''}',
      level: '${plan['cefr_level'] ?? 'A1'}',
      mode: '${plan['mode'] ?? 'conversation'}',
      topic: '${plan['topic'] ?? ''}',
      goal: '${plan['goal'] ?? ''}',
      openingPrompt: '${plan['opening_prompt'] ?? ''}',
    );
  }
}

class SpeakingTurnData {
  final String turnId;
  final String reply;
  final String correctedUtterance;
  final String naturalAlternative;
  final List<TutorFeedback> feedback;
  final bool retryRequired;
  final String retryPhrase;
  final String nextAction;

  const SpeakingTurnData({required this.turnId, required this.reply, required this.correctedUtterance, required this.naturalAlternative, required this.feedback, required this.retryRequired, required this.retryPhrase, required this.nextAction});

  factory SpeakingTurnData.fromJson(Map<String, dynamic> json) {
    final analysis = Map<String, dynamic>.from((json['analysis'] as Map?) ?? const {});
    return SpeakingTurnData(
      turnId: '${json['turn_id'] ?? ''}',
      reply: '${analysis['assistant_reply'] ?? ''}',
      correctedUtterance: '${analysis['corrected_utterance'] ?? ''}',
      naturalAlternative: '${analysis['natural_alternative'] ?? ''}',
      feedback: ((analysis['priority_feedback'] as List?) ?? const [])
          .map((item) => TutorFeedback.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      retryRequired: analysis['retry_required'] == true,
      retryPhrase: '${analysis['retry_phrase'] ?? ''}',
      nextAction: '${analysis['next_action'] ?? 'ask_follow_up'}',
    );
  }
}

class SpeakingRetryData {
  final bool successful;
  final int similarityScore;
  final int improvement;
  final String feedbackAr;
  final String nextAction;

  const SpeakingRetryData({required this.successful, required this.similarityScore, required this.improvement, required this.feedbackAr, required this.nextAction});

  factory SpeakingRetryData.fromJson(Map<String, dynamic> json) {
    final analysis = Map<String, dynamic>.from((json['analysis'] as Map?) ?? const {});
    return SpeakingRetryData(
      successful: analysis['successful'] == true,
      similarityScore: (analysis['similarity_score'] as num?)?.toInt() ?? 0,
      improvement: (analysis['improvement'] as num?)?.toInt() ?? 0,
      feedbackAr: '${analysis['feedback_ar'] ?? ''}',
      nextAction: '${analysis['next_action'] ?? 'continue'}',
    );
  }
}

class SpeakingSummaryData {
  final List<String> achievements;
  final String reviewFocus;
  final int evidenceCount;
  final String messageAr;

  const SpeakingSummaryData({required this.achievements, required this.reviewFocus, required this.evidenceCount, required this.messageAr});

  factory SpeakingSummaryData.fromJson(Map<String, dynamic> json) => SpeakingSummaryData(
        achievements: ((json['achievements'] as List?) ?? const []).map((item) => '$item').toList(),
        reviewFocus: '${json['review_focus'] ?? ''}',
        evidenceCount: (json['evidence_count'] as num?)?.toInt() ?? 0,
        messageAr: '${json['message_ar'] ?? ''}',
      );
}

class TargetWordData {
  final String word;
  final String meaningAr;
  final String ipa;
  final String example;

  const TargetWordData({required this.word, required this.meaningAr, required this.ipa, required this.example});

  factory TargetWordData.fromJson(Map<String, dynamic> json) => TargetWordData(
        word: '${json['word'] ?? ''}',
        meaningAr: '${json['meaning_ar'] ?? ''}',
        ipa: '${json['ipa'] ?? ''}',
        example: '${json['example'] ?? ''}',
      );
}

class ReadingQuestionData {
  final String id;
  final String type;
  final String question;
  final List<String> options;

  const ReadingQuestionData({required this.id, required this.type, required this.question, required this.options});

  factory ReadingQuestionData.fromJson(Map<String, dynamic> json) => ReadingQuestionData(
        id: '${json['id'] ?? ''}',
        type: '${json['type'] ?? 'detail'}',
        question: '${json['question'] ?? ''}',
        options: ((json['options'] as List?) ?? const []).map((item) => '$item').toList(),
      );
}

class ReadingSessionData {
  final String sessionId;
  final String materialId;
  final String title;
  final String level;
  final String topic;
  final String passage;
  final List<TargetWordData> targetWords;
  final List<ReadingQuestionData> questions;

  const ReadingSessionData({required this.sessionId, required this.materialId, required this.title, required this.level, required this.topic, required this.passage, required this.targetWords, required this.questions});

  factory ReadingSessionData.fromJson(Map<String, dynamic> json) {
    final lesson = Map<String, dynamic>.from((json['lesson'] as Map?) ?? const {});
    return ReadingSessionData(
      sessionId: '${json['session_id'] ?? ''}',
      materialId: '${json['material_id'] ?? ''}',
      title: '${lesson['title'] ?? ''}',
      level: '${lesson['cefr_level'] ?? 'A1'}',
      topic: '${lesson['topic'] ?? ''}',
      passage: '${lesson['passage'] ?? ''}',
      targetWords: ((lesson['target_words'] as List?) ?? const [])
          .map((item) => TargetWordData.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      questions: ((lesson['questions'] as List?) ?? const [])
          .map((item) => ReadingQuestionData.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

class ReadingAnswerData {
  final bool correct;
  final int score;
  final String feedbackAr;
  final String evidence;
  final String nextAction;

  const ReadingAnswerData({required this.correct, required this.score, required this.feedbackAr, required this.evidence, required this.nextAction});

  factory ReadingAnswerData.fromJson(Map<String, dynamic> json) {
    final analysis = Map<String, dynamic>.from((json['analysis'] as Map?) ?? const {});
    return ReadingAnswerData(
      correct: analysis['correct'] == true,
      score: (analysis['score'] as num?)?.toInt() ?? 0,
      feedbackAr: '${analysis['feedback_ar'] ?? ''}',
      evidence: '${analysis['evidence'] ?? ''}',
      nextAction: '${analysis['next_action'] ?? 'next_question'}',
    );
  }
}

class ReadingSummaryData {
  final int score;
  final int correctAnswers;
  final int totalAnswers;
  final List<String> strengths;
  final String reviewFocus;
  final String messageAr;

  const ReadingSummaryData({required this.score, required this.correctAnswers, required this.totalAnswers, required this.strengths, required this.reviewFocus, required this.messageAr});

  factory ReadingSummaryData.fromJson(Map<String, dynamic> json) => ReadingSummaryData(
        score: (json['score'] as num?)?.toInt() ?? 0,
        correctAnswers: (json['correct_answers'] as num?)?.toInt() ?? 0,
        totalAnswers: (json['total_answers'] as num?)?.toInt() ?? 0,
        strengths: ((json['strengths'] as List?) ?? const []).map((item) => '$item').toList(),
        reviewFocus: '${json['review_focus'] ?? ''}',
        messageAr: '${json['message_ar'] ?? ''}',
      );
}

class TutorProgressMetric {
  final String skill;
  final int? masteryScore;
  final double confidence;
  final int evidenceCount;
  final String trend;

  const TutorProgressMetric({required this.skill, required this.masteryScore, required this.confidence, required this.evidenceCount, required this.trend});

  factory TutorProgressMetric.fromJson(Map<String, dynamic> json) => TutorProgressMetric(
        skill: '${json['skill'] ?? ''}',
        masteryScore: (json['mastery_score'] as num?)?.toInt(),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        evidenceCount: (json['evidence_count'] as num?)?.toInt() ?? 0,
        trend: '${json['trend'] ?? 'insufficient_evidence'}',
      );
}

class TutorProgressData {
  final String level;
  final double levelConfidence;
  final TutorProgressMetric speaking;
  final TutorProgressMetric reading;
  final int dueReviews;
  final int totalSessions;

  const TutorProgressData({required this.level, required this.levelConfidence, required this.speaking, required this.reading, required this.dueReviews, required this.totalSessions});

  factory TutorProgressData.fromJson(Map<String, dynamic> json) => TutorProgressData(
        level: '${json['cefr_level'] ?? 'A1'}',
        levelConfidence: (json['cefr_confidence'] as num?)?.toDouble() ?? 0,
        speaking: TutorProgressMetric.fromJson(Map<String, dynamic>.from((json['speaking'] as Map?) ?? const {})),
        reading: TutorProgressMetric.fromJson(Map<String, dynamic>.from((json['reading'] as Map?) ?? const {})),
        dueReviews: (json['due_reviews'] as num?)?.toInt() ?? 0,
        totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      );
}

class TodayLearningPlanData {
  final String recommendedSkill;
  final String goal;
  final String reasonAr;
  final int dueReviewCount;
  final int suggestedMinutes;

  const TodayLearningPlanData({required this.recommendedSkill, required this.goal, required this.reasonAr, required this.dueReviewCount, required this.suggestedMinutes});

  factory TodayLearningPlanData.fromJson(Map<String, dynamic> json) => TodayLearningPlanData(
        recommendedSkill: '${json['recommended_skill'] ?? 'speaking'}',
        goal: '${json['goal'] ?? ''}',
        reasonAr: '${json['reason_ar'] ?? ''}',
        dueReviewCount: (json['due_review_count'] as num?)?.toInt() ?? 0,
        suggestedMinutes: (json['suggested_minutes'] as num?)?.toInt() ?? 15,
      );
}
