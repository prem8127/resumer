import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/app_state.dart';
import '../models/models.dart';

/// Generates a real, ATS-friendly PDF for a resume and hands it off to the
/// platform's share/save sheet (web triggers a download).
class ResumePdfService {
  const ResumePdfService();

  static const PdfColor _ink = PdfColor.fromInt(0xFF1D1F1B);
  static const PdfColor _sage = PdfColor.fromInt(0xFF4F6B58);
  static const PdfColor _stone = PdfColor.fromInt(0xFF5F635B);
  static const PdfColor _line = PdfColor.fromInt(0xFFDCDFD8);

  Future<Uint8List> build({
    required AppState state,
    required Resume resume,
  }) async {
    final user = state.user;
    final experience = state.careerItems
        .where((item) => item.type == CareerItemType.experience)
        .toList();
    final projects = state.careerItems
        .where((item) => item.type == CareerItemType.project)
        .toList();
    final education = state.careerItems
        .where((item) => item.type == CareerItemType.education)
        .toList();
    final skills = state.careerItems
        .where((item) => item.type == CareerItemType.skill)
        .map((item) => _clean(item.title))
        .where((title) => title.isNotEmpty)
        .toList();
    final courses = state.careerItems
        .where((item) => item.type == CareerItemType.course)
        .toList();

    final headline = _clean(user.headline);
    final displayName = user.name.trim().isEmpty
        ? 'YOUR NAME'
        : _clean(user.name.trim()).toUpperCase();
    final contactParts = [user.email, user.phone, user.location]
        .map((s) => _clean(s.trim()))
        .where((s) => s.isNotEmpty)
        .toList();

    final hasTargetRole =
        resume.targetRole != null && resume.targetRole!.trim().isNotEmpty;

    final document = pw.Document(
      title: '${_clean(resume.name)} - Resumer',
      author: displayName,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 38),
        build: (context) => [
          // 1. Candidate Name
          pw.Center(
            child: pw.Text(
              displayName,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.3,
                color: _ink,
              ),
            ),
          ),
          if (headline.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                headline,
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.4,
                  color: _sage,
                ),
              ),
            ),
          ],
          if (contactParts.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                contactParts.join('   |   '),
                style: const pw.TextStyle(fontSize: 8.5, color: _stone),
              ),
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Divider(height: 1, thickness: 0.8, color: _line),

          // 2. Professional Summary
          if (hasTargetRole || headline.isNotEmpty) ...[
            _section('PROFESSIONAL SUMMARY', [
              pw.Text(
                hasTargetRole
                    ? (headline.isNotEmpty
                        ? '$headline with targeted focus toward ${_clean(resume.targetRole!)}${resume.targetCompany == null ? '' : ' at ${_clean(resume.targetCompany!)}'}. Proven background delivering dependable, high-impact results with cross-functional technical rigor.'
                        : 'Targeted for ${_clean(resume.targetRole!)}${resume.targetCompany == null ? '' : ' at ${_clean(resume.targetCompany!)}'}. Proven background delivering dependable, high-impact results with cross-functional technical rigor.')
                    : '$headline with demonstrated expertise in delivering high-quality engineering and product solutions. Committed to technical excellence, continuous learning, and driving scalable impact.',
                style: const pw.TextStyle(fontSize: 9.5, height: 1.45),
              ),
            ]),
          ],

          // 3. Targeted Highlights
          if (resume.tailoredBullets.isNotEmpty)
            _section('TARGETED HIGHLIGHTS', [
              for (final bullet in resume.tailoredBullets)
                _bulletRow(_clean(bullet)),
            ]),

          // 4. Experience
          if (experience.isNotEmpty)
            _section('EXPERIENCE', [
              for (final item in experience) _entry(item),
            ]),

          // 5. Projects
          if (projects.isNotEmpty)
            _section('PROJECTS', [
              for (final item in projects) _entry(item),
            ]),

          // 6. Education
          if (education.isNotEmpty)
            _section('EDUCATION', [
              for (final item in education) _entry(item),
            ]),

          // 7. Skills
          if (skills.isNotEmpty)
            _section('SKILLS & EXPERTISE', [
              pw.Text(
                skills.join('   |   '),
                style: pw.TextStyle(
                  fontSize: 9.5,
                  height: 1.45,
                  color: _ink,
                ),
              ),
            ]),

          // 8. Courses / Certifications
          if (courses.isNotEmpty)
            _section('CERTIFICATIONS & COURSES', [
              for (final item in courses) _entry(item),
            ]),
        ],
      ),
    );

    return document.save();
  }

  /// Opens the platform share/save sheet with the generated PDF.
  Future<void> export({
    required AppState state,
    required Resume resume,
  }) async {
    final bytes = await build(state: state, resume: resume);
    final fileName = fileNameFor(resume);
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  String fileNameFor(Resume resume) {
    final base = resume.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return '${base.isEmpty ? 'resume' : base}.pdf';
  }

  /// Normalizes Unicode punctuation (em-dash, en-dash, smart quotes, etc.)
  /// to prevent missing glyph warnings in standard PDF font encodings.
  static String _clean(String input) {
    return input
        .replaceAll('—', ' - ')
        .replaceAll('–', ' - ')
        .replaceAll('•', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'");
  }

  pw.Widget _section(String title, List<pw.Widget> children) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5,
                  color: _ink,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Divider(height: 1, thickness: 0.7, color: _line),
              ),
            ],
          ),
          pw.SizedBox(height: 7),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _entry(CareerItem item) {
    final title = _clean(item.title);
    final subtitle = item.subtitle != null ? _clean(item.subtitle!) : null;
    final dateRange = item.dateRange != null ? _clean(item.dateRange!) : null;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
              if (dateRange != null && dateRange.isNotEmpty)
                pw.Text(
                  dateRange,
                  style: const pw.TextStyle(fontSize: 8.5, color: _stone),
                ),
            ],
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 1.5),
            pw.Text(
              subtitle,
              style: pw.TextStyle(
                fontSize: 9,
                color: _stone,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
          for (final bullet in item.bullets)
            if (bullet.trim().isNotEmpty) _bulletRow(_clean(bullet)),
        ],
      ),
    );
  }

  pw.Widget _bulletRow(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, right: 6),
            child: pw.Container(
              width: 3.2,
              height: 3.2,
              decoration: const pw.BoxDecoration(
                color: _ink,
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 9.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
