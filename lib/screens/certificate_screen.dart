import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../services/certificate_pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/route_utils.dart';
import 'ai_interview_setup_screen.dart';
import 'career_profile_screen.dart';

/// "Get Certificate" — shows the earned certificate and lets the user
/// download/share it as a PDF. Reuses the same pdf/printing packages as
/// resume export.
class CertificateScreen extends StatefulWidget {
  const CertificateScreen({super.key, required this.course});

  final Course course;

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final CertificatePdfService _pdfService = const CertificatePdfService();
  bool _exporting = false;

  Future<void> _download(AppState state, CourseEnrollment enrollment) async {
    setState(() => _exporting = true);
    try {
      await _pdfService.export(
        recipientName: state.user.name,
        course: widget.course,
        scorePercent: enrollment.testScore ?? 0,
        certificateId: enrollment.certificateId ?? '',
        issuedAt: enrollment.certificateIssuedAt ?? DateTime.now(),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export certificate: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final enrollment = state.enrollmentFor(widget.course.id);

    if (enrollment == null || !enrollment.hasCertificate) {
      return Scaffold(
        appBar: AppBar(title: const Text('Certificate')),
        body: const EmptyState(
          icon: Icons.workspace_premium_outlined,
          title: 'No certificate yet',
          subtitle: 'Pass the final exam to earn your certificate.',
        ),
      );
    }

    final issuedAt = enrollment.certificateIssuedAt!;
    final score = enrollment.testScore ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Certificate')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryBlue, width: 2),
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface
                    : AppColors.paper,
              ),
              child: Column(
                children: [
                  const Text(
                    'RESUMER',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('CERTIFICATE OF COMPLETION',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 22),
                  Text('This is to certify that',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    state.user.name.trim().isEmpty
                        ? 'Student'
                        : state.user.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('has successfully completed',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    widget.course.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Score: $score%',
                      style: const TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ID: ${enrollment.certificateId}',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        '${issuedAt.day}/${issuedAt.month}/${issuedAt.year}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _exporting ? null : () => _download(state, enrollment),
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_exporting ? 'Preparing…' : 'Download PDF'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This certificate has also been added to your career profile.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            _CertificateNextStepsRow(
              onViewCareerProfile: () => pushRouteOnce(
                context,
                (_) => Scaffold(
                  appBar: AppBar(title: const Text('Career profile')),
                  body: const CareerProfileScreen(),
                ),
              ),
              onStartInterview: () => pushRouteOnce(
                context,
                (_) => const AiInterviewSetupScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Next-step actions after earning a certificate: jump straight into the
/// existing AI Interview flow, or check the career profile the certificate
/// was just added to. Reuses [AiInterviewSetupScreen] and
/// [CareerProfileScreen] unchanged — no interview or career logic lives here.
class _CertificateNextStepsRow extends StatelessWidget {
  const _CertificateNextStepsRow({
    required this.onStartInterview,
    required this.onViewCareerProfile,
  });

  final VoidCallback onStartInterview;
  final VoidCallback onViewCareerProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onStartInterview,
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Start AI Interview'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onViewCareerProfile,
            icon: const Icon(Icons.auto_awesome_mosaic_rounded, size: 18),
            label: const Text('View Career Profile'),
          ),
        ),
      ],
    );
  }
}
