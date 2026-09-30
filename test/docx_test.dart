import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:resumer_app/models/models.dart';
import 'package:resumer_app/services/resume_docx_service.dart';
import 'package:resumer_app/services/resume_export_service.dart';
import 'package:resumer_app/services/resume_parser_service.dart';
import 'fixtures.dart' as fixtures;

void main() {
  group('ResumeDocxService', () {
    test('builds a valid OpenXML Word (.docx) document for a resume', () async {
      final state = fixtures.fixtureState();
      final resume = state.resumes.first;
      const service = ResumeDocxService();

      final bytes = await service.build(state: state, resume: resume);

      expect(bytes.length, greaterThan(1000));

      // Check ZIP magic header: PK\x03\x04
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
      expect(bytes[2], 0x03);
      expect(bytes[3], 0x04);

      // Verify internal OpenXML parts
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile('[Content_Types].xml'), isNotNull);
      expect(archive.findFile('_rels/.rels'), isNotNull);
      expect(archive.findFile('word/document.xml'), isNotNull);
      expect(archive.findFile('word/styles.xml'), isNotNull);
      expect(archive.findFile('word/settings.xml'), isNotNull);

      // Verify that ResumeParserService can parse text back from the generated docx
      const parser = ResumeParserService();
      final extracted = parser.extractTextFromDocx(bytes);

      expect(extracted, contains('PRIYA SHARMA'));
      expect(extracted.toLowerCase(), contains('aspiring product engineer'));
      expect(extracted, contains('EXPERIENCE'));
      expect(extracted, contains('EDUCATION'));
      expect(extracted, contains('SKILLS & EXPERTISE'));
    });

    test('generates expected filename with .docx extension', () {
      const service = ResumeDocxService();
      final resume = Resume(
        id: 'res-1',
        name: 'Senior Frontend Resume / 2026',
        type: ResumeType.master,
        status: ResumeStatus.ready,
        updatedAt: DateTime(2026, 1, 1),
        versions: const [],
      );

      final fileName = service.fileNameFor(resume);
      expect(fileName, 'Senior-Frontend-Resume-2026.docx');
    });
  });

  group('ResumeExportFormat', () {
    test('provides correct metadata for PDF and DOCX formats', () {
      expect(ResumeExportFormat.pdf.extension, '.pdf');
      expect(ResumeExportFormat.docx.extension, '.docx');

      expect(ResumeExportFormat.pdf.label, contains('.pdf'));
      expect(ResumeExportFormat.docx.label, contains('.docx'));

      expect(ResumeExportFormat.pdf.icon, Icons.picture_as_pdf_rounded);
      expect(ResumeExportFormat.docx.icon, Icons.description_rounded);
    });
  });

  group('ResumeExportService UI interaction', () {
    testWidgets('displays bottom sheet with PDF and DOCX options',
        (tester) async {
      final state = fixtures.fixtureState();
      final resume = state.resumes.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  const ResumeExportService().promptAndExport(
                    context,
                    state: state,
                    resume: resume,
                  );
                },
                child: const Text('Export Button'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Export Button'));
      await tester.pumpAndSettle();

      // Check modal bottom sheet content
      expect(find.text('Export resume'), findsOneWidget);
      expect(
          find.text('Choose your preferred export format for “${resume.name}”'),
          findsOneWidget);
      expect(find.text('PDF Document (.pdf)'), findsOneWidget);
      expect(find.text('Word Document (.docx)'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Editable'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
