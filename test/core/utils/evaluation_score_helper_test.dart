import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/core/utils/evaluation_score_helper.dart';

void main() {
  group('EvaluationScoreHelper.calculateScore', () {
    test('three options: first=100, middle=50, last=0', () {
      final options = ['优秀', '良好', '一般'];
      expect(EvaluationScoreHelper.calculateScore(options, 0), 100);
      expect(EvaluationScoreHelper.calculateScore(options, 1), 50);
      expect(EvaluationScoreHelper.calculateScore(options, 2), 0);
    });

    test('two options: first=100, last=0', () {
      final options = ['Good', 'Bad'];
      expect(EvaluationScoreHelper.calculateScore(options, 0), 100);
      expect(EvaluationScoreHelper.calculateScore(options, 1), 0);
    });

    test('four options: linear distribution', () {
      final options = ['A', 'B', 'C', 'D'];
      // scores: 100, 66, 33, 0  (integer division)
      expect(EvaluationScoreHelper.calculateScore(options, 0), 100);
      expect(EvaluationScoreHelper.calculateScore(options, 1), 66);
      expect(EvaluationScoreHelper.calculateScore(options, 2), 33);
      expect(EvaluationScoreHelper.calculateScore(options, 3), 0);
    });

    test('five options: linear distribution', () {
      final options = ['A', 'B', 'C', 'D', 'E'];
      expect(EvaluationScoreHelper.calculateScore(options, 0), 100);
      expect(EvaluationScoreHelper.calculateScore(options, 1), 75);
      expect(EvaluationScoreHelper.calculateScore(options, 2), 50);
      expect(EvaluationScoreHelper.calculateScore(options, 3), 25);
      expect(EvaluationScoreHelper.calculateScore(options, 4), 0);
    });

    test('single option returns 100', () {
      expect(EvaluationScoreHelper.calculateScore(['Only'], 0), 100);
    });

    test('empty list returns 0', () {
      expect(EvaluationScoreHelper.calculateScore([], 0), 0);
    });

    test('negative index returns 0', () {
      expect(EvaluationScoreHelper.calculateScore(['A', 'B'], -1), 0);
    });

    test('index out of bounds returns 0', () {
      expect(EvaluationScoreHelper.calculateScore(['A', 'B'], 2), 0);
      expect(EvaluationScoreHelper.calculateScore(['A', 'B'], 99), 0);
    });
  });

  group('EvaluationScoreHelper.calculateScoreByValue', () {
    test('returns correct score for known value', () {
      final options = ['优秀', '良好', '一般'];
      expect(EvaluationScoreHelper.calculateScoreByValue(options, '优秀'), 100);
      expect(EvaluationScoreHelper.calculateScoreByValue(options, '良好'), 50);
      expect(EvaluationScoreHelper.calculateScoreByValue(options, '一般'), 0);
    });

    test('returns 0 for unknown value', () {
      final options = ['A', 'B', 'C'];
      expect(EvaluationScoreHelper.calculateScoreByValue(options, 'Z'), 0);
    });

    test('returns 0 for empty options list', () {
      expect(EvaluationScoreHelper.calculateScoreByValue([], 'A'), 0);
    });
  });

  group('EvaluationScoreHelper.getOptionsWithScores', () {
    test('returns all options mapped to correct scores', () {
      final options = ['优秀', '良好', '一般'];
      final result = EvaluationScoreHelper.getOptionsWithScores(options);
      expect(result, equals({'优秀': 100, '良好': 50, '一般': 0}));
    });

    test('returns empty map for empty list', () {
      final result = EvaluationScoreHelper.getOptionsWithScores([]);
      expect(result, isEmpty);
    });

    test('single option maps to 100', () {
      final result = EvaluationScoreHelper.getOptionsWithScores(['Only']);
      expect(result, equals({'Only': 100}));
    });

    test('two options maps correctly', () {
      final result = EvaluationScoreHelper.getOptionsWithScores(['Good', 'Bad']);
      expect(result, equals({'Good': 100, 'Bad': 0}));
    });
  });
}
