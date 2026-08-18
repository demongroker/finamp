// JellyAmp post-1.1 regression: CONSERVATIVE OFFLINE CLASSIFICATION.
//
// Drives the REAL connectivity classification logic end-to-end against a clean
// signal record:
//   - ServerRequestSignals (the real rolling-window signal store)
//   - classifyConnectivity (the real pure classifier that
//     ConnectivityStateNotifier._computeState delegates to)
//   - the real offlineFailureThreshold constant
//
// The bug it guards: a genuinely-ONLINE user (server reachable) tripped the
// OFFLINE banner and got auto-pulled into Offline Mode after just 3 consecutive
// request failures. These cases assert the fix - reachable-but-flaky reads as
// DEGRADED, transient blips stay ONLINE, and only sustained unreachability
// (20+ consecutive failures with zero success in the window) reads OFFLINE,
// while real offline still falls back.
//
// Run:  flutter test benchmark/regression_connectivity_threshold_test.dart
import 'package:finamp/services/connectivity_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final signals = ServerRequestSignals.instance;

  /// Classifies the current signal record with sane defaults (interface up,
  /// no manual offline choice).
  ConnectivityState classify({bool interfaceDown = false, bool manualOffline = false}) =>
      classifyConnectivity(
        signals,
        networkInterfaceDown: interfaceDown,
        manualOffline: manualOffline,
      );

  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    signals.reset();
  });

  test('empty signal record (startup) reads ONLINE', () {
    expect(classify(), ConnectivityState.online);
  });

  test(
      '3 consecutive failures (the old false-OFFLINE case) stays ONLINE - '
      'transient blip must not trip OFFLINE', () {
    for (var i = 0; i < 3; i++) {
      signals.record(success: false, timeout: true);
    }
    expect(signals.failures, 3);
    expect(signals.allRecentFailed, isTrue);
    // Old bug: failures>=3 && allRecentFailed -> OFFLINE. Now needs 20.
    expect(signals.consecutiveFailures, 3);
    expect(classify(), isNot(ConnectivityState.offline));
    expect(classify(), ConnectivityState.online);
  });

  test('a handful of failures (e.g. 10) still stays ONLINE', () {
    for (var i = 0; i < 10; i++) {
      signals.record(success: false, timeout: true);
    }
    expect(signals.consecutiveFailures, 10);
    expect(signals.consecutiveFailures, lessThan(offlineFailureThreshold));
    expect(classify(), ConnectivityState.online);
  });

  test('sustained unreachability (20+ consecutive, no success) -> OFFLINE',
      () {
    for (var i = 0; i < offlineFailureThreshold; i++) {
      signals.record(success: false, timeout: false);
    }
    expect(signals.allRecentFailed, isTrue);
    expect(signals.consecutiveFailures, offlineFailureThreshold);
    expect(classify(), ConnectivityState.offline);
  });

  test(
      'reachable-but-flaky (success then many failures) reads DEGRADED, '
      'NOT OFFLINE - success must not age out after a few failures', () {
    // One success, then 20 failures. The server WAS reachable recently.
    signals.record(success: true, timeout: false);
    for (var i = 0; i < offlineFailureThreshold; i++) {
      signals.record(success: false, timeout: true);
    }
    // Even though 20 consecutive failures piled up, a success is still in the
    // window -> reachable, so DEGRADED (high failure rate), never OFFLINE.
    expect(signals.hasRecentSuccess, isTrue);
    expect(signals.consecutiveFailures, offlineFailureThreshold);
    expect(classify(), isNot(ConnectivityState.offline));
    expect(classify(), ConnectivityState.degraded);
  });

  test(
      'success aged out only after the FULL window is failures (40) -> '
      'then OFFLINE', () {
    // Fill the window entirely with failures so the earlier success is evicted.
    for (var i = 0; i < requestSignalWindowSize; i++) {
      signals.record(success: false, timeout: false);
    }
    expect(signals.allRecentFailed, isTrue);
    expect(signals.consecutiveFailures, requestSignalWindowSize);
    expect(classify(), ConnectivityState.offline);
  });

  test('flaky with high failure rate but frequent successes -> DEGRADED', () {
    // 30 failures + 10 successes (rate 0.75): reachable but unreliable.
    for (var i = 0; i < 30; i++) {
      signals.record(success: false, timeout: true);
    }
    for (var i = 0; i < 10; i++) {
      signals.record(success: true, timeout: false);
    }
    expect(signals.hasRecentSuccess, isTrue);
    expect(signals.failureRate, greaterThanOrEqualTo(degradedFailureRate));
    expect(classify(), ConnectivityState.degraded);
  });

  test('manual offline choice stays authoritative (OFFLINE)', () {
    signals.record(success: true, timeout: false);
    expect(classify(manualOffline: true), ConnectivityState.offline);
  });

  test('no usable network interface -> OFFLINE', () {
    signals.record(success: true, timeout: false);
    expect(classify(interfaceDown: true), ConnectivityState.offline);
  });
}
