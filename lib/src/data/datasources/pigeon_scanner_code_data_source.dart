import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scanner_code/src/data/datasources/scanner_code_data_source.dart';
import 'package:flutter_scanner_code/src/domain/errors/scanner_code_exception.dart';
import 'package:flutter_scanner_code/src/platform/pigeon/scanner_code_api.g.dart';

/// Uses Pigeon for capture commands and Windows-to-Dart key callbacks.
final class PigeonScannerCodeDataSource
    implements ScannerCodeDataSource, ScannerCodeFlutterApi {
  /// Creates the default Windows transport.
  PigeonScannerCodeDataSource();

  static PigeonScannerCodeDataSource? _activeSource;

  final _api = ScannerCodeHostApi();
  final _keys = StreamController<ScannerKeyInfo>.broadcast(sync: true);
  final _barcodes =
      StreamController<({String code, String devicePath})>.broadcast(
        sync: true,
      );

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  Stream<ScannerKeyInfo> get keys => _keys.stream;

  @override
  Stream<({String code, String devicePath})> get barcodes => _barcodes.stream;

  @override
  Future<List<ScannerDeviceInfo>> listDevices() =>
      _invoke(_api.listKeyboardDevices);

  @override
  Future<ScannerInputPolicyResultData> configureInputPolicy(
    String? devicePath,
  ) => _invoke(
    () => _api.configureInputPolicy(
      ScannerInputPolicyData(devicePath: devicePath),
    ),
  );

  @override
  Future<void> startCapture() async {
    _ensureSupported();
    if (_activeSource != null && _activeSource != this) {
      throw const ScannerCodeException(
        code: 'capture_already_active',
        message: 'Another keyboard capture service is already active.',
      );
    }

    final wasActive = _activeSource == this;
    _activeSource = this;
    ScannerCodeFlutterApi.setUp(this);
    try {
      await _invoke(_api.startCapture);
    } on Object {
      if (!wasActive) {
        _activeSource = null;
        ScannerCodeFlutterApi.setUp(null);
      }
      rethrow;
    }
  }

  @override
  Future<void> stopCapture() => _invoke(_api.stopCapture);

  @override
  void onKeyPressed(ScannerKeyInfo key) => _keys.add(key);

  @override
  void onBarcode(String code, String devicePath) {
    _barcodes.add((code: code, devicePath: devicePath));
  }

  @override
  Future<void> dispose() async {
    try {
      if (_activeSource == this) await _invoke(_api.stopCapture);
    } finally {
      if (_activeSource == this) {
        _activeSource = null;
        ScannerCodeFlutterApi.setUp(null);
      }
      await _keys.close();
      await _barcodes.close();
    }
  }

  Future<T> _invoke<T>(Future<T> Function() operation) async {
    _ensureSupported();
    try {
      return await operation();
    } on PlatformException catch (error) {
      throw ScannerCodeException(
        code: error.code,
        message: error.message ?? 'Windows could not complete the operation.',
      );
    } on MissingPluginException {
      throw const ScannerCodeException(
        code: 'plugin_not_registered',
        message: 'The Windows keyboard capture plugin is not registered.',
      );
    }
  }

  void _ensureSupported() {
    if (!isSupported) {
      throw const ScannerCodeException(
        code: 'unsupported_platform',
        message: 'Keyboard capture is available on Windows.',
      );
    }
  }
}
