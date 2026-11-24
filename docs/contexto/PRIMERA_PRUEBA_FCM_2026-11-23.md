# Primer envío FCM en Android — 23/11/2026

## Alcance de esta entrega

Primera integración real del canal Firebase: campana en los cinco menús,
bandeja por destinatario, permiso Android, registro privado de varios dispositivos
por usuario, renovación del token, desvinculación al cerrar sesión y envío de una
prueba al dispositivo propio. Supabase sigue gestionando autenticación y datos.

La bandeja usa los colores del rol, iconos, fecha y hora local, indicador de no
leído, detalle y paginación. El contador es exacto para avisos no leídos; no es el
contador de solicitudes pendientes del panel de cada área. Leer un aviso no
despacha, acepta, cancela ni modifica ninguna operación.

Al tocar un push se abre `/notificaciones?aviso=<uuid>`. Sin sesión conserva el
destino, solicita login y después abre la bandeja. Una cuenta distinta no puede
leer el aviso original. Las rutas de los mensajes nunca se usan como URLs libres.
Los avisos de prueba son genéricos y no incluyen pacientes, credenciales ni stock.

## Servidor y seguridad

- Migración aplicada: `docs/supabase/migracion_notificaciones_fcm_2026_11_23.sql`.
- Tablas nuevas: `dispositivos_push` y `notificaciones`, ambas con RLS.
- Ningún cliente puede consultar tokens, crear notificaciones o ejecutar la RPC
  privada `preparar_prueba_push`. El destinatario solo consulta sus avisos y
  marca como leídos mediante RPC. Comprobado con metadatos de permisos remotos.
- Edge Function desplegada: `enviar-notificacion-prueba`, con `auth.getUser()`
  explícito, comprobación de perfil activo y dispositivo de ese usuario.
- Usa OAuth2 y FCM HTTP v1; claves privadas exclusivamente en los secretos ya
  instalados, `FIREBASE_SERVICE_ACCOUNT_JSON` y `FIREBASE_PROJECT_ID`.
- Pruebas limitadas a una cada 30 segundos; bloqueo de doble pulsación y de
  solicitudes concurrentes. Un reintento en la misma sesión conserva su UUID.
  Un envío ya confirmado por el servidor no vuelve a ejecutarse con ese UUID.
- Si la red corta después de que Firebase acepte, la entrega puede ser incierta:
  revisar la bandeja antes de reintentar. FCM no garantiza entrega exactamente
  una vez. En Android se reutiliza el identificador del aviso como etiqueta.
- El estado `enviado` indica aceptación de Firebase, no recepción demostrada.
  No afirmar entrega hasta observarla en el emulador.
- Sin Internet, cerrar sesión intenta desvincular y borrar el token con tiempos
  limitados. Un aviso residual no concede acceso a datos y exige sesión válida.

## Prueba que realizará el usuario

1. Cargar esta compilación completa: incluye cambios nativos. Un hot reload no
   basta. Si se necesita depuración: desde `app`, `flutter devices` y después
   `flutter run -d <id_actual> --no-pub --no-dds`.
2. Iniciar sesión y tocar la campana del menú.
3. Pulsar **Activar avisos** y conceder permiso a Android.
4. Pulsar **Probar en este dispositivo**. Tras registrar el dispositivo, el
   envío espera cinco segundos. Para comprobar Android, pulsar **Inicio** del
   emulador durante esa espera, sin forzar detención ni cerrar la aplicación.
5. Debe aparecer el aviso **Tu conexión está lista**. Tocar el aviso: debe abrir
   su detalle en la bandeja y actualizar el contador de no leídos.
6. Con la aplicación visible, otra prueba (pasados 30 segundos) muestra un aviso
   interno con **Abrir**. Android no muestra automáticamente el banner del
   sistema en primer plano; ese comportamiento es deliberado.
7. Para revisar login, cerrar sesión tras una entrega y tocar el aviso que aún
   permanezca en Android: debe pedir acceso y luego abrir la bandeja. El token
   se desvincula al salir, por lo que no se envían nuevas pruebas sin sesión.

Si Android deniega permisos, habilitarlos en Ajustes → Aplicaciones → SITRA-Luz
→ Notificaciones. Si Firebase rechaza la cuenta o API, el resultado lo indica;
no sustituir la credencial por una clave pública del cliente.

