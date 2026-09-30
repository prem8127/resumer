import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

/// Structured outcome of parsing an uploaded or pasted resume.
class ResumeParseResult {
  const ResumeParseResult({
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    required this.headline,
    required this.degree,
    required this.school,
    required this.graduation,
    required this.role,
    required this.company,
    required this.experience,
    required this.skills,
    this.allBullets = const [],
    this.rawText = '',
  });

  final String name;
  final String email;
  final String phone;
  final String location;
  final String headline;
  final String degree;
  final String school;
  final String graduation;
  final String role;
  final String company;
  final String experience;
  final List<String> skills;
  final List<String> allBullets;
  final String rawText;

  bool get isEmpty =>
      name.isEmpty &&
      email.isEmpty &&
      phone.isEmpty &&
      headline.isEmpty &&
      degree.isEmpty &&
      role.isEmpty &&
      skills.isEmpty;

  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'location': location,
        'headline': headline,
        'degree': degree,
        'school': school,
        'graduation': graduation,
        'role': role,
        'company': company,
        'experience': experience,
        'skills': skills,
      };
}

/// Service that scrapes and extracts career details from uploaded files or text.
class ResumeParserService {
  const ResumeParserService();

  static const List<String> supportedExtensions = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'md',
    'rtf',
  ];

  /// Opens the device file picker to select a resume and parses its contents.
  Future<ResumeParseResult?> pickAndParseResume() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
      );

      if (file == null) {
        return null;
      }

      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Selected file is empty');
      }

      return await parseFileBytes(bytes, file.name);
    } catch (e) {
      debugPrint('Resume file picking/parsing failed: $e');
      rethrow;
    }
  }

  /// Parses file bytes into structured resume fields.
  Future<ResumeParseResult> parseFileBytes(
    Uint8List bytes,
    String filename,
  ) async {
    final ext = filename.split('.').last.toLowerCase();
    String text = '';

    if (ext == 'pdf' || _isPdf(bytes)) {
      text = await extractTextFromPdf(bytes, sourceName: filename);
    } else if (ext == 'docx' || _isDocx(bytes)) {
      text = extractTextFromDocx(bytes);
    } else {
      try {
        text = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        text = String.fromCharCodes(bytes);
      }
    }

    // Clean up null bytes and carriage returns
    text = text
        .replaceAll('\x00', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    return parseText(text);
  }

  bool _isDocx(Uint8List bytes) {
    // DOCX files are ZIP containers and start with the ZIP local-file header.
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  /// Extracts visible text from the main document part of a DOCX file.
  /// Word stores paragraphs and runs as XML inside a ZIP archive; preserving
  /// paragraph and tab boundaries makes the existing section parser work for
  /// resumes exported from Word and Google Docs.
  String extractTextFromDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final document = archive.findFile('word/document.xml');
      if (document == null) return '';

      final xml = utf8.decode(document.readBytes() ?? Uint8List(0),
          allowMalformed: true);
      return _decodeDocxXml(xml).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    } catch (error) {
      debugPrint('Error extracting DOCX text: $error');
      return '';
    }
  }

  String _decodeDocxXml(String xml) {
    var text = xml
        .replaceAll(RegExp(r'<w:tab\s*/>'), '\t')
        .replaceAll(RegExp(r'</w:p\s*>'), '\n')
        .replaceAll(RegExp(r'<w:br\s*/>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    return text;
  }

  bool _isPdf(Uint8List bytes) {
    if (bytes.length < 5) return false;
    // %PDF-
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  /// Extracts text with PDFium so embedded fonts, character maps, compressed
  /// streams, Unicode, and multi-page documents are decoded by a real PDF
  /// engine. The lightweight scanner is retained only as a recovery path for
  /// malformed PDFs that PDFium cannot open.
  Future<String> extractTextFromPdf(
    Uint8List bytes, {
    String sourceName = 'resume.pdf',
  }) async {
    PdfDocument? document;
    try {
      await pdfrxFlutterInitialize();
      document = await PdfDocument.openData(
        bytes,
        sourceName: sourceName,
        useProgressiveLoading: false,
      );

      final extracted = StringBuffer();
      for (final page in document.pages) {
        final pageText = await page.loadStructuredText();
        final text = _formatPdfPageText(pageText).trim();
        if (text.isNotEmpty) {
          extracted.writeln(text);
          extracted.writeln();
        }
      }

      final result = _normalizeExtractedPdfText(extracted.toString());
      if (result.isNotEmpty) return result;
    } on Object {
      // Some damaged PDFs can still expose basic text operators. Fall through
      // to the recovery scanner without surfacing engine details to the user.
    } finally {
      await document?.dispose();
    }

    return _extractTextFromPdfFallback(bytes);
  }

  String _normalizeExtractedPdfText(String text) {
    return text
        .replaceAll('\u0000', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _formatPdfPageText(PdfPageText pageText) {
    final text = pageText.fullText;
    final rects = pageText.charRects;
    if (text.isEmpty || rects.isEmpty) return text;

    final output = StringBuffer();
    var index = 0;
    while (index < text.length) {
      if (!RegExp(r'\s').hasMatch(text[index])) {
        output.write(text[index]);
        index++;
        continue;
      }

      final whitespaceStart = index;
      while (index < text.length && RegExp(r'\s').hasMatch(text[index])) {
        index++;
      }
      if (output.isEmpty || index >= text.length) continue;

      PdfRect? previous;
      final previousStart = whitespaceStart - 1 < rects.length
          ? whitespaceStart - 1
          : rects.length - 1;
      for (var i = previousStart; i >= 0; i--) {
        if (rects[i].isNotEmpty) {
          previous = rects[i];
          break;
        }
      }
      PdfRect? next;
      for (var i = index; i < rects.length; i++) {
        if (rects[i].isNotEmpty) {
          next = rects[i];
          break;
        }
      }

      if (previous == null || next == null) {
        output.write('\n');
        continue;
      }

      final overlap = (previous.top < next.top ? previous.top : next.top) -
          (previous.bottom > next.bottom ? previous.bottom : next.bottom);
      final shorterHeight =
          previous.height < next.height ? previous.height : next.height;
      final centerDistance = (previous.center.y - next.center.y).abs();
      final sameVisualLine = overlap > shorterHeight * .25 ||
          centerDistance <= (previous.height + next.height) * .3;
      output.write(sameVisualLine ? ' ' : '\n');
    }
    return output.toString();
  }

  String _extractTextFromPdfFallback(Uint8List bytes) {
    final StringBuffer extracted = StringBuffer();

    try {
      // 1. First attempt: parse PDF streams including FlateDecode compression
      final content = String.fromCharCodes(bytes);
      final streamRegex = RegExp(r'stream[\r\n]+([\s\S]*?)[\r\n]+endstream');
      final matches = streamRegex.allMatches(content);

      for (final match in matches) {
        // Use the capture group rather than offsets into the complete match.
        // The bytes immediately after `stream` and before `endstream` contain
        // line delimiters which must not be passed to the zlib decoder.
        final captured = match.group(1);
        if (captured == null || captured.isEmpty) continue;
        final streamBytes = Uint8List.fromList(captured.codeUnits);
        Uint8List decodedBytes = streamBytes;

        // Attempt zlib / FlateDecode decompression.
        try {
          decodedBytes = Uint8List.fromList(zlib.decode(streamBytes));
        } catch (_) {
          // Uncompressed stream or a PDF using a filter this lightweight
          // parser does not need to decode.
        }

        final streamText = utf8.decode(decodedBytes, allowMalformed: true);
        final textFromOperators = _extractPdfTextOperators(streamText);
        if (textFromOperators.trim().isNotEmpty) {
          extracted.writeln(textFromOperators);
        }
      }
    } catch (e) {
      debugPrint('Error in deep PDF stream decoding: $e');
    }

    // 2. Fallback / supplementary extraction: extract standard text runs from parenthesized PDF strings
    if (extracted.length < 50) {
      final rawStr = utf8.decode(bytes, allowMalformed: true);
      final tjRegex = RegExp(r"\(([^)]+)\)\s*(?:Tj|')|\[(.*?)\]\s*TJ");
      for (final match in tjRegex.allMatches(rawStr)) {
        if (match.group(1) != null) {
          extracted.writeln(_decodePdfEscapes(match.group(1)!));
        } else if (match.group(2) != null) {
          final inner = match.group(2)!;
          final innerParen = RegExp(r'\(([^)]+)\)');
          for (final innerMatch in innerParen.allMatches(inner)) {
            extracted.write(_decodePdfEscapes(innerMatch.group(1)!));
            extracted.write(' ');
          }
          extracted.writeln();
        }
      }
    }

    // 3. Fallback: printable ASCII blocks if streams were obscured
    if (extracted.length < 50) {
      final latin = String.fromCharCodes(bytes);
      final wordBlockRegex = RegExp(r'[A-Za-z0-9@.,\-+()\/:\s]{4,}');
      for (final match in wordBlockRegex.allMatches(latin)) {
        final chunk = match.group(0)!.trim();
        if (chunk.isNotEmpty && !chunk.startsWith('/')) {
          extracted.writeln(chunk);
        }
      }
    }

    return extracted.toString();
  }

  String _extractPdfTextOperators(String stream) {
    final StringBuffer sb = StringBuffer();
    // Match text blocks inside BT ... ET
    final btRegex = RegExp(r'BT([\s\S]*?)ET');
    final btMatches = btRegex.allMatches(stream);

    for (final bt in btMatches) {
      final block = bt.group(1) ?? '';
      // (string) Tj or '
      final tjRegex = RegExp(r"\((.*?)\)\s*Tj|\((.*?)\)\s*'|\[(.*?)\]\s*TJ");
      for (final m in tjRegex.allMatches(block)) {
        if (m.group(1) != null) {
          sb.writeln(_decodePdfEscapes(m.group(1)!));
        } else if (m.group(2) != null) {
          sb.writeln(_decodePdfEscapes(m.group(2)!));
        } else if (m.group(3) != null) {
          final arrayContent = m.group(3)!;
          final itemRegex = RegExp(r'\((.*?)\)|(-?\d+(?:\.\d+)?)');
          for (final item in itemRegex.allMatches(arrayContent)) {
            if (item.group(1) != null) {
              sb.write(_decodePdfEscapes(item.group(1)!));
            } else if (item.group(2) != null) {
              final spacing = double.tryParse(item.group(2)!) ?? 0;
              if (spacing < -120) sb.write(' ');
            }
          }
          sb.writeln();
        }
      }
      sb.writeln();
    }
    return sb.toString();
  }

  String _decodePdfEscapes(String s) {
    return s
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
  }

  /// Parses raw text into structured resume fields.
  ResumeParseResult parseText(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ResumeParseResult(
        name: '',
        email: '',
        phone: '',
        location: '',
        headline: '',
        degree: '',
        school: '',
        graduation: '',
        role: '',
        company: '',
        experience: '',
        skills: [],
        rawText: '',
      );
    }

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Extract Email
    final emailRegex =
        RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b');
    final emailMatch = emailRegex.firstMatch(rawText);
    final email = emailMatch?.group(0) ?? '';

    // 2. Extract Phone
    final phoneRegex = RegExp(
        r'(?:\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,5}[-.\s]?\d{4,5}');
    String phone = '';
    for (final line in lines.take(15)) {
      final pMatch = phoneRegex.firstMatch(line);
      if (pMatch != null) {
        final candidate = pMatch.group(0)!.trim();
        if (candidate.replaceAll(RegExp(r'\D'), '').length >= 10) {
          phone = candidate;
          break;
        }
      }
    }

    // 3. Extract Name
    String name = '';
    for (final line in lines.take(6)) {
      if (line.toLowerCase().contains('resume') ||
          line.toLowerCase().contains('curriculum vitae') ||
          line.toLowerCase().contains('http') ||
          line.contains('@') ||
          line.length < 2 ||
          line.length > 50) {
        continue;
      }
      // Check if line looks like a person's name (letters and spaces/hyphens)
      if (RegExp(r'^[A-Za-z\s\.\-]+$').hasMatch(line) &&
          !line.toLowerCase().contains('education') &&
          !line.toLowerCase().contains('experience') &&
          !line.toLowerCase().contains('skills')) {
        final words = line.split(RegExp(r'\s+'));
        if (const [1, 2, 3, 4].contains(words.length)) {
          name = words
              .map((w) => w.isEmpty
                  ? ''
                  : '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1) : ''}')
              .join(' ');
          break;
        }
      }
    }

    // 4. Extract Location
    String location = '';
    final locationPatterns = [
      RegExp(r'\b([A-Za-z\s]+),\s*([A-Za-z]{2,})\b'),
      RegExp(
          r'\b(Bengaluru|Bangalore|Hyderabad|Mumbai|Delhi|Pune|Chennai|San Francisco|New York|London|Berlin|Toronto|Seattle|Austin|Boston|Noida|Gurgaon|Kolkata|California|Texas|Washington|India|USA|UK|Canada)\b',
          caseSensitive: false),
    ];
    for (final line in lines.take(12)) {
      final segments = line.split(RegExp(r'[|•\t]'));
      for (final segment in segments) {
        final cleanSeg = segment.trim();
        if (cleanSeg.contains('@') ||
            cleanSeg.toLowerCase().contains('http') ||
            cleanSeg.toLowerCase().contains('github') ||
            cleanSeg.toLowerCase().contains('linkedin') ||
            cleanSeg.length > 50) {
          continue;
        }
        for (final pat in locationPatterns) {
          final match = pat.firstMatch(cleanSeg);
          if (match != null) {
            final matchedText = match.group(0)!.trim();
            if (!matchedText.toLowerCase().contains('university') &&
                !matchedText.toLowerCase().contains('college') &&
                !matchedText.toLowerCase().contains('engineer') &&
                !matchedText.toLowerCase().contains('developer') &&
                !matchedText.toLowerCase().contains('resume')) {
              location = matchedText;
              break;
            }
          }
        }
        if (location.isNotEmpty) break;
      }
      if (location.isNotEmpty) break;
    }

    // 5. Identify Sections
    final sectionHeaders = <String, int>{};
    for (var i = 0; i < lines.length; i++) {
      final clean =
          lines[i].replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim().toUpperCase();
      if (clean == 'EDUCATION' ||
          clean == 'ACADEMIC BACKGROUND' ||
          clean == 'QUALIFICATIONS') {
        sectionHeaders['education'] = i;
      } else if (clean == 'EXPERIENCE' ||
          clean == 'WORK EXPERIENCE' ||
          clean == 'EMPLOYMENT' ||
          clean == 'WORK HISTORY' ||
          clean == 'INTERNSHIPS') {
        sectionHeaders['experience'] = i;
      } else if (clean == 'PROJECTS' ||
          clean == 'ACADEMIC PROJECTS' ||
          clean == 'KEY PROJECTS') {
        sectionHeaders['projects'] = i;
      } else if (clean == 'SKILLS' ||
          clean == 'TECHNICAL SKILLS' ||
          clean == 'CORE SKILLS' ||
          clean == 'TECHNOLOGIES' ||
          clean == 'TOOLS AND TECHNOLOGIES') {
        sectionHeaders['skills'] = i;
      } else if (clean == 'SUMMARY' ||
          clean == 'PROFESSIONAL SUMMARY' ||
          clean == 'ABOUT ME' ||
          clean == 'OBJECTIVE' ||
          clean == 'PROFILE') {
        sectionHeaders['summary'] = i;
      }
    }

    // 6. Extract Headline / Summary
    String headline = '';
    if (sectionHeaders.containsKey('summary')) {
      final start = sectionHeaders['summary']! + 1;
      final buffer = StringBuffer();
      for (var i = start; i < lines.length && i < start + 4; i++) {
        if (_isAnyHeader(lines[i])) break;
        buffer.writeln(lines[i]);
      }
      headline = buffer.toString().trim();
    }
    if (headline.isEmpty) {
      // Look right under the name
      for (var i = 1; i < lines.length && i < 6; i++) {
        final line = lines[i];
        if (!line.contains('@') &&
            !phoneRegex.hasMatch(line) &&
            !_isAnyHeader(line) &&
            line.length > 5 &&
            line.length < 80) {
          headline = line;
          break;
        }
      }
    }

    // 7. Extract Education Details
    String degree = '';
    String school = '';
    String graduation = '';

    final degreePatterns = [
      RegExp(
          r'\b(B\.?Tech|B\.?E\.?|B\.?S\.?|B\.?Sc|BCA|Bachelor of [A-Za-z\s]+)\b',
          caseSensitive: false),
      RegExp(r'\b(M\.?Tech|M\.?S\.?|M\.?Sc|MCA|MBA|Master of [A-Za-z\s]+)\b',
          caseSensitive: false),
      RegExp(
          r'\b(Computer Science|Information Technology|Electrical Engineering|Mechanical Engineering|Data Science)\b',
          caseSensitive: false),
    ];
    final schoolPatterns = [
      RegExp(
          r'([A-Za-z\s]+(?:University|Institute|College|School|Academy|IIT|NIT|IIIT|BITS|Stanford|MIT|Harvard)[A-Za-z\s]*)',
          caseSensitive: false),
    ];
    final datePattern = RegExp(
        r'\b((?:20\d\d|19\d\d)\s*(?:–|-|to|—)\s*(?:20\d\d|19\d\d|Present|Current)|20\d\d)\b',
        caseSensitive: false);

    if (sectionHeaders.containsKey('education')) {
      final start = sectionHeaders['education']! + 1;
      for (var i = start; i < lines.length && i < start + 8; i++) {
        if (_isAnyHeader(lines[i])) break;
        final line = lines[i];

        if (degree.isEmpty) {
          for (final pat in degreePatterns) {
            final m = pat.firstMatch(line);
            if (m != null) {
              degree = line.replaceAll(RegExp(r'[|•\-]'), '').trim();
              break;
            }
          }
        }

        if (school.isEmpty) {
          for (final pat in schoolPatterns) {
            final m = pat.firstMatch(line);
            if (m != null) {
              school = m.group(0)!.trim();
              break;
            }
          }
        }

        if (graduation.isEmpty) {
          final m = datePattern.firstMatch(line);
          if (m != null) {
            graduation = m.group(0)!.trim();
          }
        }
      }
    }

    // 8. Extract Experience / Projects
    String role = '';
    String company = '';
    String experience = '';
    final List<String> allBullets = [];

    final expSectionIndex =
        sectionHeaders['experience'] ?? sectionHeaders['projects'];
    if (expSectionIndex != null) {
      final start = expSectionIndex + 1;
      for (var i = start; i < lines.length && i < start + 12; i++) {
        if (_isAnyHeader(lines[i])) break;
        final line = lines[i];

        if (role.isEmpty &&
            (line.contains('|') ||
                line.contains('—') ||
                line.contains(' at '))) {
          final parts = line.split(RegExp(r'[|—]|\bat\b'));
          if (parts.length >= 2) {
            role = parts[0].trim();
            company = parts[1].trim();
          } else {
            role = line;
          }
          continue;
        }

        if (role.isEmpty &&
            RegExp(r'\b(Intern|Engineer|Developer|Manager|Analyst|Consultant|Lead)\b',
                    caseSensitive: false)
                .hasMatch(line)) {
          role = line;
          continue;
        }

        if (company.isEmpty &&
            RegExp(r'\b(Inc|LLC|Technologies|Labs|Startup|Hub|Solutions|Corp|Company)\b',
                    caseSensitive: false)
                .hasMatch(line)) {
          company = line;
          continue;
        }

        // Check if line is a bullet / achievement
        if (line.startsWith('•') ||
            line.startsWith('-') ||
            line.startsWith('*') ||
            RegExp(r'^(Built|Developed|Implemented|Designed|Led|Engineered|Created|Automated|Optimized)\b',
                    caseSensitive: false)
                .hasMatch(line)) {
          final cleanBullet =
              line.replaceAll(RegExp(r'^[•\-\*\s]+'), '').trim();
          if (cleanBullet.length > 15) {
            allBullets.add(cleanBullet);
            if (experience.isEmpty) {
              experience = cleanBullet;
            }
          }
        }
      }
    }

    // 9. Extract Skills
    final Set<String> extractedSkills = {};
    const commonSkillSet = {
      'Flutter',
      'Dart',
      'Python',
      'Java',
      'JavaScript',
      'TypeScript',
      'C++',
      'C#',
      'Go',
      'Rust',
      'Kotlin',
      'Swift',
      'PHP',
      'Ruby',
      'HTML',
      'CSS',
      'React',
      'Next.js',
      'Vue.js',
      'Angular',
      'Node.js',
      'Express',
      'Django',
      'FastAPI',
      'Flask',
      'Spring Boot',
      'PostgreSQL',
      'MySQL',
      'MongoDB',
      'Redis',
      'SQLite',
      'Firebase',
      'AWS',
      'Google Cloud',
      'GCP',
      'Azure',
      'Docker',
      'Kubernetes',
      'Git',
      'GitHub',
      'GitLab',
      'CI/CD',
      'Linux',
      'Figma',
      'REST API',
      'GraphQL',
      'Tailwind CSS',
      'Machine Learning',
      'TensorFlow',
      'PyTorch',
      'Pandas',
      'NumPy',
      'SQL',
    };

    // First, scan the dedicated skills section if available
    if (sectionHeaders.containsKey('skills')) {
      final start = sectionHeaders['skills']! + 1;
      for (var i = start; i < lines.length && i < start + 6; i++) {
        if (_isAnyHeader(lines[i])) break;
        final line = lines[i];
        final parts = line.split(RegExp(r'[:,|•\n\t\/]'));
        for (final p in parts) {
          final skillCandidate = p.trim();
          if (skillCandidate.isNotEmpty &&
              skillCandidate.length < 30 &&
              !skillCandidate.toLowerCase().contains('programming') &&
              !skillCandidate.toLowerCase().contains('languages') &&
              !skillCandidate.toLowerCase().contains('frameworks') &&
              !skillCandidate.toLowerCase().contains('tools')) {
            extractedSkills.add(skillCandidate);
          }
        }
      }
    }

    // Scan raw text against dictionary for high accuracy
    for (final skill in commonSkillSet) {
      final pattern =
          RegExp('\\b${RegExp.escape(skill)}\\b', caseSensitive: false);
      if (pattern.hasMatch(rawText)) {
        extractedSkills.add(skill);
      }
    }

    return ResumeParseResult(
      name: name,
      email: email,
      phone: phone,
      location: location,
      headline: headline,
      degree: degree,
      school: school,
      graduation: graduation,
      role: role,
      company: company,
      experience: experience,
      skills: extractedSkills.isNotEmpty
          ? extractedSkills.take(8).toList()
          : const [],
      allBullets: allBullets,
      rawText: rawText,
    );
  }

  bool _isAnyHeader(String line) {
    final clean =
        line.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim().toUpperCase();
    return clean == 'EDUCATION' ||
        clean == 'ACADEMIC BACKGROUND' ||
        clean == 'EXPERIENCE' ||
        clean == 'WORK EXPERIENCE' ||
        clean == 'PROJECTS' ||
        clean == 'SKILLS' ||
        clean == 'TECHNICAL SKILLS' ||
        clean == 'SUMMARY' ||
        clean == 'PROFESSIONAL SUMMARY' ||
        clean == 'CERTIFICATIONS' ||
        clean == 'ACHIEVEMENTS' ||
        clean == 'PUBLICATIONS';
  }
}
