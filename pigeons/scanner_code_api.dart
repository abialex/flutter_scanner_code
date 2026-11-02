import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform/pigeon/scanner_code_api.g.dart',
    cppOptions: CppOptions(namespace: 'flutter_scanner_code'),
    cppHeaderOut: 'windows/include/flutter_scanner_code/scanner_code_api.g.h',
    cppSourceOut: 'windows/scanner_code_api.g.cpp',
    dartPackageName: 'flutter_scanner_code',
  ),
)
@HostApi()
abstract class ScannerCodeHostApi {
  List<ScannerDeviceInfo> listKeyboardDevices();
  ScannerInputPolicyResultData configureInputPolicy(
    ScannerInputPolicyData policy,
  );
  void startCapture();
  void stopCapture();
}

@FlutterApi()
abstract class ScannerCodeFlutterApi {
  void onKeyPressed(ScannerKeyInfo key);
  void onBarcode(String code, String devicePath);
}

class ScannerDeviceInfo {
  ScannerDeviceInfo({
    required this.devicePath,
    required this.vendorId,
    required this.productId,
    required this.interfaceNumber,
    required this.instanceId,
    required this.collectionId,
    required this.interfaceClassId,
    required this.displayName,
    required this.manufacturer,
    required this.transport,
    required this.wasLastInput,
  });

  String devicePath;
  String vendorId;
  String productId;
  String interfaceNumber;
  String instanceId;
  String collectionId;
  String interfaceClassId;
  String displayName;
  String manufacturer;
  String transport;
  bool wasLastInput;
}

class ScannerKeyInfo {
  ScannerKeyInfo({
    required this.devicePath,
    required this.vendorId,
    required this.productId,
    required this.interfaceNumber,
    required this.instanceId,
    required this.collectionId,
    required this.interfaceClassId,
    required this.virtualKey,
  });

  String devicePath;
  String vendorId;
  String productId;
  String interfaceNumber;
  String instanceId;
  String collectionId;
  String interfaceClassId;
  int virtualKey;
}

enum ScannerInputPolicyStatusData { applied, unsupported }

class ScannerInputPolicyData {
  ScannerInputPolicyData({required this.devicePath});

  String? devicePath;
}

class ScannerInputPolicyResultData {
  ScannerInputPolicyResultData({required this.status, this.message});

  ScannerInputPolicyStatusData status;
  String? message;
}
