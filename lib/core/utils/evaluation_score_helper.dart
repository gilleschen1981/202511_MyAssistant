/// Helper class for calculating evaluation scores
///
/// The scoring logic is based on the order of evaluation options:
/// - First option (index 0) = 100 points
/// - Last option (index n-1) = 0 points
/// - Middle options are linearly distributed
///
/// Example: ["优秀", "良好", "一般"]
/// - "优秀" (index 0) = 100
/// - "良好" (index 1) = 50
/// - "一般" (index 2) = 0
class EvaluationScoreHelper {
  /// Calculate the score for an evaluation option based on its index
  ///
  /// [evaluationOptions] - The list of evaluation options
  /// [index] - The index of the option in the list
  ///
  /// Returns a score between 0 and 100
  static int calculateScore(List<String> evaluationOptions, int index) {
    if (evaluationOptions.isEmpty) return 0;
    if (evaluationOptions.length == 1) return 100;
    if (index < 0 || index >= evaluationOptions.length) return 0;

    // Linear distribution: first = 100, last = 0
    final totalOptions = evaluationOptions.length;
    final score = 100 * (totalOptions - 1 - index) ~/ (totalOptions - 1);
    return score;
  }

  /// Calculate the score for an evaluation option by its value
  ///
  /// [evaluationOptions] - The list of evaluation options
  /// [optionValue] - The value of the option
  ///
  /// Returns a score between 0 and 100, or 0 if not found
  static int calculateScoreByValue(
    List<String> evaluationOptions,
    String optionValue,
  ) {
    final index = evaluationOptions.indexOf(optionValue);
    if (index == -1) return 0;
    return calculateScore(evaluationOptions, index);
  }

  /// Get all options with their scores
  ///
  /// [evaluationOptions] - The list of evaluation options
  ///
  /// Returns a map of option to score
  static Map<String, int> getOptionsWithScores(List<String> evaluationOptions) {
    final result = <String, int>{};
    for (var i = 0; i < evaluationOptions.length; i++) {
      result[evaluationOptions[i]] = calculateScore(evaluationOptions, i);
    }
    return result;
  }
}