import 'package:finamp/app.dart' show FinampErrorApp, JellyampApp;
import 'package:finamp/bootstrap/bootstrap.dart' show JellyampDependencies, TestingPathProvider, bootstrap;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

// Re-exported so the integration-test harness and a few components can keep
// constructing these symbols via `package:finamp/main.dart`.
export 'app.dart' show Finamp, FinampScrollBehavior;

/// Boring application entry point: perform startup, then mount the app tree.
///
/// P0.4: all startup work now lives in `bootstrap()`; this function only
/// handles the test path redirect, maps a fatal startup failure to the startup
/// error app, and calls [runApp].
Future<void> main(List<String> args, {bool integrationTesting = false, bool loginTesting = false}) async {
  if (loginTesting) {
    // Note that download baseDirectories cannot be redirected, so use of this flag
    // causes errors in downloader on mobile platforms
    final data = await TestingPathProvider.baseDirectory();
    PathProviderPlatform.instance = TestingPathProvider(data);
    if (data.existsSync()) {
      data.deleteSync(recursive: true);
    }
  }

  final dependencies = await _startup(args, integrationTesting: integrationTesting);
  if (dependencies == null) return;

  if (!integrationTesting) {
    runApp(JellyampApp(dependencies: dependencies));
  }
}

/// Runs the startup sequence. A fatal startup error shows the startup error
/// app and returns null (original behavior); when integration testing the error
/// is rethrown so the harness can fail the run.
Future<JellyampDependencies?> _startup(List<String> args, {required bool integrationTesting}) async {
  try {
    return await bootstrap(commandLineArgs: args, integrationTesting: integrationTesting);
  } catch (error, trace) {
    if (!integrationTesting) {
      Logger("ErrorApp").severe(error, null, trace);
      runApp(FinampErrorApp(error: error, trace: trace));
      return null;
    } else {
      rethrow;
    }
  }
}
