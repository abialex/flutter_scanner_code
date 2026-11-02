# Error al reenviar Alt y Ctrl en Windows

**Estado:** corregido

## Síntoma

Al activar el filtro de un teclado y presionar Alt o Ctrl desde otro teclado,
Flutter podía reportar:

```text
Attempted to send a key down event when no keys are in keysPressed.
```

## Causa

El plugin reenviaba teclas con `PostMessageW`. Ese método publicaba el mensaje
de tecla, pero no actualizaba el estado de modificadores que Windows expone a
Flutter. Por eso Flutter podía recibir Alt o Ctrl como tecla presionada mientras
el estado indicaba que el modificador estaba suelto.

## Corrección

El reenvío ahora usa `SendInput` con el código de escaneo y los indicadores de
tecla extendida/soltada correspondientes. Así Windows procesa el evento y
mantiene sincronizado el estado de Alt y Ctrl que Flutter consulta. Se conserva
el filtro por dispositivo: las teclas del dispositivo seleccionado siguen
suprimiéndose y las de los demás teclados se reenvían.

## Verificación manual

- Presionar y soltar Alt y Ctrl por separado mientras el filtro está activo.
- Escribir con combinaciones como Ctrl+A y Alt+una tecla desde el teclado no
  seleccionado.
- Confirmar que no aparece la excepción de `keysPressed` y que el teclado
  seleccionado continúa bloqueado.
