import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _signingIn = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
      // AppState's auth listener picks up the session and moves the flow on
      // to onboarding, so nothing else is needed here.
    } on GoogleSignInCancelledException {
      // User backed out; just reset the button.
    } catch (error) {
      if (mounted) {
        setState(() => _error = AuthService.signInErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _signingIn ? null : _signInWithGoogle,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line),
          elevation: 0,
        ),
        icon: _signingIn
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : SizedBox(
                width: 18,
                height: 18,
                child: CustomPaint(painter: _GoogleLogoPainter()),
              ),
        label: const Text(
          'Continue with Google',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 46),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LoginWordmark(),
                    const Spacer(),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.sageSoft,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.lock_open_rounded,
                        size: 22,
                        color: AppColors.sage,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('Welcome.',
                        style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 10),
                    Text(
                      'Sign in with Google to start building resumes that fit '
                      'the work you want.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.stone),
                    ),
                    const SizedBox(height: 28),
                    _buildGoogleButton(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 16, color: AppColors.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'A private workspace for your career story.',
                        style:
                            TextStyle(fontSize: 11.5, color: AppColors.stone),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;

    final Path blue = Path()
      ..moveTo(w * .98, h * .51)
      ..cubicTo(w * .98, h * .48, w * .97, h * .45, w * .96, h * .42)
      ..lineTo(w * .5, h * .42)
      ..lineTo(w * .5, h * .59)
      ..lineTo(w * .77, h * .59)
      ..cubicTo(w * .76, h * .65, w * .72, h * .7, w * .66, h * .74)
      ..lineTo(w * .8, h * .85)
      ..cubicTo(w * .91, h * .75, w * .98, h * .64, w * .98, h * .51)
      ..close();
    canvas.drawPath(blue, Paint()..color = const Color(0xFF4285F4));

    final Path green = Path()
      ..moveTo(w * .5, h * .99)
      ..cubicTo(w * .63, h * .99, w * .74, h * .95, w * .81, h * .86)
      ..lineTo(w * .67, h * .75)
      ..cubicTo(w * .62, h * .78, w * .56, h * .8, w * .5, h * .8)
      ..cubicTo(w * .37, h * .8, w * .25, h * .71, w * .22, h * .58)
      ..lineTo(w * .07, h * .69)
      ..cubicTo(w * .17, h * .88, w * .32, h * .99, w * .5, h * .99)
      ..close();
    canvas.drawPath(green, Paint()..color = const Color(0xFF34A853));

    final Path yellow = Path()
      ..moveTo(w * .22, h * .58)
      ..cubicTo(w * .21, h * .55, w * .2, h * .53, w * .2, h * .5)
      ..cubicTo(w * .2, h * .47, w * .21, h * .45, w * .22, h * .42)
      ..lineTo(w * .07, h * .31)
      ..cubicTo(w * .04, h * .38, w * .02, h * .44, w * .02, h * .5)
      ..cubicTo(w * .02, h * .56, w * .04, h * .62, w * .07, h * .69)
      ..close();
    canvas.drawPath(yellow, Paint()..color = const Color(0xFFFBBC05));

    final Path red = Path()
      ..moveTo(w * .5, h * .21)
      ..cubicTo(w * .57, h * .21, w * .63, h * .23, w * .68, h * .28)
      ..lineTo(w * .81, h * .15)
      ..cubicTo(w * .73, h * .07, w * .62, h * .02, w * .5, h * .02)
      ..cubicTo(w * .32, h * .02, w * .17, h * .12, w * .07, h * .31)
      ..lineTo(w * .22, h * .42)
      ..cubicTo(w * .25, h * .29, w * .36, h * .21, w * .5, h * .21)
      ..close();
    canvas.drawPath(red, Paint()..color = const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginWordmark extends StatelessWidget {
  const _LoginWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Text(
            'R',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            'Resumer',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
