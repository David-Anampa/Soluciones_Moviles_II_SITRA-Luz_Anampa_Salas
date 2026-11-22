# HU-003: diseño adaptable y emulador de trabajo

Fecha: 22/11/2026. Rama: `Sprint-08`.

## Alcance aplicado

- Cabecera con título breve e información del área que puede ocupar varias líneas.
- Selector General/Neonatología vertical cuando falta ancho; horizontal con espacio.
- Campos en una o varias columnas según ancho disponible y escala de texto del sistema.
- Selectores de médico, receptor y financiamiento con texto multilínea.
- Controles de cantidad distribuidos en varias filas cuando sea necesario.
- Márgenes adaptables, área segura y desplazamiento con teclado abierto.
- Cantidad y sección del selector individual ajustadas al ancho del diálogo.

Se conservan las tipografías, tamaños base, colores e iconos existentes. No se
modifican las reglas de stock, auditoría ni RPC. Este avance cubre el registro de
fichas y su selector individual; no acredita la adaptación de todas las pantallas.

## Comprobación

`flutter analyze --no-pub`: sin observaciones.
Tres comprobaciones de distribución con datos locales y nombres extensos:
320 × 568 con escala normal, 390 × 844 con texto al 150 % y teclado de 280 px,
y 640 × 360 horizontal con texto al 200 %. El formulario se desplaza y permite
alcanzar el botón de envío sin errores de distribución.

Prueba externa al repositorio:
`C:/Users/ASUS/Documents/Codex/2026-10-25/empe/work/hu003_responsive_test.dart`.
No envía fichas ni modifica datos de Supabase. La aceptación funcional y estética
con el usuario continúa pendiente.

## Emulador

El error `INSTALL_FAILED_INSUFFICIENT_STORAGE` se debía al espacio del Pixel 8
anterior: unos 385 MB libres. Los avisos de paquetes disponibles no eran su causa.

Por decisión del usuario se creó `Pixel_8_SITRA`, perfil Pixel 8, Android 36,
imagen Google Play x86_64 de páginas de 16 KB ya instalada, partición de datos de
8 GB y RAM de 2 GB. Mostró 6,9 GB libres en el primer arranque. El AVD `Pixel_8`
anterior se conserva con sus datos. SITRA-Luz pudo instalarse en el nuevo AVD.

En Android Studio, seleccionar **Pixel 8 SITRA · 8 GB** en Device Manager.
Desde la carpeta `app`, con el emulador abierto:

```powershell
flutter devices
flutter run -d emulator-5556
```

El identificador puede cambiar al reiniciar; usar el que muestre `flutter devices`.
Si está cerrado, puede iniciarse con `flutter emulators --launch Pixel_8_SITRA`.
No fue necesario actualizar dependencias para resolver la instalación.
