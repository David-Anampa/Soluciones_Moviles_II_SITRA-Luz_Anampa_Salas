# Recursos de marca SITRA-Luz

Originales trasladados desde la carpeta LOGO de Descargas a `app/assets/branding`:

- `SITRA-LUZ-icono-final.svg`: fuente del icono de Android, incluidas sus variantes adaptativas.
- `SITRA-LUZ-icono-final-2048.png`: fuente del icono de arranque.
- `SITRA-LUZ-estilo-SISGET-v3.png`: logo completo del login.

`logo_login.png` es una copia derivada del v3, con el margen transparente recortado
y tamaño reducido. No se redibuja el logo. Los originales se conservan intactos.

Para regenerar las variantes nativas y el logo optimizado, desde la raíz:

```powershell
npm install --prefix tools/branding
npm run generate --prefix tools/branding
```

Estas herramientas se usan solo para generar recursos; no añaden dependencias
a Flutter. El SVG se rasteriza con resvg para conservar sus máscaras y detalles.

Android utiliza recursos por densidad y una variante de arranque para API 31+,
con espacio seguro alrededor del PNG. El fondo nativo coincide con el del login
(`#F4F6FB`), también en modo oscuro. Android 12+ desvanece la pantalla nativa en
220 ms; el login aparece gradualmente en 350 ms sin esperas artificiales.

Referencias: [pantalla de arranque Android](https://developer.android.com/develop/ui/views/launch/splash-screen),
[integración de la pantalla nativa con Flutter](https://docs.flutter.dev/release/breaking-changes/splash-screen-migration).

Para ver estos cambios nativos hay que detener y ejecutar de nuevo la aplicación;
hot reload/hot restart no sustituye la instalación del APK actualizado:

```powershell
cd app
flutter run -d emulator-5556 --no-pub --no-dds
```

La revisión funcional/visual del arranque queda a cargo del usuario. No cambiar
versiones ni borrar los datos del emulador para actualizar estas imágenes.
