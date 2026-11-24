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

`keyEvents` informa el código virtual, la identidad técnica y el nombre, transporte y fabricante del dispositivo cuando coincide con la lista más reciente. `start()` carga esa lista si todavía no se consultó; llama a `listDevices()` para actualizarla después de conectar otro teclado. La captura Raw Input observa teclas por dispositivo, mientras la escritura normal permanece habilitada para todos los teclados. El ejemplo también registra los `KeyEvent` que llegan a Flutter.

`barcodeEvents` emite el código completo cuando el dispositivo seleccionado termina la lectura con Enter. Cada evento incluye la identidad de origen; `deviceId` se deriva de sus atributos y permite comprobar que el código provino del teclado elegido.

```dart
final subscription = service.barcodeEvents.listen((barcode) {
  if (barcode.deviceId == selectedDeviceId) {
    debugPrint('Código: ${barcode.code}');
  }
});
```

### Política de entrada por dispositivo

La API de dominio selecciona qué dispositivo Raw Input se procesa como lector de códigos de barras:

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

Un `suppressedDeviceId` nulo elimina la selección. El nombre del argumento se conserva por compatibilidad, pero actualmente no bloquea la escritura: el plugin usa la selección para asociar los códigos completos al lector correcto. Flutter puede observar `KeyEvent`, aunque ese evento no incluye el ID físico del teclado.

### Bloquear teclas del dispositivo seleccionado

`ScannerKeyboardInputBlocker` conecta los eventos nativos del paquete con el handler global de Flutter. Pasa el `deviceId` elegido para consumir sus teclas; pasa `null` para dejar pasar todos los teclados. Esto filtra eventos dentro de Flutter, no desactiva el teclado en Windows.

Usa una sola instancia activa por ventana. Inicia el blocker antes de la captura para que pueda asociar cada `KeyEvent` con su origen. En el `State` de la pantalla, donde ya tienes `service` y el ID seleccionado:

```dart
final blocker = ScannerKeyboardInputBlocker(service: service);

void onDeviceSelected(ScannerCodeDevice? device) {
  setState(() => selectedDeviceId = device?.deviceId);
  blocker.setBlockedDeviceId(device?.deviceId);
}

Future<void> startCapture() async {
  blocker.start();
  try {
    await service.start();
  } on Object {
    await blocker.stop();
    rethrow;
  }
}

Future<void> stopCapture() async {
  await blocker.stop();
  await service.stop();
}

@override
void dispose() {
  unawaited(blocker.dispose());
  unawaited(service.dispose());
  super.dispose();
}
```

El blocker consume los eventos `KeyDownEvent` y `KeyRepeatEvent` del dispositivo seleccionado. Los eventos `KeyUpEvent`, sintetizados o sin un origen nativo reciente pasan a Flutter. Si el dispositivo deja de estar seleccionado, llama a `setBlockedDeviceId(null)`.

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
| `configureInputPolicy(policy)` | Selecciona el dispositivo cuyos eventos Raw Input forman códigos de barras y devuelve un resultado tipado. |
| `ScannerKeyboardInputBlocker(service:)` | Intercepta en Flutter las teclas del dispositivo seleccionado. |
| `blocker.start()` / `blocker.setBlockedDeviceId(deviceId)` | Registra el handler y actualiza qué teclado se bloquea. |
| `blocker.stop()` / `blocker.dispose()` | Retira el handler global y libera la suscripción. |
| `stop()` | Detiene la captura y permite reanudar el servicio. |
| `dispose()` | Detiene la captura y cierra el stream. |

## Ejemplo para Windows

```powershell
cd example
fvm flutter pub get
fvm flutter run -d windows
```

El ejemplo lista teclados, muestra eventos y rutas de origen, e incluye un campo de texto para comprobar el bloqueo selectivo mediante `ScannerKeyboardInputBlocker` y los códigos completos leídos hasta Enter.

## Arquitectura

- `domain/` define el servicio público y los modelos tipados de teclas y dispositivos.
- `data/` adapta los callbacks de Pigeon a streams de Dart.
- `pigeons/` define los comandos Host API y los eventos Flutter API.
- `windows/` enumera teclados, registra Raw Input y envía las teclas capturadas a Dart.

Regenera los archivos Pigeon después de cambiar el contrato:

```powershell
fvm dart run pigeon --input pigeons/scanner_code_api.dart
```
