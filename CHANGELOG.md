# Registro de cambios

Los cambios importantes del paquete se documentan aquí.

## [0.1.0] - 2026-11-01

### Agregado

- Captura de teclas de Windows mediante Raw Input y eventos Pigeon.
- Listado de teclados conectados, con indicador del dispositivo de la última entrada.
- Nombre descriptivo de dispositivos consultado desde las propiedades PnP de Windows.
- Fabricante y tipo de conexión cuando Windows los reporta; el ejemplo añade VID/PID, interfaz o colección para distinguir nombres genéricos.
- Nombre, fabricante y transporte del dispositivo de origen adjuntos a los eventos capturados cuando coinciden con la lista Raw Input.
- Ejemplo de Windows con lista de teclados, eventos capturados y campo de escritura normal.
- Política tipada para solicitar la supresión de escritura de un dispositivo y conocer si la plataforma la aplicó.
- Stream tipado de códigos de barras completos, delimitados por Enter y asociados al dispositivo seleccionado.

### Cambiado

- La identidad del dispositivo expone atributos por separado y deriva `deviceId` mediante un getter.
- La API pública permite iniciar/detener la captura, listar teclados y emitir teclas presionadas.
- Windows suprime la escritura del dispositivo seleccionado y reenvía a Flutter las teclas Raw Input de los demás teclados.
