import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import '../data/app_state.dart';
import '../models/models.dart';

/// Generates a real, ATS-friendly Microsoft Word document (.docx) for a resume
/// and hands it off to save/share.
class ResumeDocxService {
  const ResumeDocxService();

  /// Builds a valid, ATS-friendly Word document (.docx) as a byte array.
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
        .map((item) => item.title.trim())
        .where((title) => title.isNotEmpty)
        .toList();
    final courses = state.careerItems
        .where((item) => item.type == CareerItemType.course)
        .toList();

    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln(
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    buffer.writeln('  <w:body>');

    // 1. Header: Full Name
    final displayName =
        user.name.trim().isEmpty ? 'YOUR NAME' : user.name.trim().toUpperCase();
    buffer.writeln('    <w:p>');
    buffer.writeln('      <w:pPr>');
    buffer.writeln('        <w:jc w:val="center"/>');
    buffer.writeln('        <w:spacing w:before="0" w:after="40"/>');
    buffer.writeln('      </w:pPr>');
    buffer.writeln('      <w:r>');
    buffer.writeln('        <w:rPr>');
    buffer.writeln('          <w:b/>');
    buffer.writeln('          <w:sz w:val="44"/>');
    buffer.writeln('          <w:color w:val="1D1F1B"/>');
    buffer.writeln('        </w:rPr>');
    buffer.writeln('        <w:t>${_escapeXml(displayName)}</w:t>');
    buffer.writeln('      </w:r>');
    buffer.writeln('    </w:p>');

    // 2. Headline / Target Role
    final headline = user.headline.trim();
    if (headline.isNotEmpty) {
      buffer.writeln('    <w:p>');
      buffer.writeln('      <w:pPr>');
      buffer.writeln('        <w:jc w:val="center"/>');
      buffer.writeln('        <w:spacing w:before="0" w:after="50"/>');
      buffer.writeln('      </w:pPr>');
      buffer.writeln('      <w:r>');
      buffer.writeln('        <w:rPr>');
      buffer.writeln('          <w:b/>');
      buffer.writeln('          <w:sz w:val="22"/>');
      buffer.writeln('          <w:color w:val="4F6B58"/>');
      buffer.writeln('        </w:rPr>');
      buffer.writeln('        <w:t>${_escapeXml(headline)}</w:t>');
      buffer.writeln('      </w:r>');
      buffer.writeln('    </w:p>');
    }

    // 3. Contact Details
    final contactParts = [user.email, user.phone, user.location]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (contactParts.isNotEmpty) {
      buffer.writeln('    <w:p>');
      buffer.writeln('      <w:pPr>');
      buffer.writeln('        <w:jc w:val="center"/>');
      buffer.writeln(
          '        <w:pBdr><w:bottom w:val="single" w:sz="6" w:space="5" w:color="D1D5DB"/></w:pBdr>');
      buffer.writeln('        <w:spacing w:before="0" w:after="160"/>');
      buffer.writeln('      </w:pPr>');
      buffer.writeln('      <w:r>');
      buffer.writeln('        <w:rPr>');
      buffer.writeln('          <w:sz w:val="18"/>');
      buffer.writeln('          <w:color w:val="6B7280"/>');
      buffer.writeln('        </w:rPr>');
      buffer.writeln(
          '        <w:t>${_escapeXml(contactParts.join('   |   '))}</w:t>');
      buffer.writeln('      </w:r>');
      buffer.writeln('    </w:p>');
    }

    // 4. Professional Summary / Target Role
    final hasTargetRole =
        resume.targetRole != null && resume.targetRole!.trim().isNotEmpty;
    if (hasTargetRole || headline.isNotEmpty) {
      _writeSectionHeader(buffer, 'PROFESSIONAL SUMMARY');
      final summaryText = hasTargetRole
          ? (headline.isNotEmpty
              ? '$headline with targeted focus toward ${resume.targetRole}${resume.targetCompany == null ? '' : ' at ${resume.targetCompany}'}. Proven background delivering dependable, high-impact results with cross-functional technical rigor.'
              : 'Targeted for ${resume.targetRole}${resume.targetCompany == null ? '' : ' at ${resume.targetCompany}'}. Proven background delivering dependable, high-impact results with cross-functional technical rigor.')
          : '$headline with demonstrated expertise in delivering high-quality engineering and product solutions. Committed to technical excellence, continuous learning, and driving scalable impact.';

      buffer.writeln('    <w:p>');
      buffer.writeln('      <w:pPr>');
      buffer.writeln('        <w:spacing w:before="40" w:after="100"/>');
      buffer.writeln('      </w:pPr>');
      buffer.writeln('      <w:r>');
      buffer.writeln('        <w:rPr>');
      buffer.writeln('          <w:sz w:val="21"/>');
      buffer.writeln('          <w:color w:val="2D3748"/>');
      buffer.writeln('        </w:rPr>');
      buffer.writeln('        <w:t>${_escapeXml(summaryText)}</w:t>');
      buffer.writeln('      </w:r>');
      buffer.writeln('    </w:p>');
    }

    // 5. Targeted Highlights (Tailored Bullets)
    if (resume.tailoredBullets.isNotEmpty) {
      _writeSectionHeader(buffer, 'TARGETED HIGHLIGHTS');
      for (final bullet in resume.tailoredBullets) {
        _writeBullet(buffer, bullet);
      }
    }

    // 6. Experience
    if (experience.isNotEmpty) {
      _writeSectionHeader(buffer, 'EXPERIENCE');
      for (final item in experience) {
        _writeCareerEntry(buffer, item);
      }
    }

    // 7. Projects
    if (projects.isNotEmpty) {
      _writeSectionHeader(buffer, 'PROJECTS');
      for (final item in projects) {
        _writeCareerEntry(buffer, item);
      }
    }

    // 8. Education
    if (education.isNotEmpty) {
      _writeSectionHeader(buffer, 'EDUCATION');
      for (final item in education) {
        _writeCareerEntry(buffer, item);
      }
    }

    // 9. Skills
    if (skills.isNotEmpty) {
      _writeSectionHeader(buffer, 'SKILLS & EXPERTISE');
      buffer.writeln('    <w:p>');
      buffer.writeln('      <w:pPr>');
      buffer.writeln('        <w:spacing w:before="40" w:after="100"/>');
      buffer.writeln('      </w:pPr>');
      buffer.writeln('      <w:r>');
      buffer.writeln('        <w:rPr>');
      buffer.writeln('          <w:sz w:val="21"/>');
      buffer.writeln('          <w:color w:val="2D3748"/>');
      buffer.writeln('        </w:rPr>');
      buffer
          .writeln('        <w:t>${_escapeXml(skills.join('   |   '))}</w:t>');
      buffer.writeln('      </w:r>');
      buffer.writeln('    </w:p>');
    }

    // 10. Courses / Certifications
    if (courses.isNotEmpty) {
      _writeSectionHeader(buffer, 'CERTIFICATIONS & COURSES');
      for (final item in courses) {
        _writeCareerEntry(buffer, item);
      }
    }

    // Page setup: A4 with 0.7in margins (1000 dxa)
    buffer.writeln('    <w:sectPr>');
    buffer.writeln('      <w:pgSz w:w="11906" w:h="16838"/>');
    buffer.writeln(
        '      <w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1000" w:header="720" w:footer="720" w:gutter="0"/>');
    buffer.writeln('    </w:sectPr>');

    buffer.writeln('  </w:body>');
    buffer.writeln('</w:document>');

    final archive = Archive();

    const contentTypesXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
</Types>''';

    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    const documentRelsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
</Relationships>''';

    const settingsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:defaultTabStop w:val="720"/>
</w:settings>''';

    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Calibri"/>
        <w:sz w:val="21"/>
        <w:szCs w:val="21"/>
        <w:color w:val="1D1F1B"/>
        <w:lang w:val="en-US"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:line="260" w:lineRule="auto"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
</w:styles>''';

    void addFile(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    addFile('[Content_Types].xml', contentTypesXml);
    addFile('_rels/.rels', relsXml);
    addFile('word/_rels/document.xml.rels', documentRelsXml);
    addFile('word/settings.xml', settingsXml);
    addFile('word/styles.xml', stylesXml);
    addFile('word/document.xml', buffer.toString());

    final zipBytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipBytes);
  }

