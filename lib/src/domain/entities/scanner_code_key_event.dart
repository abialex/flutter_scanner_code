import 'package:flutter_scanner_code/src/domain/entities/scanner_code_device_identity.dart';

/// A physical key-down event received from Windows Raw Input.
final class ScannerCodeKeyEvent {
  /// Creates a captured key event with its Windows device identifier.
  const ScannerCodeKeyEvent({
    required this.virtualKey,
    required this.identity,
    this.deviceName = '',
    this.deviceManufacturer = '',
    this.deviceTransport = '',
  });

  /// Windows virtual-key code for the pressed key.
  final int virtualKey;

  /// Attributes of the Raw Input device that produced the key.
  final ScannerCodeDeviceIdentity identity;

  /// Friendly name matched from the most recently listed devices.
  ///
  /// Empty when Windows did not provide a matching listed device.
  final String deviceName;

  /// Manufacturer matched from the most recently listed devices, if available.
  final String deviceManufacturer;

  /// Transport matched from the most recently listed devices, if available.
  final String deviceTransport;

  /// Composite device identifier derived from [identity].
  String get deviceId => identity.deviceId;

  /// Original Windows device path, useful for diagnostics.
  String get devicePath => identity.devicePath;
}
