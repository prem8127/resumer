import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'resume_docx_service.dart';
import 'resume_pdf_service.dart';

enum ResumeExportFormat {
  pdf,
  docx,
}

extension ResumeExportFormatX on ResumeExportFormat {
  String get label => switch (this) {
        ResumeExportFormat.pdf => 'PDF Document (.pdf)',
        ResumeExportFormat.docx => 'Word Document (.docx)',
      };

  String get shortLabel => switch (this) {
        ResumeExportFormat.pdf => 'PDF',
        ResumeExportFormat.docx => 'DOCX',
      };

  String get extension => switch (this) {
        ResumeExportFormat.pdf => '.pdf',
        ResumeExportFormat.docx => '.docx',
      };

  String get description => switch (this) {
        ResumeExportFormat.pdf =>
          'ATS-compliant, print-ready, fixed-layout document',
        ResumeExportFormat.docx =>
          'Fully editable Microsoft Word document for recruiters & tailoring',
      };

  IconData get icon => switch (this) {
        ResumeExportFormat.pdf => Icons.picture_as_pdf_rounded,
        ResumeExportFormat.docx => Icons.description_rounded,
      };

  Color get iconColor => switch (this) {
        ResumeExportFormat.pdf => const Color(0xFFD9381E),
        ResumeExportFormat.docx => const Color(0xFF2563EB),
      };

  Color get iconBgColor => switch (this) {
        ResumeExportFormat.pdf => const Color(0xFFFDE8E5),
        ResumeExportFormat.docx => const Color(0xFFEFF6FF),
      };
}

/// Coordinates resume export by prompting the user to choose between PDF
/// and DOCX, and dispatching to the respective generator.
class ResumeExportService {
  const ResumeExportService({
    this.pdfService = const ResumePdfService(),
    this.docxService = const ResumeDocxService(),
  });

  final ResumePdfService pdfService;
  final ResumeDocxService docxService;

  /// Shows an interactive bottom sheet asking the user to choose between
  /// PDF and DOCX, then exports the resume in the selected format.
  ///
  /// Returns the format exported, or null if the user cancelled.
  Future<ResumeExportFormat?> promptAndExport(
    BuildContext context, {
    required AppState state,
    required Resume resume,
  }) async {
    final format = await showModalBottomSheet<ResumeExportFormat>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ExportFormatSheet(resume: resume),
    );

    if (format == null) return null;
    if (!context.mounted) return null;

    try {
      if (format == ResumeExportFormat.pdf) {
        await pdfService.export(state: state, resume: resume);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported “${resume.name}” as an ATS-safe PDF'),
            ),
          );
        }
      } else {
        await docxService.export(state: state, resume: resume);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Exported “${resume.name}” as an editable Word document (.docx)'),
            ),
          );
        }
      }
      return format;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not export the resume: $error'),
          ),
        );
      }
      return null;
    }
  }
}

class _ExportFormatSheet extends StatelessWidget {
  const _ExportFormatSheet({required this.resume});

  final Resume resume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Export resume',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your preferred export format for “${resume.name}”',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.stone,
            ),
          ),
          const SizedBox(height: 20),

          // Option 1: PDF
          _FormatOptionTile(
            format: ResumeExportFormat.pdf,
            badgeText: 'Recommended',
            onTap: () => Navigator.of(context).pop(ResumeExportFormat.pdf),
          ),
          const SizedBox(height: 12),

          // Option 2: DOCX
          _FormatOptionTile(
            format: ResumeExportFormat.docx,
            badgeText: 'Editable',
            onTap: () => Navigator.of(context).pop(ResumeExportFormat.docx),
          ),
          const SizedBox(height: 12),

          // Cancel
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatOptionTile extends StatelessWidget {
  const _FormatOptionTile({
    required this.format,
    required this.badgeText,
    required this.onTap,
  });

  final ResumeExportFormat format;
  final String badgeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
          color: theme.colorScheme.surface,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: format.iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                format.icon,
                color: format.iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        format.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: format == ResumeExportFormat.pdf
                              ? AppColors.sageSoft
                              : const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: format == ResumeExportFormat.pdf
                                ? AppColors.sage
                                : const Color(0xFF4338CA),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    format.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.stone,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.stone,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
