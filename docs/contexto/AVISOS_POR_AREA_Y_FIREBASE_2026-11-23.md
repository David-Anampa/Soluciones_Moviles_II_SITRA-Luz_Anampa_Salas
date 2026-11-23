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

En esta versión Firebase sigue desactivado: no existe `google-services.json` en
Android y el plugin está comentado. El servicio actual solo registra eventos y
contempla un token por perfil. No afirmar que ya envía o navega correctamente.

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

Fuentes: [FCM](https://firebase.google.com/products/cloud-messaging),
[precios](https://firebase.google.com/pricing),
[recepción Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
