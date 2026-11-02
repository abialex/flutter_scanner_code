import 'package:flutter_scanner_code/src/data/datasources/pigeon_scanner_code_data_source.dart';
import 'package:flutter_scanner_code/src/data/services/scanner_code_service_impl.dart';
import 'package:flutter_scanner_code/src/domain/services/scanner_code_service.dart';

/// Creates the default scanner service for the current Flutter platform.
ScannerCodeService initScannerCodeService() => ScannerCodeServiceImpl(
  PigeonScannerCodeDataSource(),
);
