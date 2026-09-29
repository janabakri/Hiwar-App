import 'package:flutter_test/flutter_test.dart';

import 'package:speak_replica/services/hiwar_api.dart';

void main() {
  group('HiwarChatResult.fromJson', () {
    test('parses a full /chat response', () {
      final result = HiwarChatResult.fromJson({
        'reply': 'Nice! What did you buy?',
        'corrections': [
          {'wrong': 'goed', 'correct': 'went', 'explanation': 'Past of go.'}
        ],
        'tips': ['Irregular verbs change in the past.'],
        'conversation_id': 3,
        'message_id': 12,
        'analysis_completed': true,
      });
      expect(result.reply, 'Nice! What did you buy?');
      expect(result.corrections.single['wrong'], 'goed');
      expect(result.corrections.single['correct'], 'went');
      expect(result.tips, hasLength(1));
      expect(result.conversationId, 3);
      expect(result.messageId, 12);
      expect(result.analysisCompleted, isTrue);
    });

    test('treats a missing analysis flag as not completed', () {
      final result = HiwarChatResult.fromJson({'reply': 'Hi'});
      expect(result.corrections, isEmpty);
      expect(result.tips, isEmpty);
      expect(result.analysisCompleted, isFalse);
    });
  });

  test('HiwarError.fromJson reads the repeat count', () {
    final error = HiwarError.fromJson(
        {'id': 1, 'wrong': 'goed', 'correct': 'went', 'count': 2});
    expect(error.count, 2);
    expect(error.errorType, 'general');
  });

  test('HiwarProfile.fromJson defaults an unassessed level to pending', () {
    final profile = HiwarProfile.fromJson({'user_id': 'u1', 'name': 'Jana'});
    expect(profile.level, 'pending');
    expect(profile.levelScore, 0);
    expect(profile.profileComplete, isFalse);
  });

  test('HiwarApi.isValidEmail rejects placeholder domains', () {
    expect(HiwarApi.isValidEmail('learner@gmail.com'), isTrue);
    expect(HiwarApi.isValidEmail('you@example.com'), isFalse);
    expect(HiwarApi.isValidEmail('not-an-email'), isFalse);
  });
}
