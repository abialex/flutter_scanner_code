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
  List<ScannerCodeDevice> _devices = const [];
  StreamSubscription<ScannerCodeKeyEvent>? _subscription;
  String? _selectedDeviceId;
  bool _capturing = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = _service.keyEvents.listen(_onKeyPressed);
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

  Future<void> _startCapture() => _runCapture(() async {
    await _service.start();
    _capturing = true;
    _updateDevices(await _service.listDevices());
  });

  Future<void> _stopCapture() => _runCapture(() async {
    await _service.stop();
    _capturing = false;
  });

  Future<void> _refreshDevices() => _runCapture(() async {
    _updateDevices(await _service.listDevices());
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

  ScannerCodeDevice? get _selectedDevice {
    for (final device in _devices) {
      if (device.deviceId == _selectedDeviceId) return device;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final visibleEvents = _visibleEvents;
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
                helperText: 'La tecla también debe escribirse en este campo.',
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
                  onPressed: visibleEvents.isEmpty
                      ? null
                      : () => setState(
                          () => _events.removeWhere(
                            (event) => event.deviceId == _selectedDeviceId,
                          ),
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
                labelText: 'Teclados detectados (${_devices.length})',
                helperText:
                    'USB o Bluetooth en modo teclado. La etiqueta identifica '
                    'el dispositivo que envió la última tecla.',
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
                  onChanged: _busy || _devices.isEmpty
                      ? null
                      : (deviceId) => setState(
                          () => _selectedDeviceId = deviceId,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