  /// Exports the generated Word document to the user's device via Save/Share.
  Future<void> export({
    required AppState state,
    required Resume resume,
  }) async {
    final bytes = await build(state: state, resume: resume);
    final fileName = fileNameFor(resume);

    try {
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Save Resume as Word Document',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['docx'],
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      if (savedUri != null) return;
    } catch (error) {
      debugPrint('FilePicker saveFile failed or not supported: $error');
    }

    // Fallback: use Printing.sharePdf or web anchor download
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  String fileNameFor(Resume resume) {
    final base = resume.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return '${base.isEmpty ? 'resume' : base}.docx';
  }

  void _writeSectionHeader(StringBuffer buffer, String title) {
    buffer.writeln('    <w:p>');
    buffer.writeln('      <w:pPr>');
    buffer.writeln(
        '        <w:pBdr><w:bottom w:val="single" w:sz="6" w:space="3" w:color="E5E7EB"/></w:pBdr>');
    buffer.writeln('        <w:spacing w:before="220" w:after="70"/>');
    buffer.writeln('      </w:pPr>');
    buffer.writeln('      <w:r>');
    buffer.writeln('        <w:rPr>');
    buffer.writeln('          <w:b/>');
    buffer.writeln('          <w:sz w:val="21"/>');
    buffer.writeln('          <w:color w:val="111827"/>');
    buffer.writeln('        </w:rPr>');
    buffer.writeln('        <w:t>${_escapeXml(title.toUpperCase())}</w:t>');
    buffer.writeln('      </w:r>');
    buffer.writeln('    </w:p>');
  }

  void _writeCareerEntry(StringBuffer buffer, CareerItem item) {
    // Title + Date on one line (right aligned tab)
    buffer.writeln('    <w:p>');
    buffer.writeln('      <w:pPr>');
    buffer.writeln('        <w:tabs>');
    buffer.writeln('          <w:tab w:val="right" w:pos="9800"/>');
    buffer.writeln('        </w:tabs>');
    buffer.writeln('        <w:spacing w:before="100" w:after="20"/>');
    buffer.writeln('      </w:pPr>');
    buffer.writeln('      <w:r>');
    buffer.writeln('        <w:rPr>');
    buffer.writeln('          <w:b/>');
    buffer.writeln('          <w:sz w:val="21"/>');
    buffer.writeln('          <w:color w:val="111827"/>');
    buffer.writeln('        </w:rPr>');
    buffer.writeln('        <w:t>${_escapeXml(item.title)}</w:t>');
    buffer.writeln('      </w:r>');
    if (item.dateRange != null && item.dateRange!.trim().isNotEmpty) {
      buffer.writeln('      <w:r>');
      buffer.writeln('        <w:tab/>');
      buffer.writeln('        <w:rPr>');
      buffer.writeln('          <w:sz w:val="18"/>');
      buffer.writeln('          <w:color w:val="6B7280"/>');
      buffer.writeln('        </w:rPr>');
      buffer.writeln('        <w:t>${_escapeXml(item.dateRange!)}</w:t>');
      buffer.writeln('      </w:r>');
    }
    buffer.writeln('    </w:p>');

    // Subtitle (Company / School / Tech stack)
    if (item.subtitle != null && item.subtitle!.trim().isNotEmpty) {
      buffer.writeln('    <w:p>');
      buffer.writeln('      <w:pPr>');
      buffer.writeln('        <w:spacing w:before="0" w:after="40"/>');
      buffer.writeln('      </w:pPr>');
      buffer.writeln('      <w:r>');
      buffer.writeln('        <w:rPr>');
      buffer.writeln('          <w:i/>');
      buffer.writeln('          <w:sz w:val="19"/>');
      buffer.writeln('          <w:color w:val="4B5563"/>');
      buffer.writeln('        </w:rPr>');
      buffer.writeln('        <w:t>${_escapeXml(item.subtitle!)}</w:t>');
      buffer.writeln('      </w:r>');
      buffer.writeln('    </w:p>');
    }

    // Bullets
    for (final bullet in item.bullets) {
      _writeBullet(buffer, bullet);
    }
  }

  void _writeBullet(StringBuffer buffer, String bullet) {
    if (bullet.trim().isEmpty) return;
    buffer.writeln('    <w:p>');
    buffer.writeln('      <w:pPr>');
    buffer.writeln('        <w:ind w:left="360" w:hanging="220"/>');
    buffer.writeln('        <w:spacing w:before="20" w:after="25"/>');
    buffer.writeln('      </w:pPr>');
    buffer.writeln('      <w:r>');
    buffer.writeln('        <w:rPr>');
    buffer.writeln('          <w:color w:val="111827"/>');
    buffer.writeln('        </w:rPr>');
    buffer.writeln('        <w:t xml:space="preserve">•  </w:t>');
    buffer.writeln('      </w:r>');
    buffer.writeln('      <w:r>');
    buffer.writeln('        <w:rPr>');
    buffer.writeln('          <w:sz w:val="20"/>');
    buffer.writeln('          <w:color w:val="2D3748"/>');
    buffer.writeln('        </w:rPr>');
    buffer.writeln('        <w:t>${_escapeXml(bullet)}</w:t>');
    buffer.writeln('      </w:r>');
    buffer.writeln('    </w:p>');
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  }
}
