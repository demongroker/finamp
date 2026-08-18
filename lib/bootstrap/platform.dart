import 'dart:async';
import 'dart:io';

import 'package:finamp/gen/assets.gen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/keep_screen_on_helper.dart';
import 'package:finamp/services/ui_overlay_setter_observer.dart';
import 'package:finamp/services/widget_bindings_observer_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_user_certificates_android/flutter_user_certificates_android.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../components/global_snackbar.dart';

final _platformLog = Logger("Main()");

/// Configures the system UI overlay style (edge-to-edge on Android, status bar
/// brightness on iOS) before anything else renders.
///
/// P0.4: extracted from `main.dart` (was `_setupEdgeToEdgeOverlayStyle`).
Future<void> setupEdgeToEdgeOverlayStyle() async {
  if (Platform.isAndroid) {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent));
    final binding = WidgetsFlutterBinding.ensureInitialized();
    binding.addObserver(UIOverlaySetterObserver());
  } else if (Platform.isIOS) {
    // On iOS, the status bar will have black icons by default on the login
    // screen as it does not have an AppBar. To fix this, we set the
    // brightness to dark manually on startup.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarBrightness: Brightness.dark));
  }
}

/// Extends the default security context to trust Android user certificates.
///
/// P0.4: extracted from `main.dart` (was `_trustAndroidUserCerts`).
Future<void> trustAndroidUserCerts() async {
  if (!Platform.isAndroid) return;
  // Extend the default security context to trust Android user certificates.
  // This is a workaround for <https://github.com/dart-lang/sdk/issues/50435>.
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // SecurityContext.defaultContext seems to cause a native crash on Linux in some environments?
    await FlutterUserCertificatesAndroid().trustAndroidUserCertificates(SecurityContext.defaultContext);
    _platformLog.info("Trusted Android user certs");
  } catch (e) {
    Logger("AndroidCertTrust").severe("Failed to trust certificates: $e", e);
    GlobalSnackbar.error("Failed to trust user certificates: $e");
  }
}

/// Performs OS-specific integration setup: window manager on desktop, album
/// image asset for Android Auto, and native theme mode channel on Android.
///
/// P0.4: extracted from `main.dart` (was `_setupOSIntegration`).
Future<void> setupOSIntegration(List<String> commandLineArgs) async {
  // set up window manager on desktop, mainly to restrict minimum size
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final screenSize = FinampSettingsHelper.finampSettings.screenSize;
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      size: screenSize?.size ?? Size(1200, 800),
      center: screenSize == null,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      minimumSize: Size(400, 250),
      // This matches the size of the iPhone 5, which is probably the smallest screen size worth testing against
      //minimumSize: Size(336, 607),
    );
    unawaited(
      WindowManager.instance.waitUntilReadyToShow(windowOptions, () async {
        if (screenSize != null) {
          await windowManager.setPosition(screenSize.location);
        }
        GetIt.instance<ProviderContainer>().listen(brightnessProvider, fireImmediately: true, (_, brightness) {
          windowManager.setBrightness(brightness);
        });
        if (commandLineArgs.contains("--fullscreen")) {
          await windowManager.setFullScreen(true);
        }
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  // Load the album image from assets and save it to the documents directory for use in Android Auto
  final applicationSupportDirectory = await getApplicationSupportDirectory();
  final albumImageFile = File(
    path_helper.join(applicationSupportDirectory.absolute.path, Assets.images.albumWhite.path),
  );
  if (!(await albumImageFile.exists())) {
    final albumImageBytes = await rootBundle.load(Assets.images.albumWhite.path);
    final albumBuffer = albumImageBytes.buffer;
    await albumImageFile.create(recursive: true);
    await albumImageFile.writeAsBytes(
      albumBuffer.asUint8List(albumImageBytes.offsetInBytes, albumImageBytes.lengthInBytes),
    );
  }

  if (Platform.isAndroid) {
    var themeModeChannel = MethodChannel("com.unicornsonlsd.finamp/set_native_theme");
    GetIt.instance<ProviderContainer>().listen(finampSettingsProvider.themeMode, (_, mode) {
      _platformLog.info("Setting android native theme to $mode");
      themeModeChannel.invokeMethod("setNativeThemeMode", {
        "targetMode": switch (mode) {
          ThemeMode.system => 0,
          ThemeMode.light => 1,
          ThemeMode.dark => 2,
        },
      });
      // Fire on startup to correct desyncs and apply migration
    }, fireImmediately: true);
  }
}

/// Registers the [KeepScreenOnHelper] singleton.
///
/// P0.4: extracted from `main.dart` (was `_setupKeepScreenOnHelper`).
Future<void> setupKeepScreenOnHelper() async {
  GetIt.instance.registerSingleton(KeepScreenOnHelper());
}
