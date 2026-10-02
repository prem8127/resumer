import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';

import '../data/app_state.dart';
import '../services/ai_interview_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/route_utils.dart';
import 'career_profile_screen.dart';
import 'resumes_screen.dart';

/// Runs a mock AI interview for the configuration chosen on the setup
/// screen: fetches AI-generated questions, then steps through them one at a
/// time with a free-text answer box.
class AiInterviewScreen extends StatefulWidget {
  const AiInterviewScreen({
    super.key,
    required this.targetRole,
    required this.experienceLevel,
    required this.interviewType,
    required this.questionCount,
    AiInterviewService? service,
  }) : _service = service;

  final String targetRole;
  final String experienceLevel;
  final String interviewType;
  final int questionCount;
  final AiInterviewService? _service;

  @override
  State<AiInterviewScreen> createState() => _AiInterviewScreenState();
}

enum _LoadState { loading, error, ready }

/// Status of the post-interview AI analysis (scoring + summary) that runs
/// once the candidate finishes answering.
enum _AnalysisState { analyzing, done, failed }

class _AiInterviewScreenState extends State<AiInterviewScreen> {
  late final AiInterviewService _service =
      widget._service ?? AiInterviewService();
  late final bool _ownsService = widget._service == null;

  _LoadState _loadState = _LoadState.loading;
  String? _errorMessage;
  List<InterviewQuestion> _questions = const [];

  int _index = 0;
  final List<String> _answers = [];
  final TextEditingController _answerController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FlutterTts _questionVoice = FlutterTts();
  StreamSubscription<Uint8List>? _audioSubscription;
  final List<Uint8List> _audioChunks = [];
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _finished = false;

  _AnalysisState? _analysisState;
  int? _score;
  String? _summary;
  bool _savedToCareerProfile = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _answerController.dispose();
    unawaited(_audioSubscription?.cancel());
    unawaited(_audioRecorder.dispose());
    unawaited(_questionVoice.stop());
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  Future<void> _speakQuestion() async {
    try {
      await _questionVoice.setLanguage('en-US');
      await _questionVoice.setSpeechRate(0.48);
      await _questionVoice.speak(_questions[_index].text);
    } on Object {
      _showMessage('Question audio is unavailable on this device.');
    }
  }