El AVD es **Pixel_8_SITRA**; el identificador ADB cambia entre arranques. En esta
sesión se detectó `emulator-5554`; anteriormente fue `emulator-5556`.

## Comprobaciones y pendientes

`flutter analyze --no-pub`, compilación APK Android y comprobación de tipos Deno
del remitente correctos. Migración y función desplegadas en
`nedeqnvpkalrchswrapr`. Aceptación de la entrega en pantalla pendiente del usuario;
no se ejecutaron recorridos funcionales ni pedidos de prueba.

**Pendiente después de confirmar el primer push:** conectar eventos reales de
solicitudes y cambios de estado al remitente, resolver destinatarios por rol y
área, añadir referencias a pedidos y navegación autorizada a sus detalles,
cola/reintentos del servidor y auditoría de dichos eventos. La tabla actual
acepta exclusivamente `PRUEBA`; ese alcance necesita una migración adicional.
Los paneles de trabajo por área ya existentes siguen operando por separado.
No marcar completadas las historias de notificaciones operativas con esta prueba.

Referencia: [recepción Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
y [envío HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api).

## Confirmación del usuario y tono propio

El usuario confirmó que el aviso sí llega al emulador. Esta confirmación acredita
la recepción del push de prueba; no acredita todavía recorridos completos de
login, separación entre cuentas ni notificaciones automáticas de pedidos.

Se añadió un tono original de dos notas ascendentes, de 0,56 segundos, en
`app/android/app/src/main/res/raw/sitra_mensaje.wav`. No usa muestras de Twitter
ni dependencias nuevas. Fuera de la app usa ese sonido y una vibración de 60 ms;
en primer plano se conserva exclusivamente el aviso interno existente.

El canal actual es `sitra_avisos_mensaje_v2`, tanto en Android como en el remitente
y el canal predeterminado del manifiesto. Esta versión es necesaria porque
[Android no permite cambiar el sonido de un canal ya creado](https://developer.android.com/develop/ui/views/notifications/channels).
Se conserva la importancia anterior (incluido un canal silenciado), una selección
de sonido hecha expresamente por el usuario cuando Android permite consultarla,
y los ajustes del canal nuevo en los siguientes arranques. El canal anterior no
se borra. Los permisos generales, el volumen y No molestar siguen bajo control
de Android. Para cargar el recurso y canal nuevos hace falta instalar el APK
actualizado y abrir la aplicación; un hot reload no basta.

La bandeja es una primera entrega para pruebas e historial. El flujo operativo
de Almacén sigue siendo la fuente del estado de los pedidos de Farmacia: el
futuro aviso debe dirigir al pedido autorizado, nunca atenderlo al leerlo.

## Uniformidad de pedidos — 24/11/2026

Aplicado `TemaPedidos` a solicitudes Almacén–Farmacia y registro, listado y
detalle de pedidos clínicos: botones con medidas compartidas, tarjetas con
espaciado coherente, franjas de sección con icono y texto blanco en color del
rol mediante el mismo componente de los menús. Se retiraron referencias HU/RF
de etiquetas visibles y descripciones decorativas; se conservaron instrucciones
de cantidades, diferencias, cobertura y justificaciones. Los nombres y textos
clínicos pueden crecer en varias líneas, respetando la escala del sistema.

El registro ofrece Neonatología y Otras áreas. Las opciones se habilitan solo
si existen áreas autorizadas de ese tipo en el catálogo. Otras áreas muestra
un dropdown filtrado; Neonatología selecciona su área (permite elegir si hay
varias). El cambio reutiliza `_cambiarArea`, que actualiza receptor y kit como
antes, y al pasar a un área no neonatal fija el tipo GENERAL. No reasigna el
área durante el despacho de una ficha existente. No se añadieron áreas ficticias.

Sin cambios en SQL, consultas, permisos, acciones de stock o auditoría. Los
contadores y la conexión pendiente de avisos operativos conservan su alcance
anterior. `flutter analyze --no-pub` correcto; revisión visual en el emulador y
aceptación funcional pendientes del usuario. No se ejecutaron pedidos de prueba.
