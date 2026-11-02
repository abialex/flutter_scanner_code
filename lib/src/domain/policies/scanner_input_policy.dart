/// Desired input behavior for a captured scanner device.
final class ScannerInputPolicy {
  /// Creates a policy that suppresses text input from [suppressedDeviceId].
  ///
  /// A null device ID clears the suppression selection.
  const ScannerInputPolicy({this.suppressedDeviceId});

  /// ID of the device whose keyboard text input should be suppressed.
  final String? suppressedDeviceId;
}
