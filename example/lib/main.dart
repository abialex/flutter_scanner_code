import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_scanner_code/flutter_scanner_code.dart';

void main() => runApp(
  MaterialApp(
    title: 'Scanner code',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: const _KeyboardCapturePage(),
  ),
);

class _KeyboardCapturePage extends StatefulWidget {
  const _KeyboardCapturePage();

  @override
  State<_KeyboardCapturePage> createState() => _KeyboardCapturePageState();
}

class _KeyboardCapturePageState extends State<_KeyboardCapturePage> {
  final ScannerCodeService _service = initScannerCodeService();
  final _events = <ScannerCodeKeyEvent>[];
  final _barcodes = <ScannerCodeBarcode>[];
  List<ScannerCodeDevice> _devices = const [];
  StreamSubscription<ScannerCodeKeyEvent>? _subscription;
  StreamSubscription<ScannerCodeBarcode>? _barcodeSubscription;
  String? _selectedDeviceId;
  bool _capturing = false;
  bool _busy = false;
  String? _error;
  String? _policyMessage;

  @override
  void initState() {
    super.initState();
    _subscription = _service.keyEvents.listen(_onKeyPressed);
    _barcodeSubscription = _service.barcodeEvents.listen(_onBarcode);
    unawaited(_startCapture());
  }

