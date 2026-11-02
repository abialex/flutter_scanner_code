import 'package:flutter_scanner_code/src/platform/pigeon/scanner_code_api.g.dart';

/// Internal Pigeon transport contract for Windows keyboard events.
abstract interface class ScannerCodeDataSource {
  /// Whether native calls are supported.
  bool get isSupported;

  /// Key-down events received from Windows.
  Stream<ScannerKeyInfo> get keys;

  /// Complete barcode values and their originating Raw Input paths.
  Stream<({String code, String devicePath})> get barcodes;

  /// Lists keyboard devices detected by Windows Raw Input.
  Future<List<ScannerDeviceInfo>> listDevices();

  /// Selects a Raw Input device whose legacy text input should be suppressed.
  Future<ScannerInputPolicyResultData> configureInputPolicy(
    String? devicePath,
  );

  /// Starts receiving raw keyboard input.
  Future<void> startCapture();

  /// Stops receiving raw keyboard input.
  Future<void> stopCapture();

  /// Releases native observation and the Pigeon callback handlers.
  Future<void> dispose();
}
