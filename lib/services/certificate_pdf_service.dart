import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

/// Generates a landscape certificate-of-completion PDF and hands it to the
/// platform share/save sheet — same pattern as [ResumePdfService].
class CertificatePdfService {
  const CertificatePdfService();

  static const PdfColor _ink = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _blue = PdfColor.fromInt(0xFF1677E8);
  static const PdfColor _stone = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _gold = PdfColor.fromInt(0xFFF59E0B);

  Future<Uint8List> build({
    required String recipientName,
    required Course course,
    required int scorePercent,
    required String certificateId,
    required DateTime issuedAt,
  }) async {
    final document = pw.Document(
      title: 'Certificate - ${course.title}',
      author: 'Resumer',
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _blue, width: 2.5),
            ),
            padding: const pw.EdgeInsets.all(36),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'RESUMER',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _blue,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'CERTIFICATE OF COMPLETION',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: _stone,
                    letterSpacing: 3,
                  ),
                ),
                pw.SizedBox(height: 28),
                pw.Text('This is to certify that',
                    style: const pw.TextStyle(fontSize: 12, color: _stone)),
                pw.SizedBox(height: 10),
                pw.Text(
                  recipientName.trim().isEmpty ? 'Student' : recipientName,
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('has successfully completed',
                    style: const pw.TextStyle(fontSize: 12, color: _stone)),
                pw.SizedBox(height: 8),
                pw.Text(
                  course.title,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _blue,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Score: $scorePercent%',
                  style: pw.TextStyle(
                    fontSize: 13,
                    color: _gold,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Certificate ID: $certificateId',
                      style: const pw.TextStyle(fontSize: 10, color: _stone),
                    ),
                    pw.Text(
                      '${issuedAt.day}/${issuedAt.month}/${issuedAt.year}',
                      style: const pw.TextStyle(fontSize: 10, color: _stone),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return document.save();
  }

  /// Opens the platform share/save sheet with the generated certificate PDF.
  Future<void> export({
    required String recipientName,
    required Course course,
    required int scorePercent,
    required String certificateId,
    required DateTime issuedAt,
  }) async {
    final bytes = await build(
      recipientName: recipientName,
      course: course,
      scorePercent: scorePercent,
      certificateId: certificateId,
      issuedAt: issuedAt,
    );
    final fileName =
        'Certificate-${course.title.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
