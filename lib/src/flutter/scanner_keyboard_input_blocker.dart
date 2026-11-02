import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scanner_code/src/domain/entities/scanner_code_device.dart';
import 'package:flutter_scanner_code/src/domain/entities/scanner_code_key_event.dart';
import 'package:flutter_scanner_code/src/domain/services/scanner_code_service.dart';

/// Blocks Flutter key-downs produced by one selected physical keyboard.
///
/// Create one active blocker per Flutter application window. Call [start]
/// before the service starts capturing keys, update the selected device with
/// [setBlockedDeviceId], and call [dispose] when the owner is removed.
///
/// It consumes key-down and repeat events only when a recent native event
/// identifies the selected device. Key-up, synthesized, and uncorrelated events
/// pass through.
///
/// This class only filters Flutter key events. It does not configure barcode
/// collection or suppress input in the operating system.
final class ScannerKeyboardInputBlocker {
  /// Creates a blocker that correlates Flutter events with [service] events.
  factory ScannerKeyboardInputBlocker({
    required ScannerCodeService service,
  }) {
    return ScannerKeyboardInputBlocker._(service);
  }

  ScannerKeyboardInputBlocker._(this._service);

  static const Duration _correlationWindow = Duration(milliseconds: 150);
  static const int _maxPendingSources = 32;
  static ScannerKeyboardInputBlocker? _activeBlocker;

  final ScannerCodeService _service;
  final Queue<_PendingKeySource> _pendingSources = Queue<_PendingKeySource>();
  late final OnKeyEventCallback _keyEventHandler = _onFlutterKeyEvent;
  StreamSubscription<ScannerCodeKeyEvent>? _keySubscription;
  String? _blockedDeviceId;
  bool _started = false;
  bool _disposed = false;

  /// Starts listening for device origins and registers a global Flutter hook.
  ///
  /// This method is idempotent. Start it before [ScannerCodeService.start] so
  /// the first native key event can be correlated with its Flutter event.
  void start() {
    _ensureNotDisposed();
    if (_started) return;

    final activeBlocker = _activeBlocker;
    if (activeBlocker != null && !identical(activeBlocker, this)) {
      throw StateError(
        'Only one ScannerKeyboardInputBlocker can be active per window.',
      );
    }

    FocusManager.instance.addEarlyKeyEventHandler(_keyEventHandler);
    try {
      _keySubscription = _service.keyEvents.listen(_onNativeKeyEvent);
      _activeBlocker = this;
      _started = true;
    } on Object {
      FocusManager.instance.removeEarlyKeyEventHandler(_keyEventHandler);
      rethrow;
    }
  }

  /// Selects which device's key-down and repeat events Flutter should consume.
  ///
  /// Pass the selected [ScannerCodeDevice.deviceId], or `null` to allow every
  /// keyboard. Changing the selection discards pending source correlations.
  void setBlockedDeviceId(String? deviceId) {
    _ensureNotDisposed();
    if (_blockedDeviceId == deviceId) return;

    _blockedDeviceId = deviceId;
    _pendingSources.clear();
  }

  /// Removes the Flutter hook and stops listening for device origins.
  ///
  /// The selected device ID is retained so the blocker can be started again.
  Future<void> stop() async {
    if (!_started) return;

    _started = false;
    FocusManager.instance.removeEarlyKeyEventHandler(_keyEventHandler);
    _pendingSources.clear();
    if (identical(_activeBlocker, this)) _activeBlocker = null;

    await _keySubscription?.cancel();
    _keySubscription = null;
  }

  /// Stops the blocker and prevents it from being started again.
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    await stop();
  }

  void _onNativeKeyEvent(ScannerCodeKeyEvent event) {
    if (!_started) return;

    final receivedAt = DateTime.now();
    _discardExpiredSources(receivedAt);
    if (_pendingSources.length == _maxPendingSources) {
      _pendingSources.removeFirst();
    }
    _pendingSources.addLast(
      _PendingKeySource(deviceId: event.deviceId, receivedAt: receivedAt),
    );
  }

  KeyEventResult _onFlutterKeyEvent(KeyEvent event) {
    if (!_started ||
        event.synthesized ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }

    final source = _takeNextSource();
    if (source == null || source.deviceId != _blockedDeviceId) {
      return KeyEventResult.ignored;
    }

    return KeyEventResult.handled;
  }

  _PendingKeySource? _takeNextSource() {
    _discardExpiredSources(DateTime.now());
    if (_pendingSources.isEmpty) return null;

    return _pendingSources.removeFirst();
  }

  void _discardExpiredSources(DateTime now) {
    while (_pendingSources.isNotEmpty &&
        now.difference(_pendingSources.first.receivedAt) > _correlationWindow) {
      _pendingSources.removeFirst();
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('Create a new blocker after disposing this one.');
    }
  }
}

final class _PendingKeySource {
  const _PendingKeySource({required this.deviceId, required this.receivedAt});

  final String deviceId;
  final DateTime receivedAt;
}
