# Gestión de usuarios — estructura y listado

15 de octubre de 2026. Entrega de Walter: acceso desde el menú Administrador y consulta real con búsqueda/filtros. Crear/editar cuentas y cambiar su habilitación siguen asignados a David.

## Acceso y comportamiento

- Administrador → **Gestión de usuarios** (`/admin/usuarios`). La protección de rutas HU-002 restringe este apartado y la nueva RPC solo admite Administrador activo.
- Consulta usuarios existentes de Supabase con paginación. No genera perfiles de ejemplo.
- Resumen táctil Todos/Habilitados/Deshabilitados. Tocar un contador filtra el listado.
- Búsqueda por palabras sobre nombre, usuario, correo, cargo, rol y áreas. Combina filtros de habilitación, rol y área; orden por nombre o fecha de registro. Los filtros se construyen con los datos existentes y se pueden limpiar.
- Tarjetas con nombre, cargo/rol, usuario, correo, áreas y estado. Tocar la tarjeta o el icono de ojo abre un detalle desplazable con todos los datos y fechas.
- Actualización al deslizar hacia abajo; cabecera roja con flecha blanca, fondos claros, iconos, hover y espaciado táctil.
- Los estados son informativos en esta entrega. No hay botones falsos de crear, editar, habilitar o eliminar; David añadirá las acciones reales en sus HU.

## Migración y campos

Ejecutar `migracion_hu020_estructura_usuarios_2026_10_15.sql` después de HU-012. El `setup` contiene ambos scripts para reconstruir una base nueva. No ejecutar el setup sobre la base existente.

- Nuevos campos: `profiles.nombre_usuario`, `nombres` y `apellidos`.
- `nombre_usuario`: 3–32 caracteres, minúsculas, números, punto, guion o guion bajo; comienza con letra o número; único sin distinguir mayúsculas. Para perfiles existentes se deriva del correo, agregando un sufijo si hace falta para evitar duplicados.
- Se conserva `profiles.nombre` (nombre completo histórico). No se divide automáticamente: títulos y apellidos compuestos harían inseguro inferir la separación. `nombres` y `apellidos` quedan pendientes de completar mediante HU-022. El listado muestra el nombre completo actual mientras tanto.
- `cargo` se preparó en HU-012 y no equivale a rol. Desde el ajuste del 25 de octubre se muestra únicamente `email`; `correo_drive` queda como columna heredada sin uso en la gestión de usuarios. Se conserva un solo campo Cargo / ocupación, sin agregar Profesión. Los doctores se mantienen como registros seleccionables, sin crear un nuevo rol de acceso. Ver `GUIA_COLEGIATURA_Y_ESPECIALIDADES_2026_10_25.md`.
- `listar_usuarios_hu020(p_desde,p_limite)` pagina y devuelve exclusivamente los campos de perfil necesarios. No devuelve FCM, contraseñas ni datos de `auth.users`.
- Si todavía no existe la RPC, la vista puede consultar los campos originales de los perfiles y avisa que faltan los nuevos campos de estructura. No inventa nombres de usuario, cargos ni nombres/apellidos separados. Los errores de permiso o conexión no se reemplazan por datos de demostración.

## Credenciales: contrato para David

- El nombre de usuario es un identificador de perfil. Esta entrega no cambia el login actual por correo ni implementa login por nombre de usuario.
- Contraseña no es una columna pública, no se muestra en tarjetas ni se devuelve desde la API. Supabase Auth almacena su hash; no se puede recuperar la contraseña original.
- HU-021 puede pedir la contraseña inicial con campo oculto y opción de mostrar mientras se escribe; se entrega al servicio autorizado de alta de Supabase Auth y no se guarda en `profiles`.
- HU-022 no precarga contraseñas. Restablecer credenciales requerirá su flujo autorizado; no simular una contraseña existente con puntos.
- Cuando David guarde nombres/apellidos separados, deberá mantener `profiles.nombre` como nombre completo para las pantallas actuales y la trazabilidad.
- Crear cuenta y perfil requiere servicio autorizado. Ninguna clave service-role debe incluirse en Flutter.
- Mantener los permisos y asociaciones de área descritos en `GUIA_HU012_Y_CONTRATO_HU020.md`.

## Validación manual del equipo

1. Entrar como Administrador, abrir la tarjeta nueva y comparar la lista con los perfiles reales registrados.
2. Buscar por correo/nombre y combinar rol, área y habilitación. Limpiar filtros debe recuperar todos los usuarios consultados.
3. Abrir detalle: revisar datos completos, áreas y fechas. Los campos anteriores no registrados deben indicar Sin registrar, sin inventar valores.
4. Aplicar la migración, actualizar al deslizar hacia abajo y comprobar los nombres de usuario generados. El nombre completo anterior debe conservarse.
5. Entrar con otro rol y confirmar que la ruta administrativa redirige y que la nueva RPC rechaza acceso.

No se ejecutaron esta migración, pruebas, análisis Flutter ni capturas durante la entrega. Esta guía no declara HU-020 completa: la parte de habilitación y su integración funcional siguen pendientes.