  Future<void> _startVoiceAnswer() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        _showMessage('Allow microphone access to speak your answer.');
        return;
      }
      _audioChunks.clear();
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _audioSubscription = stream.listen(
        _audioChunks.add,
        onError: (_) {
          if (mounted) setState(() => _isRecording = false);
        },
      );
      if (mounted) setState(() => _isRecording = true);
    } on Object {
      _showMessage('Could not start the microphone. Try again.');
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (!_isRecording || _isTranscribing) return;
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });
    try {
      await _audioRecorder.stop();
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      final pcm = BytesBuilder(copy: false);
      for (final chunk in _audioChunks) {
        pcm.add(chunk);
      }
      final bytes = pcm.takeBytes();
      if (bytes.isEmpty) {
        throw const AiInterviewException('No audio was recorded. Try again.');
      }
      final transcript = await _service.transcribeAnswer(_waveFile(bytes));
      if (!mounted) return;
      final previous = _answerController.text.trim();
      _answerController.text =
          previous.isEmpty ? transcript : '$previous\n$transcript';
      _answerController.selection = TextSelection.collapsed(
        offset: _answerController.text.length,
      );
      _showMessage('Transcript added. Review it before continuing.');
    } on AiInterviewException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) {
        _showMessage('Could not transcribe the recording. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Uint8List _waveFile(Uint8List pcm) {
    final bytes = ByteData(44 + pcm.length);
    void writeTag(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeTag(0, 'RIFF');
    bytes.setUint32(4, 36 + pcm.length, Endian.little);
    writeTag(8, 'WAVE');
    writeTag(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, 16000, Endian.little);
    bytes.setUint32(28, 32000, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    writeTag(36, 'data');
    bytes.setUint32(40, pcm.length, Endian.little);
    bytes.buffer.asUint8List().setRange(44, 44 + pcm.length, pcm);
    return bytes.buffer.asUint8List();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loadState = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final questions = await _service.generateQuestions(
        targetRole: widget.targetRole,
        experienceLevel: widget.experienceLevel,
        interviewType: widget.interviewType,
        questionCount: widget.questionCount,
      );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _answers
          ..clear()
          ..addAll(List.filled(questions.length, ''));
        _loadState = _LoadState.ready;
      });
    } on AiInterviewException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _loadState = _LoadState.error;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong generating your questions.';
        _loadState = _LoadState.error;
      });
    }
  }

  void _saveCurrentAnswer() {
    if (_index < _answers.length) {
      _answers[_index] = _answerController.text.trim();
    }
  }

  void _nextQuestion() {
    _saveCurrentAnswer();
    if (_index + 1 < _questions.length) {
      setState(() {
        _index++;
        _answerController.text = _answers[_index];
      });
    } else {
      _finishInterview();
    }
  }

  void _finishInterview() {
    _saveCurrentAnswer();
    setState(() {
      _finished = true;
      _analysisState = _AnalysisState.analyzing;
    });
    unawaited(_analyzeAndSave());
  }

  /// Scores the transcript with AI, then saves the interview to the career
  /// profile either way. If AI analysis fails (network error, malformed
  /// response, timeout, etc.), the candidate's answers are still saved —
  /// just without a score or AI summary.
  Future<void> _analyzeAndSave() async {
    try {
      final analysis = await _service.analyzeInterview(
        targetRole: widget.targetRole,
        interviewType: widget.interviewType,
        questions: [for (final q in _questions) q.text],
        answers: _answers,
      );
      if (!mounted) return;
      setState(() {
        _score = analysis.score;
        _summary = analysis.summary;
        _analysisState = _AnalysisState.done;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _analysisState = _AnalysisState.failed);
    }
    _saveToCareerProfile();
  }

  /// Records this interview as career evidence exactly once per attempt,
  /// regardless of whether AI analysis succeeded.
  void _saveToCareerProfile() {
    if (_savedToCareerProfile || !mounted) return;
    _savedToCareerProfile = true;
    AppScope.of(context).recordInterviewResult(
      targetRole: widget.targetRole,
      interviewType: widget.interviewType,
      questions: [for (final q in _questions) q.text],
      answers: _answers,
      score: _score,
      summary: _summary,
    );
  }

  void _restart() {
    setState(() {
      _index = 0;
      _answers.clear();
      _answerController.clear();
      _finished = false;
      _analysisState = null;
      _score = null;
      _summary = null;
      _savedToCareerProfile = false;
    });
    _loadQuestions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _loadState == _LoadState.ready && !_finished
              ? 'Question ${_index + 1}/${_questions.length}'
              : 'AI Interview',
        ),
      ),
      body: SafeArea(
        top: false,
        child: switch (_loadState) {
          _LoadState.loading => const _LoadingView(),
          _LoadState.error => _ErrorView(
              message: _errorMessage ?? 'Something went wrong.',
              onRetry: _loadQuestions,
            ),
          _LoadState.ready =>
            _finished ? _buildSummary(context) : _buildInterview(context),
        },
      ),
    );
  }

  Widget _buildInterview(BuildContext context) {
    final question = _questions[_index];
    final isLast = _index + 1 == _questions.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _index / _questions.length,
              minHeight: 6,
              backgroundColor: AppColors.sageSoft,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            physics: const BouncingScrollPhysics(),
            children: [
              if (question.focusArea != null) ...[
                Chip(
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 14),
                  label: Text(question.focusArea!),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                question.text,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTranscribing ? null : _speakQuestion,
                    icon: const Icon(Icons.volume_up_outlined),
                    label: const Text('Listen to question'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _isTranscribing
                        ? null
                        : _isRecording
                            ? _stopAndTranscribe
                            : _startVoiceAnswer,
                    icon: Icon(
                      _isTranscribing
                          ? Icons.hourglass_top_rounded
                          : _isRecording
                              ? Icons.stop_rounded
                              : Icons.mic_none_rounded,
                    ),
                    label: Text(
                      _isTranscribing
                          ? 'Transcribing…'
                          : _isRecording
                              ? 'Stop & transcribe'
                              : 'Speak your answer',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isRecording
                    ? 'Recording… tap stop when you finish.'
                    : 'Your recording is sent for transcription and is not saved. Review the transcript before continuing.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _answerController,
                minLines: 6,
                maxLines: 12,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Type your answer here...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _isRecording || _isTranscribing ? null : _nextQuestion,
                child: Text(isLast ? 'Finish interview' : 'Next question'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final answeredCount =
        _answers.where((answer) => answer.trim().isNotEmpty).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        const Icon(Icons.emoji_events_rounded,
            size: 52, color: AppColors.orange),
        const SizedBox(height: 16),
        Text('Interview complete',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'You answered $answeredCount of ${_questions.length} questions for '
          '${widget.targetRole}.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        _AnalysisCard(
          state: _analysisState,
          score: _score,
          summary: _summary,
        ),
        if (_savedToCareerProfile) ...[
          const SizedBox(height: 12),
          _CareerNextStepsRow(
            onViewCareerProfile: () => pushRouteOnce(
              context,
              (_) => Scaffold(
                appBar: AppBar(title: const Text('Career profile')),
                body: const CareerProfileScreen(),
              ),
            ),
            onTailorResume: () => pushRouteOnce(
              context,
              (_) => Scaffold(
                appBar: AppBar(title: const Text('Resumes')),
                body: const ResumesScreen(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        for (var i = 0; i < _questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q${i + 1}. ${_questions[i].text}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _answers[i].isEmpty ? 'No answer given.' : _answers[i],
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil(
                  (route) => route.isFirst,
                ),
                child: const Text('Back to dashboard'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _restart,
                child: const Text('Practice again'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lets the candidate jump straight from a saved interview into the career
/// vault that now holds it, or take the natural next step of putting that
/// fresh evidence to work on their resume. Shown once the interview has
/// actually been saved as career evidence (see [_AiInterviewScreenState._savedToCareerProfile]),
/// regardless of whether AI scoring itself succeeded.
class _CareerNextStepsRow extends StatelessWidget {
  const _CareerNextStepsRow({
    required this.onViewCareerProfile,
    required this.onTailorResume,
  });

  final VoidCallback onViewCareerProfile;
  final VoidCallback onTailorResume;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onViewCareerProfile,
            icon: const Icon(Icons.auto_awesome_mosaic_rounded, size: 18),
            label: const Text('View Career Profile'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onTailorResume,
            icon: const Icon(Icons.description_rounded, size: 18),
            label: const Text('Tailor your resume'),
          ),
        ),
      ],
    );
  }
}

/// Shows AI scoring progress/result under the interview summary. This is a
/// status card only — the interview and the candidate's answers are always
/// saved to the career profile regardless of what this shows.
class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.state,
    required this.score,
    required this.summary,
  });

  final _AnalysisState? state;
  final int? score;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case null:
        return const SizedBox.shrink();
      case _AnalysisState.analyzing:
        return GlassCard(
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Scoring your interview and saving it to your career profile...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      case _AnalysisState.done:
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: AppColors.orange),
                  const SizedBox(width: 8),
                  Text('AI performance score',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 14)),
                  const Spacer(),
                  Text('${score ?? 0}/100',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              if (summary != null && summary!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(summary!, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 6),
              Text('Saved to your career profile.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.stone, fontStyle: FontStyle.italic)),
            ],
          ),
        );
      case _AnalysisState.failed:
        return GlassCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Couldn't score this interview right now, but your "
                  'answers were saved to your career profile.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              'Generating your interview questions...',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Could not generate questions',
      subtitle: message,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}
