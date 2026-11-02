import 'package:flutter_scanner_code/src/domain/entities/scanner_code_barcode.dart';
import 'package:flutter_scanner_code/src/domain/entities/scanner_code_device.dart';
import 'package:flutter_scanner_code/src/domain/entities/scanner_code_key_event.dart';
import 'package:flutter_scanner_code/src/domain/policies/scanner_input_policy.dart';
import 'package:flutter_scanner_code/src/domain/results/scanner_input_policy_result.dart';

/// Streams physical keyboard keys captured by the Windows platform plugin.
abstract interface class ScannerCodeService {
  /// Whether the current platform supports native capture.
  bool get isSupported;

  /// Key-down events from observed keyboards, including their device ID and
  /// descriptive metadata matched from the latest device list.
  Stream<ScannerCodeKeyEvent> get keyEvents;

  /// Complete barcode values emitted when Windows receives Enter from a device.
  ///
  /// Each value carries its source identity so consumers can filter it by the
  /// selected device.
  Stream<ScannerCodeBarcode> get barcodeEvents;

  /// Lists keyboard devices currently detected by Windows Raw Input.
  ///
  /// Refreshes the metadata used to add a source name to [keyEvents].
  Future<List<ScannerCodeDevice>> listDevices();

  /// Applies the selected-device text input policy.
  Future<ScannerInputPolicyResult> configureInputPolicy(
    ScannerInputPolicy policy,
  );

  /// Starts forwarding each physical key-down event from Windows.
  ///
  /// Loads the device list first when no metadata has been loaded yet.
  Future<void> start();

  /// Stops forwarding key events while keeping the service reusable.
  Future<void> stop();

  /// Stops native capture and closes its streams.
  Future<void> dispose();
}
