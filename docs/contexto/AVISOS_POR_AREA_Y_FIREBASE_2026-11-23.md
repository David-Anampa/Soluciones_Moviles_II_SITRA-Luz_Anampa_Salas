# Avisos por área y preparación de Firebase — 23/11/2026

El usuario eligió «Aviso integrado» del prototipo y pidió áreas destacadas,
cantidades por área y total. Solicita que las pruebas de uso las realice él.

## Implementado

- Panel de pendientes separado de las tarjetas de navegación: nombre real del
  área resaltado, contador por grupo, total y urgentes. No contiene pacientes.
- Almacén: solicitudes pendientes iniciadas por Farmacia.
- Farmacia: pedidos clínicos SOLICITADO agrupados por área y abastecimientos
  LISTO que aún no confirmó Farmacia. Los grupos de recepción se distinguen.
- Enfermería: fichas LISTO_PARA_RECOJO visibles según área autorizada o solicitante.
  El origen visible es Farmacia y se identifica el área de destino debajo.
- Acciones abren las solicitudes o el listado de fichas con área/estado adecuados.
  Abrir el panel no altera pedidos, cantidades ni auditoría de operaciones.
- Consulta al entrar, al regresar de revisar pedidos, al volver a primer plano,
  al actualizar la pantalla y mediante el icono de actualizar. Sin sondeo continuo.
- Se oculta si no hay pendientes. Si falla la consulta se ofrece reintento;
  conserva los datos anteriores identificándolos como no actualizados.
- Las franjas de sección también usan los colores de cada rol.

## Base de datos verificada

Proyecto `nedeqnvpkalrchswrapr`, inspección remota realizada. Ya existen áreas,
origen/destino y estados en pedidos y fichas; no había tablas de notificaciones.
Los listados actuales limitan las filas, por lo que no sirven como total completo.

Aplicada `docs/supabase/migracion_resumen_avisos_home_2026_11_23.sql`:
añade únicamente la RPC de lectura `resumen_avisos_home(TEXT)` con agregación
completa en servidor. Exige perfil activo y mismo rol del ámbito (Administrador
puede consultar cualquiera). Enfermería conserva el filtro de área/solicitante.
No modifica tablas, stock ni pedidos. No devuelve datos de pacientes. Verificada
la ejecución autenticada y la ausencia de permiso para anónimos mediante consulta
de lectura; sin pedidos ni movimientos de prueba.

Los contadores son **trabajo pendiente**, no avisos «sin leer». No se simulan
campana, historial ni marcas de lectura mientras no exista su persistencia.

## Firebase: pendiente de configuración y desarrollo

FCM entrega push a una instancia de la app/dispositivo, no al correo o teléfono.
FCM no cobra por la mensajería; otros servicios de infraestructura mantienen sus
propias cuotas. El SMS de Phone Auth sirve para verificar teléfonos y es facturable;
no es el canal propuesto para pedidos.

SDK Android configurado el 23/11 con el archivo proporcionado por el usuario
`C:/Users/ASUS/Downloads/google-services (2).json`, copiado a
`app/android/app/google-services.json` (ignorado por Git). Se verificaron proyecto
`sitra-luz` y paquete `ap.sitra.luz.clinica` sin publicar claves del archivo.
Plugin Google Services habilitado con la versión 4.4.2 ya declarada; se conservan
las dependencias FlutterFire existentes sin duplicar la BoM. Permiso de Android
13+ e icono de notificación preparados en el manifiesto.

`enableFirebaseSdk=true` inicializa Firebase Core. `enablePushNotifications=false`
mantiene pendiente el flujo push hasta terminar bandeja, navegación y envío.
Retirados los logs de tokens, títulos, cuerpos y payloads. El servicio heredado
todavía contempla un token por perfil: reemplazarlo por dispositivos con RLS antes
de activar producción. No afirmar que ya envía o navega correctamente.

Para completarlo, acordar/vincular el proyecto Firebase del usuario y registrar
Android (`ap.sitra.luz.clinica`), instalar configuración cliente y mantener las
credenciales de envío exclusivamente en servidor. Guardar dispositivos por usuario,
renovar/desvincular tokens al cambiar de sesión, gestionar permisos de Android,
persistir eventos y lectura con RLS en Supabase, generar envíos tras confirmar la
operación, evitar duplicados y reintentar sin duplicar el historial. Al tocar un
push debe abrir su solicitud tras verificar sesión y permisos. Sin datos de
pacientes en la notificación de bloqueo. Firebase no sustituye Supabase Auth.

Separar dos conceptos: «sin leer» disminuye al abrir un aviso; «pendiente» solo
disminuye al cambiar el estado operativo correspondiente. El push no acredita
lectura, preparación, entrega ni recepción física.

## Flujo solicitado para la siguiente implementación

