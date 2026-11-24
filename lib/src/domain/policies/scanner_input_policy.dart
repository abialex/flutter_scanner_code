/// Selects the keyboard device used as the barcode input source.
///
/// The current Windows implementation keeps normal text input enabled.
final class ScannerInputPolicy {
  /// Selects [suppressedDeviceId] as the barcode source.
  ///
  /// A null device ID clears the barcode source selection.
  const ScannerInputPolicy({this.suppressedDeviceId});

  /// ID of the selected barcode device.
  ///
  /// The property name is retained for API compatibility; it does not
  /// currently suppress Flutter text input.
  final String? suppressedDeviceId;
}
