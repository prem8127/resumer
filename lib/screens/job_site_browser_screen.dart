import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../services/job_apply_service.dart';
import '../services/profile_autofill_service.dart';
import '../theme/app_theme.dart';

/// Full-screen in-app browser for a job posting.
///
/// Cookies, DOM storage and the HTTP cache persist inside the app, so once
/// the user signs into a company site they stay signed in across sessions.
/// On every finished page load the profile autofill script is injected; with
/// auto-submit enabled a genuine application button is clicked after filling.
class JobSiteBrowserScreen extends StatefulWidget {
  const JobSiteBrowserScreen({super.key, required this.job});

  final JobOpening job;

  @override
  State<JobSiteBrowserScreen> createState() => _JobSiteBrowserScreenState();
}

class _JobSiteBrowserScreenState extends State<JobSiteBrowserScreen> {
  final ProfileAutofillService _autofill = ProfileAutofillService();
  late final PullToRefreshController _pullToRefresh =
      PullToRefreshController(onRefresh: () => _controller?.reload());
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _autoSubmit = false;
  String _hostLabel = '';

  late final Uri _startUrl = JobApplyService().resolveTarget(widget.job);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hostLabel.isEmpty) {
      _hostLabel = _labelFor(_startUrl);
    }
  }

  String _labelFor(Uri uri) => uri.host.replaceFirst(RegExp(r'^www\.'), '');

  Future<void> _injectAutofill(InAppWebViewController controller) async {
    final state = AppScope.of(context);
    await controller.evaluateJavascript(
      source: _autofill.buildScript(
        user: state.user,
        autoSubmit: _autoSubmit,
      ),
    );
  }

  void _handleConsoleMessage(ConsoleMessage message) {
    final text = message.message;
    if (!text.startsWith(ProfileAutofillService.resultMarker)) return;
    try {
      final payload = jsonDecode(
          text.substring(ProfileAutofillService.resultMarker.length));
      final filled = payload['filled'];
      final submitted = payload['submitted'] == true;
      if (filled is num && filled > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Autofilled $filled field${filled == 1 ? '' : 's'}'
              '${submitted ? ' and submitted the application' : ''}.',
            ),
          ),
        );
      }
    } on Object {
      // Non-JSON marker output — ignore.
    }
  }

  Future<void> _openExternally() async {
    await launchUrl(_startUrl, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final controller = _controller;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
        } else {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.job.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Text(
                '$_hostLabel · applying as ${AppScope.of(context).user.email}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: .8),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Reload page (re-runs autofill)',
              onPressed: () => _controller?.reload(),
              icon: const Icon(Icons.refresh_rounded, size: 21),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'external':
                    _openExternally();
                  case 'top':
                    _controller?.scrollTo(x: 0, y: 0, animated: true);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'external',
                    child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.open_in_browser_rounded, size: 20),
                        title: Text('Open in system browser'))),
                PopupMenuItem(
                    value: 'top',
                    child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Icon(Icons.vertical_align_top_rounded, size: 20),
                        title: Text('Scroll to top'))),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2.5),
            child: _progress > 0 && _progress < 100
                ? LinearProgressIndicator(
                    minHeight: 2.5,
                    value: _progress / 100,
                    color: AppColors.sage,
                  )
                : const SizedBox(height: 2.5),
          ),
        ),
        body: Column(
          children: [
            Material(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceSubtle
                  : AppColors.sageSoft,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_fix_high_rounded,
                        size: 17, color: AppColors.sage),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Your details are autofilled on application forms.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 11.5),
                      ),
                    ),
                    const Text('Auto-submit',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    Switch(
                      value: _autoSubmit,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (value) async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _autoSubmit = value);
                        final controller = _controller;
                        if (controller != null) {
                          await _injectAutofill(controller);
                        }
                        if (!mounted || !value) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            duration: Duration(seconds: 3),
                            content: Text(
                                'Auto-submit is on — genuine application buttons are '
                                'clicked after autofill. Reload to re-apply.'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest:
                    URLRequest(url: WebUri(_startUrl.toString())),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  cacheEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  transparentBackground: false,
                  supportZoom: true,
                  disableDefaultErrorPage: false,
                ),
                pullToRefreshController: _pullToRefresh,
                onWebViewCreated: (controller) => _controller = controller,
                onLoadStop: (controller, url) async {
                  _pullToRefresh.endRefreshing();
                  if (url != null) {
                    setState(() => _hostLabel = _labelFor(url.uriValue));
                  }
                  await _injectAutofill(controller);
                },
                onReceivedError: (controller, request, error) {
                  _pullToRefresh.endRefreshing();
                },
                onProgressChanged: (controller, progress) {
                  setState(() => _progress = progress.toDouble());
                },
                onConsoleMessage: (controller, message) =>
                    _handleConsoleMessage(message),
                shouldOverrideUrlLoading: (controller, action) async {
                  final scheme = action.request.url?.scheme.toLowerCase();
                  if (scheme == 'mailto' || scheme == 'tel') {
                    await launchUrl(
                      action.request.url!.uriValue,
                      mode: LaunchMode.externalApplication,
                    );
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
