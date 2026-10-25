# HU-020, HU-021 y HU-022 — habilitar, crear y editar usuarios

## Actualización del 25 de octubre de 2026 — correo único

La ampliación de colegiatura, especialidad, fuentes y estado real de despliegue
se detalla en `GUIA_COLEGIATURA_Y_ESPECIALIDADES_2026_10_25.md`.

El formulario y el detalle utilizan un solo correo: el de Supabase Auth, reflejado
en `profiles.email`. También será la referencia para vincular Google Drive en
HU-027; guardar el correo no autoriza el acceso a Google ni selecciona una carpeta.

Después de las migraciones HU-020 y HU-021/HU-022, aplicar
`migracion_hu020_hu021_hu022_correo_unico_2026_10_25.sql`.
Está incorporada al final del setup. La columna `correo_drive` se conserva únicamente
como dato heredado, sin mostrarse, recibirse ni actualizarse mediante las nuevas RPC.
La migración no modifica correos de acceso ni borra los valores heredados.

La migración de correo único y las migraciones de estructura, gestión y colegiatura
se aplicaron a Supabase el 25 de octubre, con verificación de estructura y permisos.
El estado de Edge Function y validaciones está detallado en la guía de colegiatura.

Fecha: 22 de octubre de 2026. Entrega de David Anampa (Sprint 4, semana 1). Implementada en código; **pendiente de aplicar SQL, desplegar la función y validar manualmente**. No se ejecutaron pruebas funcionales ni `flutter analyze` (el SDK local, Dart 3.9.2, no resuelve las dependencias del proyecto, que piden Dart ≥ 3.10).

## Qué se entrega

| HU | Funcionalidad |
|---|---|
| HU-020 | Habilitar/deshabilitar desde la tarjeta (icono de persona verde/rojo) con confirmación. |
| HU-021 | Botón flotante **Nuevo usuario**: alta de cuenta de acceso y perfil. |
| HU-022 | Icono de lápiz: edición de nombres, apellidos, usuario, cargo, correo de Drive, rol y áreas. |

## Pasos para activarlo (en este orden)

1. **SQL:** ejecutar `migracion_hu021_hu022_gestion_usuarios_2026_10_22.sql` en el SQL Editor (requiere HU-012 y HU-020 aplicadas). Es transaccional. No ejecutar el `setup` completo sobre la base existente.
2. **Edge Function:** desplegar `supabase/functions/crear-usuario` con `supabase functions deploy crear-usuario`. Supabase inyecta `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY`; no hay que copiar ninguna clave en Flutter.
3. Para una base nueva, el `setup_sitra_luz.sql` ya incluye la migración (sección 20). La función se despliega igualmente aparte.

## Diseño y decisiones

- **Una sola validación en el servidor.** `hu021_normalizar_perfil` valida y normaliza los datos; la reutilizan la edición y el alta. Flutter replica las reglas en `UsuarioValidadores` solo para dar respuesta inmediata.
- **Alta atómica (todo o nada).** La función crea la cuenta en Auth, completa el perfil con `registrar_perfil_usuario_hu021` y, si eso falla, elimina la cuenta recién creada.
- **Clave service-role solo en el servidor.** La función verifica con el token del solicitante que sea Administrador activo. `registrar_perfil_usuario_hu021` solo se puede ejecutar con `service_role` y acepta únicamente perfiles pendientes (`activo = false`).
- **Auditoría.** Cada operación registra `USUARIO_CREAR`, `USUARIO_EDITAR` o `USUARIO_ESTADO` con el antes y el después, sin tokens FCM ni contraseñas.
- **Sin eliminación.** Deshabilitar conserva el historial y bloquea el acceso.
- **Protecciones.** No se puede deshabilitar ni cambiar el rol de la propia cuenta, y debe quedar al menos un Administrador activo. La interfaz bloquea la acción y el servidor la rechaza igualmente.
- **Contraseña.** Campo oculto con opción de mostrar, mínimo 8 caracteres con letras y números. Solo existe al crear; HU-022 no la precarga. No se guarda en `profiles`.
- **Correo electrónico.** Se define al crear y no se edita (pertenece a Supabase Auth). Es el único correo del formulario y se reutiliza para la futura vinculación con Drive.
- **Áreas.** Se guardan con `areas.codigo`. Solo se ofrecen las habilitadas; las ya asignadas se conservan aunque se deshabiliten, para no quitarlas en silencio. El trigger de HU-012 sincroniza `profile_areas`.
- **Nombre completo.** Al guardar nombres y apellidos, `profiles.nombre` se actualiza como `nombres + ' ' + apellidos`, como pide el contrato de HU-020.

## Código

| Capa | Archivo |
|---|---|
| Dominio (Dart puro) | `domain/usuario_validadores.dart`, `domain/usuario_borrador.dart` |
| Datos | `data/usuarios_repository.dart` (`crear`, `editar`, `cambiarEstado`, `mensajeError`) |
| Presentación | `usuario_formulario_view.dart` (alta y edición), `usuarios_admin_view.dart` (acciones) |
| Servidor | `supabase/functions/crear-usuario/index.ts`, migración SQL |
| Pruebas | `app/test/usuario_validadores_test.dart` |

## Validación manual sugerida

1. Crear un usuario con cada rol y verificar que inicia sesión y ve solo su menú (HU-002).
2. Crear con un correo ya registrado, un usuario duplicado y una contraseña débil: no debe quedar ninguna cuenta a medias.
3. Editar nombres, cargo, rol y áreas; recargar y comprobar que persisten y que `nombre` se actualiza.
4. Deshabilitar a un usuario y comprobar que no puede entrar; volver a habilitarlo.
5. Con el único Administrador: intentar deshabilitarse y cambiarse el rol (debe rechazarse).
6. Probar con un usuario no Administrador la función y las RPC: deben responder 403 o error de permisos.
7. Revisar `auditoria_trazabilidad`: eventos `USUARIO_*` sin datos sensibles.
8. Sin la función desplegada o sin la migración, la app debe mostrar un aviso claro, no datos de demostración.

No incluido: restablecer contraseñas de usuarios existentes, ni login por nombre de usuario.
