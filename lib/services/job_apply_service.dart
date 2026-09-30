import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';

/// Opens a job posting so the user can sign in there
/// and submit the application prepared in the app.
///
/// Resolution order:
///   1. The direct careers-portal URL captured by the scraper (always present
///      for live listings).
///   2. A web search for the company's own careers page for this role — used
///      only by demo listings for fictional companies. Aggregators such as
///      LinkedIn are never opened.
class JobApplyService {
  JobApplyService({Future<bool> Function(Uri)? launcher})
      : _launcherOverride = launcher;

  final Future<bool> Function(Uri)? _launcherOverride;

  /// Resolves where to send the user and opens it externally.
  ///
  /// Returns true when a browser was opened. Never throws — failures surface
  /// as a false return so callers can show their own fallback message.
  Future<bool> openJobPosting(JobOpening job) async {
    final Uri target = _resolve(job);
    try {
      final Future<bool> Function(Uri)? override = _launcherOverride;
      if (override != null) {
        return await override(target);
      }
      return await launchUrl(
        target,
        mode: LaunchMode.externalApplication,
        webViewConfiguration:
            const WebViewConfiguration(enableJavaScript: true),
      );
    } on Object {
      return false;
    }
  }

  /// The careers-portal URL when usable, otherwise a search for the company's
  /// own careers page. LinkedIn and other aggregators are never used.
  Uri resolveTarget(JobOpening job) => _resolve(job);

  Uri _resolve(JobOpening job) {
    final raw = job.url?.trim() ?? '';
    final direct = Uri.tryParse(raw);
    if (direct != null &&
        (direct.scheme == 'http' || direct.scheme == 'https') &&
        direct.host.isNotEmpty) {
      return direct;
    }
    return Uri.https('www.google.com', '/search', {
      'q': '${job.companyName} ${job.title} careers site apply',
    });
  }
}
