/// An error reported by the Windows keyboard capture integration.
final class ScannerCodeException implements Exception {
  /// Creates an integration error with a stable code and readable message.
  const ScannerCodeException({required this.code, required this.message});

  /// Machine-readable reason for the failure.
  final String code;

  /// Description suitable for diagnostics or presentation by the consumer.
  final String message;

  @override
  String toString() => 'ScannerCodeException($code): $message';
}
