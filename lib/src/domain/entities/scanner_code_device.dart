import 'package:flutter_scanner_code/src/domain/entities/scanner_code_device_identity.dart';

/// A keyboard input device currently exposed by Windows Raw Input.
final class ScannerCodeDevice {
  /// Creates a device snapshot.
  const ScannerCodeDevice({
    required this.identity,
    required this.displayName,
    required this.wasLastInput,
    this.manufacturer = '',
    this.transport = '',
  });

  /// Hardware attributes used to identify this device across Raw Input events.
  final ScannerCodeDeviceIdentity identity;

  /// Composite identifier derived from [identity].
  String get deviceId => identity.deviceId;

  /// Original Windows device path, useful for diagnostics.
  String get devicePath => identity.devicePath;

  /// Windows-friendly device name, when its Plug and Play node provides one.
  final String displayName;

  /// Device manufacturer reported by Windows, when it is meaningful.
  final String manufacturer;

  /// Connection type reported by the Windows device hierarchy.
  ///
  /// Common values are `USB`, `Bluetooth`, and `Virtual`.
  final String transport;

  /// Whether this device most recently generated a captured key.
  final bool wasLastInput;
}
