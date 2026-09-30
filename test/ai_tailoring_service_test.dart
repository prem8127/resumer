import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'fixtures.dart' as fixtures;
import 'package:resumer_app/services/ai_tailoring_service.dart';

void main() {
  test('parses grounded structured tailoring output from the secure proxy',
      () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://example.test/tailor');
      final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      expect(requestBody['model'], AiTailoringService.model);
      return http.Response(
        jsonEncode({
          'targetRole': 'Product Engineer Intern',
          'targetCompany': 'Fenix Labs',
          'summary': 'Lead with shipped product work and API evidence.',
          'score': 86,
          'requirements': [
            {
              'skill': 'React',
              'status': 'strong',
              'evidence': 'Supported by exp-1',
            },
          ],
          'suggestions': [
            {
              'skill': 'React',
              'currentBullet':
                  'Built a React analytics dashboard used by the support team daily.',
              'rewrittenBullet':
                  'Built a React analytics dashboard used daily by the support team.',
              'evidenceId': 'exp-1',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AiTailoringService(
      client: client,
      proxyUrl: 'https://example.test/tailor',
    );

    final report = await service.tailor(
      jobDescription: 'We need a React product engineer for Fenix Labs.',
      evidence: fixtures.demoCareerItems(),
    );

    expect(report.generatedByAi, isTrue);
    expect(report.score, 86);
    expect(report.targetRole, 'Product Engineer Intern');
    expect(report.suggestions, hasLength(1));
    service.dispose();
  });

  test('uses the local Python API by default', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://127.0.0.1:8000/v1/tailor');
      final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      expect(requestBody['model'], AiTailoringService.model);

      final result = {
        'targetRole': 'Frontend Developer',
        'targetCompany': 'Northstar',
        'summary': 'Focus on frontend delivery.',
        'score': 80,
        'requirements': [
          {
            'skill': 'React',
            'status': 'strong',
            'evidence': 'Supported by exp-1',
          },
        ],
        'suggestions': <Object>[],
      };
      return http.Response(
        jsonEncode(result),
        200,
      );
    });
    final service = AiTailoringService(client: client);

    final report = await service.tailor(
      jobDescription: 'Northstar needs a React frontend developer.',
      evidence: fixtures.demoCareerItems(),
    );

    expect(report.targetCompany, 'Northstar');
    expect(report.generatedByAi, isTrue);
    service.dispose();
  });
}
