import 'package:flutter_scanner_code/src/domain/entities/scanner_code_device_identity.dart';

/// A complete barcode emitted by a keyboard-style scanner after its Enter key.
final class ScannerCodeBarcode {
  /// Creates a barcode with the identity of its source keyboard device.
  const ScannerCodeBarcode({required this.code, required this.identity});

  /// Complete scanned value, without the trailing Enter key.
  final String code;

  /// Raw Input identity of the device that produced the barcode.
  final ScannerCodeDeviceIdentity identity;

  /// Stable identifier derived from the source device's available attributes.
  String get deviceId => identity.deviceId;

  /// Original Windows path of the source device.
  String get devicePath => identity.devicePath;
}
