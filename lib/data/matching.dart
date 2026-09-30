import '../models/models.dart';

class Requirement {
  const Requirement({
    required this.skill,
    required this.status,
    required this.evidence,
  });

  final String skill;
  final String status;
  final String evidence;
}

class MatchReport {
  const MatchReport({
    required this.requirements,
    required this.score,
    required this.backedCount,
    required this.totalCount,
    this.suggestions = const [],
    this.summary = '',
    this.targetRole = 'Tailored role',
    this.targetCompany = 'Target company',
    this.generatedByAi = false,
  });

  final List<Requirement> requirements;
  final int score;
  final int backedCount;
  final int totalCount;
  final List<TailoringSuggestion> suggestions;
  final String summary;
  final String targetRole;
  final String targetCompany;
  final bool generatedByAi;
}

class TailoringSuggestion {
  const TailoringSuggestion({
    required this.skill,
    required this.currentBullet,
    required this.rewrittenBullet,
    required this.evidenceId,
  });

  final String skill;
  final String currentBullet;
  final String rewrittenBullet;
  final String evidenceId;
}

final RegExp _wordPattern = RegExp(r"[a-z0-9+#.]{2,}", caseSensitive: false);
final Set<String> _stopWords = {
  'and',
  'are',
  'with',
  'for',
  'the',
  'you',
  'your',
  'our',
  'from',
  'that',
  'this',
  'will',
  'have',
  'has',
  'years',
  'year',
  'work',
  'role',
  'team',
  'ability',
  'experience',
  'strong',
  'excellent',
  'required',
  'preferred',
  'including',
  'such',
  'other',
  'related',
  'degree',
  'equivalent',
  'must',
  'plus',
  'good',
  'knowledge',
  'skills',
  'working',
  'using',
  'into',
  'across',
};

Set<String> _tokens(String text) => _wordPattern
    .allMatches(text.toLowerCase())
    .map((match) => match.group(0)!)
    .where((word) => !_stopWords.contains(word))
    .toSet();

List<String> _extractRequirements(String description) {
  final clauses = description
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .split(RegExp(r'[\n\r.;|]+'))
      .map((part) => part.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((part) => part.length >= 12)
      .toList();
  final selected = clauses.where((clause) {
    final text = clause.toLowerCase();
    final qualification = RegExp(
      r'\b(require|qualif|experience|proficien|knowledge|skill|degree|bachelor|master|senior|staff|location|remote|hybrid|onsite|full.?time|part.?time|contract|intern|education|certif|must have|nice to have)\w*\b',
    ).hasMatch(text);
    return qualification && _tokens(clause).length >= 1;
  }).toList();
  if (selected.isNotEmpty) return selected.take(30).toList();
  return clauses
      .where((clause) => _tokens(clause).length >= 3)
      .take(20)
      .toList();
}

/// Compares extracted job requirements with the candidate's recorded evidence.
/// This deliberately reports missing evidence instead of assuming a match.
MatchReport buildMatchReport({
  required String jobDescription,
  required List<CareerItem> evidence,
}) {
  final candidateText = evidence
      .expand((item) => [
            item.type.label,
            item.title,
            item.subtitle ?? '',
            item.dateRange ?? '',
            ...item.bullets,
          ])
      .join(' ');
  final candidateTokens = _tokens(candidateText);
  final requirements = _extractRequirements(jobDescription);
  final report = <Requirement>[];
  var scoreTotal = 0.0;
  var strongCount = 0;

  for (final clause in requirements) {
    final requiredTokens = _tokens(clause);
    if (requiredTokens.isEmpty) continue;
    final overlap = requiredTokens.intersection(candidateTokens);
    final score = overlap.length / requiredTokens.length;
    final status = score >= .65
        ? 'strong'
        : score >= .25
            ? 'partial'
            : 'missing';
    if (status == 'strong') strongCount++;
    scoreTotal += score.clamp(0, 1);
    report.add(Requirement(
      skill: clause,
      status: status,
      evidence: overlap.isEmpty
          ? 'No supporting evidence found in your career profile'
          : 'Evidence overlaps: ${overlap.take(5).join(', ')}',
    ));
  }

  final score = report.isEmpty ? 0 : (scoreTotal / report.length * 100).round();
  return MatchReport(
    requirements: report,
    score: score,
    backedCount: strongCount,
    totalCount: report.length,
  );
}