Preparación acordada, aún no implementada: centro `/notificaciones` con áreas
destacadas, fechas, avisos sin leer y acceso al documento correspondiente. Las
cantidades de pendientes siguen siendo independientes del historial de lectura.

1. Al tocar el push, recoger su identificador y conservar una intención de
   navegación pendiente sin contenido clínico. Cubrir `getInitialMessage()` y
   `onMessageOpenedApp`; no navegar desde el manejador de segundo plano.
2. Esperar a que Supabase termine de resolver/restaurar la sesión. Si sigue
   válida, continuar; si no, mostrar login conservando ese destino.
3. Tras autenticar, comprobar perfil activo, destinatario y permisos consultando
   la notificación mediante RLS. No confiar en un rol ni URL enviados en el push.
4. Abrir el centro de notificaciones con ese aviso seleccionado. Desde él,
   «Ver solicitud» abre el pedido/ficha autorizado, sin modificar su estado.
5. Consumir el destino una sola vez. Si el aviso ya no existe o pertenece a otra
   cuenta, mostrar un mensaje neutro y conservar el acceso a la bandeja propia.
6. Leer un aviso actualiza únicamente su lectura; cancelar login no debe revelar
   su contenido. Gestionar cambios de cuenta y desvincular tokens al salir.

La configuración inicial requiere una cuenta de Google administradora del
proyecto Firebase (personal o institucional con acceso a la consola). Los usuarios
de SITRA-Luz no necesitan cuentas Google. Plan Spark y FCM; Analytics opcional,
sin activar bases de datos ni Firebase Authentication. Registrar la app Android
con `applicationId` **ap.sitra.luz.clinica**, descargar `google-services.json` y
colocarlo en `app/android/app/google-services.json` (pasos ya completados).
La bandeja, navegación y envío seguro desde Supabase continúan pendientes.

Para el envío, se solicitó al usuario generar la credencial de cuenta de servicio
desde Configuración del proyecto → Cuentas de servicio → SDK Admin de Firebase,
descargarla fuera del repositorio e indicar solo su ruta. No pedir que publique su
contenido. Verificar su project_id y guardar la credencial únicamente como secreto
de Supabase para el remitente FCM HTTP v1. El JSON Android no sustituye esa clave.

El usuario pausó inicialmente la credencial de servidor y posteriormente retomó
esa etapa y proporcionó el JSON de cuenta de servicio. Verificaciones del SDK: `flutter analyze --no-pub`
sin observaciones y `flutter build apk --debug --no-pub` correcto con el plugin
habilitado y el JSON instalado. No se enviaron notificaciones de prueba ni se
activó el flujo incompleto. Para cargar cambios nativos, detener la ejecución
actual y usar `flutter run -d emulator-5556 --no-pub --no-dds` desde `app`.

## Credencial del servidor preparada — 23/11/2026

Validada la cuenta de servicio proporcionada para el proyecto `sitra-luz`.
Guardados en los secretos de Edge Functions de Supabase `nedeqnvpkalrchswrapr`:

- `FIREBASE_SERVICE_ACCOUNT_JSON`: cuenta de servicio completa, solo en servidor.
- `FIREBASE_PROJECT_ID`: `sitra-luz`.

Guardado verificado comparando SHA-256 en memoria con las huellas remotas, sin
publicar valores ni claves. La CLI actual llama `value` al campo de huella de
`secrets list`; no confundirlo con la credencial descifrada. Archivo original
preservado en Descargas fuera del repositorio; archivo `.env` de carga temporal
eliminado. `.gitignore` también excluye archivos `*-firebase-adminsdk-*.json` y
`serviceAccountKey.json` para impedir su inclusión accidental.

No se ha enviado ningún push ni desplegado aún un remitente FCM. No hay prueba de
entrega ni de permisos efectivos de envío. El siguiente trabajo es implementar
remitente HTTP v1 con estos secretos, registro seguro de dispositivos, eventos e
historial con RLS, bandeja y navegación con login. `enablePushNotifications`
continúa en false hasta completar ese flujo. No pedir de nuevo la credencial.

Fuentes: [FCM](https://firebase.google.com/products/cloud-messaging),
[precios](https://firebase.google.com/pricing),
[recepción Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

## Actualización posterior: primer envío programado

El canal de prueba, registro de dispositivos y bandeja ya se implementaron;
`enablePushNotifications` ahora está en true. Migración aplicada y función
`enviar-notificacion-prueba` desplegada. La descripción anterior de flujo aún
deshabilitado es histórica. El estado actual, pasos para el emulador y pendientes
operativos están en [PRIMERA_PRUEBA_FCM_2026-11-23.md](PRIMERA_PRUEBA_FCM_2026-11-23.md).
Todavía debe comprobarse visualmente la primera entrega; los eventos automáticos
de solicitudes no forman parte de esta primera prueba.
