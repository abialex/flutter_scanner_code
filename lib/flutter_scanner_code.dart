/// Captures physical keyboard keys and their device origin on Windows.
library;

export 'src/domain/entities/scanner_code_barcode.dart';
export 'src/domain/entities/scanner_code_device.dart';
export 'src/domain/entities/scanner_code_device_identity.dart';
export 'src/domain/entities/scanner_code_key_event.dart';
export 'src/domain/errors/scanner_code_exception.dart';
export 'src/domain/policies/scanner_input_policy.dart';
export 'src/domain/results/scanner_input_policy_result.dart';
export 'src/domain/services/scanner_code_service.dart';
export 'src/flutter/scanner_keyboard_input_blocker.dart';
export 'src/init_scanner_code_service.dart' show initScannerCodeService;
