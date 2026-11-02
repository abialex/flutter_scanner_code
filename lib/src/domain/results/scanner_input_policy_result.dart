import 'package:flutter_scanner_code/src/domain/policies/scanner_input_policy.dart';

/// Outcome of applying a [ScannerInputPolicy].
enum ScannerInputPolicyStatus {
  /// Windows applied the requested policy.
  applied,

  /// The current platform could not enforce the policy.
  unsupported,

  /// The selected device was not present in the latest device list.
  deviceNotFound,
}

/// Result returned after the platform applies an input policy.
final class ScannerInputPolicyResult {
  /// Creates a result with the platform status and optional explanation.
  const ScannerInputPolicyResult({required this.status, this.message});

  /// Whether the policy was applied, unsupported, or used a missing device.
  final ScannerInputPolicyStatus status;

  /// Human-readable details from the platform.
  final String? message;

  /// Whether Windows accepted the policy.
  bool get isApplied => status == ScannerInputPolicyStatus.applied;
}
