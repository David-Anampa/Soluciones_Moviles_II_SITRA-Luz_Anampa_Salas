# HU-002 — Sesión y permisos por rol

Fecha: 13 de octubre de 2026.

Estado: implementada en código y SQL; pendiente de aplicar la migración y validar manualmente. No se ejecutaron pruebas, análisis automáticos, capturas ni cambios en Supabase remoto durante esta implementación.

## Permisos acordados

| Rol | Acceso |
|---|---|
| Administrador | Accede a todos los módulos y administra perfiles y datos maestros. Las correcciones de pedidos respetan estados y usan la misma RPC que los otros roles. No puede borrar pedidos ni editar/eliminar auditorías desde la aplicación. |
| Jefatura de Farmacia | Accede a su dashboard y consulta información; no modifica inventario, catálogo ni pedidos. |
| Almacén | Registra medicamentos y lotes, gestiona stock operativo y toma, rechaza y despacha pedidos de Farmacia. |
| Farmacia | Crea solicitudes a Almacén, cancela pendientes y confirma recepción conforme o con devolución. Consulta inventario y los datos necesarios para el flujo. |
| Enfermería/Técnico | Consulta el inventario de Farmacia y Almacén y el de sus propias áreas, sin modificarlo. Las fichas y los kits están delimitados a sus áreas asignadas. Su flujo funcional se desarrollará en próximos sprints. |

En la futura vista HU-023 se mostrarán por separado stock de Farmacia y stock de Almacén. El total será informativo: el stock de Almacén requiere abastecimiento a Farmacia antes de dispensarse. Enfermería solicitará a Farmacia; Farmacia solicitará el traslado a Almacén cuando lo necesite. Esta sesión no implementa HU-023 ni los pedidos de kits.

## Cambios realizados

- GoRouter redirige al dashboard propio ante un intento de entrar a rutas de otro rol. Administrador puede entrar a los módulos existentes.
- Un rol desconocido deja de convertirse en Administrador; se rechaza el perfil.
- La interfaz escucha cambios de sesión, restaura la sesión al iniciar y elimina la suscripción al disponer el ViewModel.
- Se rechazan perfiles inexistentes, inactivos o con rol inválido; se intenta cerrar su sesión local.
- El cierre de sesión limpia inmediatamente la identidad en la interfaz y no oculta errores de Supabase.
- Al cambiar identidad, rol o áreas se limpia el estado compartido de inventario. Las respuestas de cargas anteriores no se incorporan después de ese cambio.
- Crear un pedido exige un usuario autenticado; se retiró el uso del primer perfil como sustituto del solicitante.
- Los errores explícitos de permisos al consultar catálogo/inventario no se sustituyen por datos de demostración.
- Las políticas SQL usan el perfil activo vinculado a `auth.uid()` y las áreas asignadas. No se confía en un rol enviado por Flutter.
- El usuario común solo puede actualizar su FCM token. No puede cambiar su rol, áreas, nombre ni estado activo.
- Registrarse o elegir un email con la palabra “admin” ya no concede privilegios. Los perfiles nuevos quedan inactivos, sin áreas, hasta que Administración los configure mediante un servicio autorizado o desde Supabase. Los perfiles existentes no se modifican.
- Los pedidos y despachos no reciben UPDATE/DELETE directo desde el cliente; las transiciones usan la RPC. La RPC permite al Administrador operar respetando las mismas reglas de estado y stock.
- La auditoría no recibe UPDATE/DELETE para usuarios de la aplicación. Jefatura queda en lectura.

## Migración y reconstrucción

Para la base existente, ejecutar:

`docs/supabase/migracion_hu002_permisos_sesion_2026_10_13.sql`

Requiere que ya esté aplicada `migracion_recepcion_pedidos_2026_10_12.sql`. Ejecutar las migraciones en orden; no volver a aplicar la anterior después de HU-002 porque contiene la versión anterior de permisos de despachos.

Para reconstruir una base nueva, `docs/supabase/setup_sitra_luz.sql` contiene ambas migraciones y el estado final de permisos. No ejecutar el setup completo sobre una base existente para actualizarla.

La migración no borra registros ni altera los perfiles actuales. Reemplaza las políticas existentes únicamente de las tablas del sistema indicadas en el script y restringe sus privilegios.

Las áreas de un perfil pueden estar guardadas como código o como nombre exacto del área. Deben corresponder a una fila de `public.areas`. Por ejemplo, `SOP` o el nombre de esa área. Un área no registrada no concede acceso a fichas o stock de otras áreas.

## Revisión manual a cargo del usuario

1. Ejecutar la migración HU-002 en SQL Editor y reiniciar la aplicación.
2. Entrar con cada rol y comprobar que llega a su dashboard.
3. En la versión web, intentar entrar a `/admin`, `/almacen` o `/farmacia` con un rol distinto: debe volver a su propio dashboard. Administrador puede abrirlos.
4. Cerrar sesión, iniciar con otro usuario y comprobar que no aparecen datos de la sesión anterior.
5. Cerrar y volver a abrir la aplicación con una sesión válida: debe recuperarse el usuario y su rol.
6. Verificar que Farmacia puede crear/cancelar/recibir y Almacén puede tomar/rechazar/despachar, sin intercambiar responsabilidades.
7. Con una sesión de Jefatura o Enfermería, comprobar mediante el cliente autenticado que no pueden escribir inventario ni operar la RPC de abastecimiento.
8. Comprobar que un usuario común no puede cambiar `rol`, `activo` o `areas_asignadas` de su perfil; la sincronización del FCM token sí está permitida.
9. Comprobar que UPDATE/DELETE de auditoría está denegado incluso para el Administrador de la aplicación.
10. Al desarrollar las fichas en próximos sprints, comprobar que Enfermería solo ve fichas y kits de las áreas que tiene asignadas.

SQL Editor utiliza un usuario privilegiado de base de datos y no sirve por sí solo para demostrar los límites de un rol de la aplicación. Las comprobaciones de RLS deben usar una sesión autenticada del rol correspondiente. Esta implementación no se marcó como probada.

El cierre por inactividad de 15 minutos es RNF-013 y sigue pendiente; no se añadió silenciosamente en HU-002.
