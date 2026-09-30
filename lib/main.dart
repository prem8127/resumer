import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_state.dart';
import 'services/auth_service.dart';
import 'services/secure_api_storage.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle Flutter framework-level rendering errors gracefully in production
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) FlutterError.presentError(details);
  };

  // Prevent uncaught asynchronous errors from crashing the application
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };

  // Provide a clean, resilient fallback UI if any individual widget fails to render
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 36,
              ),
              SizedBox(height: 10),
              Text(
                'Something unexpected occurred in this section.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    await AuthService.instance.initialize();
  } catch (error) {
    if (kDebugMode) debugPrint('AuthService initialization failed: $error');
  }

  try {
    await SecureApiStorage.instance.initializeIfMissing();
  } on ApiConfigurationException {
    // A build without RAPIDAPI_KEY can still start and show a safe UI error
    // when search is used. Never include credential values in logs.
    if (kDebugMode) {
      debugPrint('RapidAPI credentials are not configured for this build.');
    }
  } on Object {
    if (kDebugMode) {
      debugPrint('Secure API storage could not be initialized.');
    }
  }

  final state = AppState();
  try {
    await state.load();
  } catch (error) {
    if (kDebugMode) debugPrint('AppState load failed: $error');
  }

  runApp(AppRoot(state: state));
}
