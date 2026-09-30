import 'package:flutter_test/flutter_test.dart';
import 'package:resumer_app/models/models.dart';
import 'package:resumer_app/services/job_apply_service.dart';

JobOpening _job({String? url}) => JobOpening(
      id: 'j1',
      title: 'Flutter Developer',
      companyName: 'Namma Tech',
      location: 'Bengaluru, India',
      workMode: 'On-site',
      employmentType: 'Full-time',
      salaryLabel: 'Competitive salary',
      postedAt: DateTime(2026, 8, 1),
      description: 'Build apps.',
      skills: const ['Flutter'],
      matchScore: 80,
      url: url,
    );

void main() {
  test('resolves the direct posting URL when present', () {
    final uri = JobApplyService().resolveTarget(
      _job(url: 'https://jobs.example.com/apply/123'),
    );
    expect(uri.toString(), 'https://jobs.example.com/apply/123');
  });

  test('fallback searches the company careers site, never LinkedIn', () {
    final uri = JobApplyService().resolveTarget(_job());
    expect(uri.host, isNot(contains('linkedin')));
    expect(uri.queryParameters['q'], contains('Namma Tech'));
    expect(uri.queryParameters['q'], contains('careers'));
  });

  test('ignores malformed URLs and uses the careers fallback', () {
    final uri = JobApplyService().resolveTarget(_job(url: 'not a url'));
    expect(uri.host, isNot(contains('linkedin')));
  });

  test('openJobPosting launches the resolved target', () async {
    Uri? launched;
    final service = JobApplyService(
      launcher: (uri) async {
        launched = uri;
        return true;
      },
    );
    final opened = await service.openJobPosting(
      _job(url: 'https://boards.greenhouse.io/atlassian/jobs/123'),
    );
    expect(opened, isTrue);
    expect(
        launched.toString(), 'https://boards.greenhouse.io/atlassian/jobs/123');
  });
}
