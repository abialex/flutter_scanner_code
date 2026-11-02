# flutter_scanner_code

Plugin de Flutter que captura cada tecla física presionada en Windows. El plugin nativo lee Raw Input y envía a Dart la tecla y la ruta del dispositivo mediante Pigeon.

Admite teclados conectados que Windows expone mediante Raw Input, incluidos dispositivos USB y Bluetooth configurados como teclado. No empareja dispositivos ni arma códigos de barras completos. Cuando Windows lo informa, la lista también expone fabricante y transporte (USB, Bluetooth o virtual).

## Requisitos

- Flutter 3.44.0 o posterior y Dart 3.12 o posterior.
- Windows de escritorio y Visual Studio con la carga **Desktop development with C++**.

## Instalación

```yaml
dependencies:
  flutter_scanner_code:
    path: ../flutter_scanner_code
```

Después de agregar o cambiar el plugin de Windows, recompila la aplicación. Hot reload no recarga el código nativo.

## Uso

```dart
import 'package:flutter_scanner_code/flutter_scanner_code.dart';

final service = initScannerCodeService();
final subscription = service.keyEvents.listen((event) {
  debugPrint(
    'VK ${event.virtualKey} desde ${event.deviceName} (${event.deviceId})',
  );
});

await service.start();

// Cuando ya no se necesite capturar:
await service.stop();
await subscription.cancel();
await service.dispose();
```

`keyEvents` informa el código virtual, la identidad técnica y el nombre, transporte y fabricante del dispositivo cuando coincide con la lista más reciente. `start()` carga esa lista si todavía no se consultó; llama a `listDevices()` para actualizarla después de conectar otro teclado. De forma predeterminada, la captura deja pasar la escritura normal. Al elegir un dispositivo con `configureInputPolicy`, Windows suprime su escritura dentro de esta aplicación y conserva la de los demás teclados.

`barcodeEvents` emite el código completo cuando el dispositivo seleccionado termina la lectura con Enter. Cada evento incluye la identidad de origen; `deviceId` se deriva de sus atributos y permite comprobar que el código provino del teclado elegido.

```dart
final subscription = service.barcodeEvents.listen((barcode) {
  if (barcode.deviceId == selectedDeviceId) {
    debugPrint('Código: ${barcode.code}');
  }
});
```

### Política de entrada por dispositivo

La API de dominio permite solicitar que se suprima la escritura normal de un dispositivo seleccionado:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_scanner_code/flutter_scanner_code.dart';

Future<void> configureSelectedDevice() async {
  final service = initScannerCodeService();
  try {
    final devices = await service.listDevices();
    if (devices.isEmpty) return;

    await service.start();
    final result = await service.configureInputPolicy(
      ScannerInputPolicy(suppressedDeviceId: devices.first.deviceId),
    );
    debugPrint('${result.status}: ${result.message ?? ''}');
  } finally {
    await service.dispose();
  }
}
```

Un `suppressedDeviceId` nulo elimina la selección. Windows no permite desactivar los mensajes de teclado heredados para un único dispositivo HID. Por eso, mientras hay una selección, el plugin recibe Raw Input, omite las teclas de ese dispositivo y vuelve a enviar a la vista enfocada de esta aplicación las teclas de los demás. Así conserva la escritura del teclado restante. Al limpiar la selección, se restaura el flujo normal de teclado. La política se activa al iniciar la captura.

### Listar teclados detectados

```dart
final devices = await service.listDevices();
for (final device in devices) {
  debugPrint(
    '${device.displayName} · ${device.transport} · '
    '${device.manufacturer} · ${device.deviceId} · '
    'última entrada: ${device.wasLastInput}',
  );
}
```

La lista contiene los teclados conectados que Windows presenta a Raw Input. Puede incluir lectores USB o Bluetooth en modo teclado, pero no incluye todos los dispositivos Bluetooth emparejados. Windows puede proporcionar un nombre descriptivo del dispositivo o de un nodo padre. Si el nombre es genérico, el ejemplo muestra transporte, fabricante cuando está disponible, VID/PID e interfaz o colección para ayudar a reconocerlo. `deviceId` es un getter compuesto a partir de los atributos disponibles, mientras que `devicePath` conserva la ruta original de Windows. `wasLastInput` indica qué dispositivo envió la tecla capturada más reciente.

## Manejo de errores

En otras plataformas, `isSupported` es `false` y las operaciones nativas lanzan `ScannerCodeException` con el código `unsupported_platform`. Los errores de Windows también se traducen a `ScannerCodeException`, con un `code` estable y un `message` legible.

## Métodos disponibles

| Miembro | Uso |
| --- | --- |
| `initScannerCodeService()` | Crea el servicio predeterminado. |
| `isSupported` | Indica si la plataforma admite la captura. |
| `start()` | Inicia la captura Raw Input. |
| `listDevices()` | Lista teclados conectados con nombre, fabricante, transporte y atributos separados. |
| `keyEvents` | Emite cada tecla presionada con su código virtual y ruta de origen. |
| `barcodeEvents` | Emite el código completo al recibir Enter desde el dispositivo seleccionado. |
| `configureInputPolicy(policy)` | Solicita suprimir la escritura normal del dispositivo seleccionado y devuelve un resultado tipado. |
| `stop()` | Detiene la captura y permite reanudar el servicio. |
| `dispose()` | Detiene la captura y cierra el stream. |

## Ejemplo para Windows

```powershell
cd example
fvm flutter pub get
fvm flutter run -d windows
```

El ejemplo lista teclados, muestra eventos y rutas de origen, e incluye un campo de texto para comprobar la escritura normal, el filtro por dispositivo y el código completo leído hasta Enter.

## Arquitectura

- `domain/` define el servicio público y los modelos tipados de teclas y dispositivos.
- `data/` adapta los callbacks de Pigeon a streams de Dart.
- `pigeons/` define los comandos Host API y los eventos Flutter API.
- `windows/` enumera teclados, registra Raw Input y envía las teclas capturadas a Dart.

Regenera los archivos Pigeon después de cambiar el contrato:

```powershell
fvm dart run pigeon --input pigeons/scanner_code_api.dart
```
