import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:resumer_app/services/resume_parser_service.dart';

void main() {
  group('ResumeParserService', () {
    const parser = ResumeParserService();

    const sampleResume = '''
Alex Morgan
San Francisco, CA | +1 (555) 234-5678 | alex.morgan@example.com
https://github.com/alexmorgan

PROFESSIONAL SUMMARY
Senior Full Stack Engineer with 4+ years of experience in Flutter, React, and Python backend services.

EDUCATION
Bachelor of Science in Computer Science
Stanford University
2019 — 2023

EXPERIENCE
Full Stack Developer | Acme Innovations
Jun 2023 — Present
• Engineered high-performance mobile UI in Flutter and optimized state management.
• Built RESTful APIs using Python FastAPI and PostgreSQL, serving 50k+ daily active users.
• Automated CI/CD deployment workflows with Docker and GitHub Actions.

SKILLS
Flutter, Dart, React, Python, PostgreSQL, Docker, Git, REST API, TypeScript
''';

    test('parses plain text resume correctly', () {
      final result = parser.parseText(sampleResume);

      expect(result.name, equals('Alex Morgan'));
      expect(result.email, equals('alex.morgan@example.com'));
      expect(result.phone, contains('555'));
      expect(result.location, contains('San Francisco'));
      expect(result.headline, contains('Full Stack Engineer'));
      expect(result.degree, contains('Bachelor of Science'));
      expect(result.school, contains('Stanford University'));
      expect(result.graduation, contains('2019'));
      expect(result.role, contains('Full Stack Developer'));
      expect(result.company, contains('Acme Innovations'));
      expect(
          result.experience, contains('Engineered high-performance mobile UI'));
      expect(result.skills, contains('Flutter'));
      expect(result.skills, contains('Python'));
      expect(result.skills, contains('Docker'));
    });

    test('parses byte buffer text correctly', () async {
      final bytes = Uint8List.fromList(utf8.encode(sampleResume));
      final result = await parser.parseFileBytes(bytes, 'resume.txt');

      expect(result.name, equals('Alex Morgan'));
      expect(result.email, equals('alex.morgan@example.com'));
      expect(result.skills, isNotEmpty);
    });

    test('keeps a fallback for a malformed PDF content stream', () async {
      const pdf = '''%PDF-1.4
1 0 obj
<< /Length 118 >>
stream
BT
/F1 12 Tf
72 720 Td
(Alex Morgan) Tj
0 -18 Td
(alex@example.com | +1 555 234 5678) Tj
ET
endstream
endobj
trailer
<<>>
%%EOF''';

      final result = await parser.parseFileBytes(
        Uint8List.fromList(utf8.encode(pdf)),
        'resume.pdf',
      );

      expect(result.name, 'Alex Morgan');
      expect(result.email, 'alex@example.com');
      expect(result.phone, contains('555'));
    });

    test('extracts all pages from a generated PDF and parses fields', () async {
      final document = pw.Document();
      document.addPage(
        pw.Page(
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Taylor Jordan'),
              pw.Text('taylor@example.com | +91 98765 43210'),
              pw.Text('EXPERIENCE'),
              pw.Text('Flutter Engineer | Bluebird Labs'),
            ],
          ),
        ),
      );
      document.addPage(
        pw.Page(
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SKILLS'),
              pw.Text('Flutter, Dart, Firebase'),
            ],
          ),
        ),
      );

      final bytes = Uint8List.fromList(await document.save());
      final text = await parser.extractTextFromPdf(bytes);
      final result = await parser.parseFileBytes(bytes, 'generated.pdf');

      expect(text, contains('Taylor'));
      expect(text, contains('Jordan'));
      expect(text, contains('Flutter'));
      expect(text, contains('Firebase'));
      expect(result.email, 'taylor@example.com');
      expect(result.skills, contains('Flutter'));
      expect(result.skills, contains('Firebase'));
    });

    test('extracts and parses DOCX document text', () async {
      final archive = Archive()
        ..addFile(ArchiveFile.string(
          'word/document.xml',
          '''<w:document><w:body>
            <w:p><w:r><w:t>Jamie Lee</w:t></w:r></w:p>
            <w:p><w:r><w:t>Bengaluru, India | jamie@example.com | +91 98765 43210</w:t></w:r></w:p>
            <w:p><w:r><w:t>SUMMARY</w:t></w:r></w:p>
            <w:p><w:r><w:t>Product engineer building mobile apps.</w:t></w:r></w:p>
            <w:p><w:r><w:t>EDUCATION</w:t></w:r></w:p>
            <w:p><w:r><w:t>B.Tech Computer Science</w:t></w:r></w:p>
            <w:p><w:r><w:t>IIIT Bengaluru</w:t></w:r></w:p>
            <w:p><w:r><w:t>2022 — 2026</w:t></w:r></w:p>
            <w:p><w:r><w:t>SKILLS</w:t></w:r></w:p>
            <w:p><w:r><w:t>Flutter, Dart, Firebase</w:t></w:r></w:p>
          </w:body></w:document>''',
        ));
      final bytes = ZipEncoder().encodeBytes(archive);

      final result = await parser.parseFileBytes(bytes, 'resume.docx');

      expect(result.name, 'Jamie Lee');
      expect(result.email, 'jamie@example.com');
      expect(result.location, contains('Bengaluru'));
      expect(result.degree, contains('B.Tech'));
      expect(result.school, contains('IIIT Bengaluru'));
      expect(result.skills, contains('Flutter'));
    });

    test('handles empty text gracefully', () {
      final result = parser.parseText('');
      expect(result.isEmpty, isTrue);
    });
  });
}
