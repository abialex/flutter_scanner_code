/// Windows attributes that identify one Raw Input keyboard interface.
final class ScannerCodeDeviceIdentity {
  /// Creates a device identity from its native attributes.
  const ScannerCodeDeviceIdentity({
    required this.devicePath,
    required this.vendorId,
    required this.productId,
    required this.interfaceNumber,
    required this.instanceId,
    required this.collectionId,
    required this.interfaceClassId,
  });

  /// Original Raw Input path, retained for diagnostics and as a fallback.
  final String devicePath;

  /// USB or HID vendor identifier without the `VID_` prefix.
  final String vendorId;

  /// USB or HID product identifier without the `PID_` prefix.
  final String productId;

  /// HID interface number without the `MI_` prefix.
  final String interfaceNumber;

  /// Windows device-instance portion of the Raw Input path.
  final String instanceId;

  /// HID collection number without the `COL` prefix, when present.
  final String collectionId;

  /// Device-interface class identifier from the Raw Input path.
  final String interfaceClassId;

  /// Stable identifier derived from the available hardware attributes.
  String get deviceId {
    if (instanceId.isEmpty && interfaceClassId.isEmpty) return devicePath;

    return [
      if (vendorId.isNotEmpty) 'VID_$vendorId',
      if (productId.isNotEmpty) 'PID_$productId',
      if (interfaceNumber.isNotEmpty) 'MI_$interfaceNumber',
      if (instanceId.isNotEmpty) instanceId,
      if (collectionId.isNotEmpty) 'COL$collectionId',
      if (interfaceClassId.isNotEmpty) interfaceClassId,
    ].join('|');
  }
}
