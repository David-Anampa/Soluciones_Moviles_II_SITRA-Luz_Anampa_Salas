# HU-003 — receptor, médico y confirmación de guardado

Fecha: **22/11/2026**. Alcance: los tres puntos de HU-003 solicitados por Walter.
No cierra toda la HU ni modifica las reglas pendientes de kits/consumo/anulación.

## Necesidad comprobada en Supabase

Antes de migrar se inspeccionaron las funciones instaladas en una transacción de
solo lectura. Se confirmó que:

- `registrar_ficha_hu003` permitía médico manual y validaba al receptor únicamente
  por existencia/activo, sin exigir rol y asignación al área.
- `procesar_ficha_dispensacion_hu008_hu011` buscaba al receptor solo por ID.
- No existía `validar_receptor_ficha_hu003`.
- Los bloques de ambas funciones eran compatibles con el parche incremental.

Por tanto, **sí era necesario modificar Supabase**, no solo el formulario Flutter.
La migración fue aplicada y verificada en el proyecto remoto el 22/11/2026.

## Cambios

1. `validar_receptor_ficha_hu003(UUID,TEXT)` comprueba sesión/perfil activo del
   actor; exige receptor identificado, activo, con rol ENFERMERIA (Enfermería/Técnico)
   y relación real en `profile_areas` con el área activa solicitante. Devuelve su
   nombre canónico. Enfermería solo valida dentro de sus propias áreas.
2. Registro y entrega usan el mismo validador. La entrega revalida la asignación
   vigente aunque el receptor fuera válido cuando se creó el pedido.
3. Registro exige `doctor_id` del catálogo activo; el nombre se obtiene del servidor.
   No se admiten un médico ni un receptor representados únicamente por texto libre.
4. La pantalla elimina médico manual y la recepción elimina receptor manual.
   Sin médicos o receptores adecuados se muestra un aviso para corregir el catálogo
   o la asignación. Un área sin receptores no ofrece usuarios de otras áreas.
5. `guardarFichaConActualizacion` separa el guardado de las consultas posteriores.
   Si el guardado falla se conserva el error y el identificador de reintento.
   Si se guardó y solo falla actualizar lista/stock, devuelve la ficha confirmada,
   limpia el formulario y muestra advertencia explícita de que ya está guardada;
   no se vuelve a enviar para refrescar. Se conserva la ficha en el listado local.

Las fichas históricas no se reescriben: permanecen consultables. Para editar una
ficha antigua con datos manuales, o confirmar una sin receptor válido, se debe
seleccionar el médico/receptor actual permitido antes de operar.

## Migración incremental

Archivo: [migracion_hu003_receptor_medico_2026_11_22.sql](migracion_hu003_receptor_medico_2026_11_22.sql).
También se incorporó al final de `setup_sitra_luz.sql` para nuevas instalaciones.

- No crea usuarios, cambia contraseñas ni ejecuta escrituras sobre las fichas,
  stock, perfiles o auditoría existentes.
- Añade un validador y cambia exclusivamente los bloques de médico/receptor de
  las dos funciones, conservando sus otros controles y diferencias instaladas.
- Reconoce las versiones con/sin comentarios de las migraciones y del setup.
  Normaliza finales de línea; se detiene en transacción si encuentra una versión
  no reconocida. Es reaplicable sin duplicar cambios.
- Requiere el registro HU-003 instalado. Si Sprint 7 aún no existe, deja su parche
  de entrega pendiente; se reaplica después de instalarlo.
- No usar el setup completo ni las semillas antiguas sobre la base existente.
  Si se reinstala una migración anterior que reemplaza estas funciones, reaplicar
  esta corrección al final.

## Verificación ejecutada

- **14 pruebas Dart aprobadas**: pruebas existentes de validadores y regresiones
  dirigidas de médico/receptor, filtro estricto de área y guardado frente a fallos
  posteriores de lista/stock. También se comprobó que un error real de guardado
  se propaga sin lanzar consultas posteriores.
- **SQL en base local aislada**: receptor válido; rechazo por rol incorrecto,
  inactividad, otra área, falta de identidad y sesión; rechazo de médico manual
  y receptor ajeno al registrar; revalidación al entregar tras desactivar al receptor;
  reaplicación y modificación exclusiva de dos funciones existentes.
- Pruebas nuevas y base de prueba fuera del proyecto, en la carpeta de trabajo
  externa `C:\Users\ASUS\Documents\Codex\2026-10-25\empe\work`.
- `flutter analyze --no-pub`: **No issues found**.
- **Supabase después de migrar**: validador instalado y usado por registro/entrega,
  médico manual retirado, solo dos funciones existentes modificadas. Huellas de
  datos iguales antes/después en perfiles, asignaciones, áreas, médicos, fichas,
  ítems y stock. No se crearon pedidos ni consumos de prueba remotos.

Los cambios locales de `app/android/gradle.properties` pertenecen al usuario y
no forman parte del commit de esta corrección.

## Comprobación manual pendiente con el usuario

1. Hacer **Hot Restart** de la app para cargar la versión actual del formulario.
2. Abrir una ficha nueva: comprobar selector de médico, selector de receptor del
   área y ausencia de opciones para escribir esos nombres manualmente.
3. Cambiar de área: el receptor debe actualizarse; si no hay asignaciones, aviso y
   bloqueo de envío. Verificar el mismo comportamiento si no hay médicos activos.
4. Crear una ficha de prueba General y otra de Neonatología con selecciones válidas;
   consultar su número en Farmacia y comprobar cabecera, sin confirmar consumo aún.
5. Repetir la comprobación de edición sobre SOLICITADO. Para fallos posteriores
   de actualización ya existe prueba automatizada dirigida: no simularlos alterando
   datos ni permisos de producción.

Este es un cierre de los tres defectos concretos de código/contrato, **no una
declaración de aceptación funcional completa de HU-003**. Las restantes historias
del plan conservan sus pendientes.