  void _onKeyPressed(ScannerCodeKeyEvent event) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, event);
      if (_events.length > 200) _events.removeLast();
      _devices = _devices
          .map(
            (device) => ScannerCodeDevice(
              identity: device.identity,
              displayName: device.displayName,
              manufacturer: device.manufacturer,
              transport: device.transport,
              wasLastInput: device.deviceId == event.deviceId,
            ),
          )
          .toList(growable: false);
    });
  }

  void _onBarcode(ScannerCodeBarcode barcode) {
    if (!mounted) return;
    setState(() {
      _barcodes.insert(0, barcode);
      if (_barcodes.length > 100) _barcodes.removeLast();
    });
  }

  Future<void> _startCapture() => _runCapture(() async {
    final previouslySelectedDeviceId = _selectedDeviceId;
    await _service.start();
    _capturing = true;
    _updateDevices(await _service.listDevices());
    if (previouslySelectedDeviceId != null && _selectedDeviceId == null) {
      final result = await _service.configureInputPolicy(
        const ScannerInputPolicy(),
      );
      _policyMessage = result.message;
    }
  });

  Future<void> _selectDevice(String? deviceId) => _runCapture(() async {
    final previousDeviceId = _selectedDeviceId;
    setState(() {
      _selectedDeviceId = deviceId;
      _policyMessage = null;
    });
    final result = await _service.configureInputPolicy(
      ScannerInputPolicy(suppressedDeviceId: deviceId),
    );
    if (!mounted) return;
    if (result.isApplied) {
      setState(() => _policyMessage = result.message);
    } else {
      setState(() {
        _selectedDeviceId = previousDeviceId;
        _error = result.message ?? 'No se pudo aplicar el filtro.';
      });
    }
  });

  Future<void> _allowSelectedDevice() => _runCapture(() async {
    final result = await _service.configureInputPolicy(
      const ScannerInputPolicy(),
    );
    if (mounted) setState(() => _policyMessage = result.message);
  });

  Future<void> _stopCapture() => _runCapture(() async {
    await _service.stop();
    _capturing = false;
  });

  Future<void> _refreshDevices() => _runCapture(() async {
    final previouslySelectedDeviceId = _selectedDeviceId;
    _updateDevices(await _service.listDevices());
    if (previouslySelectedDeviceId != null && _selectedDeviceId == null) {
      final result = await _service.configureInputPolicy(
        const ScannerInputPolicy(),
      );
      _policyMessage = result.message;
    }
  });

  void _updateDevices(List<ScannerCodeDevice> devices) {
    _devices = devices;
    if (!_devices.any((device) => device.deviceId == _selectedDeviceId)) {
      _selectedDeviceId = null;
    }
  }

  Future<void> _runCapture(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ScannerCodeException catch (error) {
      if (mounted) setState(() => _error = '${error.code}: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_barcodeSubscription?.cancel());
    unawaited(_service.dispose());
    super.dispose();
  }

  List<ScannerCodeKeyEvent> get _visibleEvents {
    final selectedDeviceId = _selectedDeviceId;
    if (selectedDeviceId == null) return const [];

    return _events
        .where((event) => event.deviceId == selectedDeviceId)
        .toList(growable: false);
  }

  List<ScannerCodeBarcode> get _visibleBarcodes {
    final selectedDeviceId = _selectedDeviceId;
    if (selectedDeviceId == null) return const [];

    return _barcodes
        .where((barcode) => barcode.deviceId == selectedDeviceId)
        .toList(growable: false);
  }

  ScannerCodeDevice? get _selectedDevice {
    for (final device in _devices) {
      if (device.deviceId == _selectedDeviceId) return device;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final visibleEvents = _visibleEvents;
    final visibleBarcodes = _visibleBarcodes;
    final selectedDevice = _selectedDevice;
    final selectedDeviceName = selectedDevice == null
        ? 'este dispositivo'
        : _displayName(selectedDevice);

    return Scaffold(
      appBar: AppBar(title: const Text('Captura de teclas · Windows')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Presiona teclas en un teclado o escanea un código. '
              'Windows envía cada tecla y el identificador del dispositivo '
              'por Pigeon.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Prueba de escritura normal',
                helperText:
                    'La escritura del teclado seleccionado se filtra; los '
                    'demás teclados siguen escribiendo.',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _busy || _capturing ? null : _startCapture,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar captura'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _busy || !_capturing ? null : _stopCapture,
                  icon: const Icon(Icons.stop),
                  label: const Text('Detener'),
                ),
                const SizedBox(width: 16),
                Text(_capturing ? 'Capturando' : 'Detenido'),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _refreshDevices,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar teclados'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: visibleEvents.isEmpty && visibleBarcodes.isEmpty
                      ? null
                      : () => setState(
                          () {
                            _events.removeWhere(
                              (event) => event.deviceId == _selectedDeviceId,
                            );
                            _barcodes.removeWhere(
                              (barcode) =>
                                  barcode.deviceId == _selectedDeviceId,
                            );
                          },
                        ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText:
                    'Teclado seleccionado (${_devices.length} detectados)',
                helperText:
                    'El teclado seleccionado se filtra mientras la captura '
                    'esta activa. Los demas siguen funcionando.',
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value:
                      _devices.any(
                        (device) => device.deviceId == _selectedDeviceId,
                      )
                      ? _selectedDeviceId
                      : null,
                  hint: Text(
                    _devices.isEmpty
                        ? 'No hay teclados detectados'
                        : 'Selecciona un teclado',
                  ),
                  items: _devices
                      .map(
                        (device) => DropdownMenuItem(
                          value: device.deviceId,
                          child: Row(
                            children: [
                              Icon(
                                device.wasLastInput
                                    ? Icons.keyboard_alt_outlined
                                    : Icons.keyboard_outlined,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Tooltip(
                                  message: device.devicePath,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayName(device),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _deviceDetails(device),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy || _devices.isEmpty ? null : _selectDevice,
                ),
              ),
            ),
            if (_policyMessage case final message?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy || !_capturing || _selectedDeviceId == null
                    ? null
                    : _allowSelectedDevice,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Permitir teclado seleccionado'),
              ),
            ),
            const SizedBox(height: 12),
            Text('Códigos completos: ${visibleBarcodes.length}'),
            if (visibleBarcodes.isNotEmpty)
              SelectableText('Último código: ${visibleBarcodes.first.code}'),
            const SizedBox(height: 8),
            Text('Teclas capturadas del dispositivo: ${visibleEvents.length}'),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: _selectedDeviceId == null
                    ? const Center(
                        child: Text(
                          'Selecciona un dispositivo para ver sus teclas.',
                        ),
                      )
                    : visibleEvents.isEmpty
                    ? Center(
                        child: Text(
                          'Esperando teclas de $selectedDeviceName…',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: visibleEvents.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final event = visibleEvents[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(_keyLabel(event.virtualKey)),
                            ),
                            title: Text(
                              'Virtual key: ${event.virtualKey}',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            subtitle: Text(
                              _eventSource(event),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(ScannerCodeDevice device) {
    final displayName = device.displayName.trim();
    if (displayName.isNotEmpty) return displayName;

    final identity = device.identity;
    if (device.transport == 'USB') {
      return 'Teclado USB';
    }
    if (device.transport == 'Virtual') {
      return 'Teclado virtual';
    }
    final fallback = [
      if (identity.vendorId.isNotEmpty) 'VID ${identity.vendorId}',
      if (identity.productId.isNotEmpty) 'PID ${identity.productId}',
    ].join(' · ');
    return fallback.isEmpty ? 'Teclado sin nombre' : fallback;
  }

  String _deviceDetails(ScannerCodeDevice device) {
    final identity = device.identity;
    return [
      if (device.transport.isNotEmpty) device.transport,
      if (device.manufacturer.isNotEmpty) device.manufacturer,
      if (identity.vendorId.isNotEmpty) 'VID ${identity.vendorId}',
      if (identity.productId.isNotEmpty) 'PID ${identity.productId}',
      if (identity.interfaceNumber.isNotEmpty)
        'Interfaz ${identity.interfaceNumber}',
      if (identity.collectionId.isNotEmpty)
        'Colección ${identity.collectionId}',
      if (device.wasLastInput) 'Última entrada',
    ].join(' · ');
  }

  String _eventSource(ScannerCodeKeyEvent event) {
    final sourceDetails = [
      event.deviceName,
      if (event.deviceTransport.isNotEmpty) event.deviceTransport,
      if (event.deviceManufacturer.isNotEmpty) event.deviceManufacturer,
    ].where((value) => value.isNotEmpty).join(' · ');
    if (sourceDetails.isEmpty) {
      return event.deviceId.isEmpty ? 'Origen no informado' : event.deviceId;
    }

    return event.deviceId.isEmpty
        ? sourceDetails
        : '$sourceDetails\n${event.deviceId}';
  }

  String _keyLabel(int virtualKey) {
    if ((virtualKey >= 0x30 && virtualKey <= 0x39) ||
        (virtualKey >= 0x41 && virtualKey <= 0x5a)) {
      return String.fromCharCode(virtualKey);
    }
    if (virtualKey >= 0x60 && virtualKey <= 0x69) {
      return String.fromCharCode(virtualKey - 0x30);
    }
    return switch (virtualKey) {
      0x08 => '⌫',
      0x09 => 'Tab',
      0x0d => '↵',
      0x1b => 'Esc',
      0x20 => 'Space',
      _ => 'VK',
    };
  }
}
