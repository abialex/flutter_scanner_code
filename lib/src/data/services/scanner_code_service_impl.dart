import 'dart:async';

import 'package:flutter_scanner_code/src/data/datasources/scanner_code_data_source.dart';
import 'package:flutter_scanner_code/src/domain/entities/scanner_code_barcode.dart';
import 'package:flutter_scanner_code/src/domain/entities/scanner_code_device.dart';
import 'package:flutter_scanner_code/src/domain/entities/scanner_code_device_identity.dart';
import 'package:flutter_scanner_code/src/domain/entities/scanner_code_key_event.dart';
import 'package:flutter_scanner_code/src/domain/policies/scanner_input_policy.dart';
import 'package:flutter_scanner_code/src/domain/results/scanner_input_policy_result.dart';
import 'package:flutter_scanner_code/src/domain/services/scanner_code_service.dart';
import 'package:flutter_scanner_code/src/platform/pigeon/scanner_code_api.g.dart';

/// Maps Pigeon key callbacks to the public key-event stream.
final class ScannerCodeServiceImpl implements ScannerCodeService {
  /// Creates a service using the supplied Pigeon transport.
  ScannerCodeServiceImpl(this._dataSource);

  final ScannerCodeDataSource _dataSource;
  final _keyEvents = StreamController<ScannerCodeKeyEvent>.broadcast(
    sync: true,
  );
  final _barcodeEvents = StreamController<ScannerCodeBarcode>.broadcast(
    sync: true,
  );
  final Map<String, ScannerCodeDevice> _devicesById = {};
  StreamSubscription<ScannerKeyInfo>? _keySubscription;
  StreamSubscription<({String code, String devicePath})>? _barcodeSubscription;
  bool _started = false;
  bool _disposed = false;

  @override
  bool get isSupported => _dataSource.isSupported;

  @override
  Stream<ScannerCodeKeyEvent> get keyEvents => _keyEvents.stream;

  @override
  Stream<ScannerCodeBarcode> get barcodeEvents => _barcodeEvents.stream;

  @override
  Future<List<ScannerCodeDevice>> listDevices() async {
    _ensureUsable();
    final devices = await _dataSource.listDevices();
    final result = devices
        .map(
          (device) => ScannerCodeDevice(
            identity: _identityFromDevice(device),
            displayName: device.displayName,
            manufacturer: device.manufacturer,
            transport: device.transport,
            wasLastInput: device.wasLastInput,
          ),
        )
        .toList(growable: false);
    _devicesById
      ..clear()
      ..addEntries(result.map((device) => MapEntry(device.deviceId, device)));
    return result;
  }

  @override
  Future<ScannerInputPolicyResult> configureInputPolicy(
    ScannerInputPolicy policy,
  ) async {
    _ensureUsable();

    final requestedDeviceId = policy.suppressedDeviceId;
    ScannerCodeDevice? selectedDevice;
    if (requestedDeviceId != null) {
      await listDevices();
      selectedDevice = _devicesById[requestedDeviceId];
      if (selectedDevice == null) {
        return const ScannerInputPolicyResult(
          status: ScannerInputPolicyStatus.deviceNotFound,
          message: 'The selected keyboard is no longer available.',
        );
      }
    }

    final result = await _dataSource.configureInputPolicy(
      selectedDevice?.devicePath,
    );
    return ScannerInputPolicyResult(
      status: switch (result.status) {
        ScannerInputPolicyStatusData.applied =>
          ScannerInputPolicyStatus.applied,
        ScannerInputPolicyStatusData.unsupported =>
          ScannerInputPolicyStatus.unsupported,
      },
      message: result.message,
    );
  }

  @override
  Future<void> start() async {
    _ensureUsable();
    if (_started) return;

    if (_devicesById.isEmpty) await listDevices();
    _keySubscription ??= _dataSource.keys.listen(_onKeyPressed);
    _barcodeSubscription ??= _dataSource.barcodes.listen(_onBarcode);
    try {
      await _dataSource.startCapture();
      _started = true;
    } on Object {
      await _keySubscription?.cancel();
      _keySubscription = null;
      await _barcodeSubscription?.cancel();
      _barcodeSubscription = null;
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _ensureUsable();
    if (!_started) return;
    await _dataSource.stopCapture();
    _started = false;
  }

  void _onKeyPressed(ScannerKeyInfo key) {
    final identity = _identityFromKey(key);
    final device = _devicesById[identity.deviceId];
    _keyEvents.add(
      ScannerCodeKeyEvent(
        virtualKey: key.virtualKey,
        identity: identity,
        deviceName: device?.displayName ?? '',
        deviceManufacturer: device?.manufacturer ?? '',
        deviceTransport: device?.transport ?? '',
      ),
    );
  }

  void _onBarcode(({String code, String devicePath}) barcode) {
    _barcodeEvents.add(
      ScannerCodeBarcode(
        code: barcode.code,
        identity: _identityForPath(barcode.devicePath),
      ),
    );
  }

  ScannerCodeDeviceIdentity _identityForPath(String devicePath) {
    for (final device in _devicesById.values) {
      if (device.devicePath == devicePath) return device.identity;
    }

    return ScannerCodeDeviceIdentity(
      devicePath: devicePath,
      vendorId: '',
      productId: '',
      interfaceNumber: '',
      instanceId: '',
      collectionId: '',
      interfaceClassId: '',
    );
  }

  ScannerCodeDeviceIdentity _identityFromDevice(ScannerDeviceInfo device) =>
      ScannerCodeDeviceIdentity(
        devicePath: device.devicePath,
        vendorId: device.vendorId,
        productId: device.productId,
        interfaceNumber: device.interfaceNumber,
        instanceId: device.instanceId,
        collectionId: device.collectionId,
        interfaceClassId: device.interfaceClassId,
      );

  ScannerCodeDeviceIdentity _identityFromKey(ScannerKeyInfo key) =>
      ScannerCodeDeviceIdentity(
        devicePath: key.devicePath,
        vendorId: key.vendorId,
        productId: key.productId,
        interfaceNumber: key.interfaceNumber,
        instanceId: key.instanceId,
        collectionId: key.collectionId,
        interfaceClassId: key.interfaceClassId,
      );

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('Create a new service after disposing this one.');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _keySubscription?.cancel();
    await _barcodeSubscription?.cancel();
    try {
      await _dataSource.dispose();
    } finally {
      await _keyEvents.close();
      await _barcodeEvents.close();
    }
  }
}
