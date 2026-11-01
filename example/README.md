# Ejemplo de flutter_scanner_code

Aplicación Windows que consume la API pública del paquete.

Desde `example/`:

```powershell
fvm flutter pub get
fvm flutter run -d windows
```

1. Pulsa **Actualizar teclados** para consultar los teclados Raw Input conectados.
2. Presiona una tecla o escanea con un lector en modo teclado. La lista de eventos muestra el código virtual y el identificador de origen.
3. El campo de prueba debe recibir la escritura normal al mismo tiempo.
4. Selecciona un teclado en el dropdown: el contenedor de eventos muestra solo las teclas de ese dispositivo. El dropdown muestra el nombre descriptivo de Windows o, si es genérico, transporte, fabricante disponible, VID/PID e interfaz o colección.
5. Pulsa **Detener** para pausar la captura y **Iniciar captura** para reanudarla.

Windows solo lista los dispositivos conectados que presenta como teclados. Esto incluye lectores USB o Bluetooth en modo teclado, pero no todos los dispositivos Bluetooth emparejados.
