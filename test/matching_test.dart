import 'package:flutter_test/flutter_test.dart';
import 'package:resumer_app/data/matching.dart';
import 'package:resumer_app/models/models.dart';

void main() {
  test('extracts varied requirements and reports grounded partial/missing evidence', () {
    final report = buildMatchReport(
      jobDescription: '''
        Senior Data Analyst
        Required: 5 years experience with Python and SQL.
        Bachelor's degree in statistics or related field.
        Hybrid position based in Bengaluru.
        Full-time role.
      ''',
      evidence: const [
        CareerItem(
          id: 'exp-1',
          type: CareerItemType.experience,
          title: 'Data Analyst',
          dateRange: '2022 - 2025',
          bullets: ['Built Python analytics pipelines and SQL dashboards.'],
        ),
        CareerItem(
          id: 'edu-1',
          type: CareerItemType.education,
          title: 'Bachelor of Statistics',
          subtitle: 'Bengaluru',
        ),
      ],
    );

    expect(report.requirements, isNotEmpty);
    expect(report.requirements.any((item) => item.status == 'strong'), isTrue);
    expect(report.requirements.any((item) => item.status == 'missing'), isTrue);
    expect(report.score, inInclusiveRange(0, 100));
  });

  test('does not fabricate a positive fallback for empty job descriptions', () {
    final report = buildMatchReport(jobDescription: '', evidence: const []);

    expect(report.requirements, isEmpty);
    expect(report.score, 0);
  });
}
