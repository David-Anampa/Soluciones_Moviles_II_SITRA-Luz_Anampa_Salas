# HU-012 y contrato para HU-020

Fecha: 15 de octubre de 2026. Implementación preparada; pendiente de aplicar SQL y validación manual del equipo. No se ejecutaron migraciones, análisis Flutter, pruebas ni capturas durante este trabajo.

## Aplicar en Supabase

1. La base existente debe tener las migraciones de recepción y HU-002. La consulta de estructura del 13 de octubre confirmó ambas; HU-012 es nueva.
2. Ejecutar únicamente `migracion_hu012_catalogos_2026_10_15.sql` en SQL Editor. Es transaccional: si falla una instrucción, no continuar ejecutando fragmentos sueltos.
3. Iniciar sesión como Administrador y abrir la tarjeta **Financiamientos, seguros y áreas**. La ruta es `/admin/catalogos`.
4. Para una base nueva, el `setup_sitra_luz.sql` ya contiene esta migración al final. No ejecutar el setup completo sobre la base actual.

No hay datos ficticios de seguros/convenios ni descuentos inventados. Se crean desde la aplicación.

## Interfaz de HU-012

- Dos pestañas: **Áreas** y **Seguros y convenios**.
- Búsqueda, filtros de habilitación y, para financiamientos, filtro Seguro/Convenio.
- Tarjetas móviles con descripción, estado y acciones. Tocar una tarjeta abre la edición.
- Crear/editar desde un formulario desplazable; cabecera roja y acciones visibles, texto/iconos blancos sobre rojo, tonos pastel y grises, tipografía de la aplicación y hover en controles.
- Áreas: código visible editable y único, nombre, descripción y configuración de stock propio. Si no se escribe código al crear, se genera `AREA-001`, etc.
- Seguros/convenios: nombre, descripción, tipo, porcentaje entre 0 y 100 con dos decimales, y lista seleccionable de medicamentos. Búsqueda y filtro de seleccionados conservan la selección. Vista previa sobre Kairos; precios ausentes se muestran como no registrados, no como cero.
- Las acciones de tarjeta utilizan solo iconos, tooltip, hover y objetivos táctiles de 48 px. El icono de usuario aparece verde si está habilitado y rojo si está deshabilitado; tocarlo cambia el estado directamente, sin modal, y muestra el resultado tras guardar. Se bloquean pulsaciones mientras se procesa.
- Eliminar mantiene su modal de confirmación. El servidor determina si existen asociaciones antes de eliminar. Crear/editar conservan sus formularios con Guardar/Cancelar. Agregar utiliza un botón flotante de icono más.
- Deshabilitar conserva historial, stock y asignaciones anteriores; bloquea nuevas selecciones y asignaciones. Los pedidos existentes pueden terminarse. No se borra ni se reasigna stock automáticamente.

## Estructura de áreas y compatibilidad

- `areas.id`: UUID estable para asociaciones nuevas.
- `areas.codigo_interno`: identificador visible `AREA-001`, único sin distinguir mayúsculas; editable desde HU-012.
- `areas.codigo`: alias operativo existente (por ejemplo `FARMACIA`, `ALMACEN` o `SOP`). No es el código visible del formulario. Se conserva porque los pedidos, stock y funciones actuales lo utilizan. Las áreas nuevas reciben un alias técnico estable.
- `nombre`, `descripcion`, `activo`, `administra_stock`, `created_at`, `updated_at`. El antiguo `stock_minimo_alerta` se conserva por compatibilidad; HU-012 no implementa mínimos diferentes por producto ni consumo de botiquines.
- La migración no cambia nombres/descripciones actuales de las áreas. Administrador puede editarlos, por ejemplo nombre `SOP` y descripción `Sala de Operaciones`.
- Cambiar nombre o código visible conserva la identidad del área. Las asignaciones normalizadas usan UUID y los tokens anteriores del perfil se normalizan al alias operativo cuando corresponda.
- Farmacia y Almacén pueden deshabilitarse, lo que impide nuevos pedidos entre ellas; las operaciones existentes continúan. No pueden eliminarse porque el flujo de abastecimiento las necesita. La aplicación muestra el motivo.

## Seguros, convenios y precios

- `financiamientos`: UUID, nombre, descripción, tipo `SEGURO`/`CONVENIO`, porcentaje de descuento, habilitación y fechas.
- `financiamiento_medicamentos`: relación única seguro/convenio–medicamento. Un porcentaje por registro y una lista de medicamentos incluidos, no un descuento global sobre todo el catálogo.
- Nombre, descripción, tipo, porcentaje y cobertura son editables. Guardar porcentaje y lista es una sola transacción con auditoría.
- Particular se representa en la ficha con `tipo_atencion='PARTICULAR'` y `financiamiento_id=NULL`; no hay una fila Particular en el catálogo.
- La futura HU-003 mostrará Tipo de atención (Particular/Seguro/Convenio) y después el registro habilitado del tipo elegido. Al cambiar el primer combo, limpiar el segundo.
- Solo los medicamentos incluidos tienen descuento. Los demás y Particular utilizan Kairos completo.
- `cotizar_medicamento_hu012(p_medicamento_id,p_financiamiento_id)` devuelve el Kairos, porcentaje efectivo y precio unitario redondeado. Rechaza precios ausentes; no guarda ni factura.
- Se prepararon `dispensaciones.tipo_atencion`, `financiamiento_id`, `financiamiento_nombre_aplicado` y los campos `precio_kairos_aplicado`, `porcentaje_descuento_aplicado`, `precio_unitario_aplicado` de los ítems. Los campos de valor histórico anteriores quedan NULL; no se inventa una valorización.
- HU-003/HU-010 deberán guardar los snapshots al momento operativo acordado y reutilizarlos para documentos e historial; nunca recalcular una ficha antigua con el descuento o la cobertura actual. HU-012 no implementa todavía esas pantallas, el cobro, ni la afiliación de pacientes.
- Eliminar un seguro/convenio sin fichas elimina solo su configuración de cobertura. La auditoría conserva los valores anteriores. Si tiene fichas, se bloquea y se ofrece deshabilitarlo.

## Contrato para David — HU-020/HU-021/HU-022

- No se implementaron listado, alta o edición de usuarios: corresponden a David. Esta entrega prepara la estructura.
- `profiles` conserva `id`, `email`, `nombre`, `rol`, `areas_asignadas`, `activo`, fechas y FCM. Se añaden `cargo TEXT` y `correo_drive TEXT`, ambos opcionales para no romper usuarios actuales.
- Columnas de HU-020: nombre, cargo, correo de acceso, rol, áreas, estado y acciones. No mostrar tokens ni contraseñas. En móvil utilizar tarjetas.
- Roles existentes: ADMINISTRADOR, JEFATURA_FARMACIA, FARMACIA, ALMACEN y ENFERMERIA. Doctor no es un rol de acceso: se selecciona desde `doctores` en la ficha; especialidad y doctor de turno se guardarán en esa ficha.
- `profile_areas(profile_id,area_id)` contiene relaciones estables por UUID y es de solo lectura para la aplicación. La migración copia las coincidencias existentes por código/nombre sin borrar tokens históricos no reconocidos.
- Para guardar las áreas desde el futuro servicio seguro de usuarios: consultar `areas(id,codigo,codigo_interno,nombre,activo)`; mostrar nombre/código visible y guardar los valores de **`areas.codigo`** en `profiles.areas_asignadas`. El trigger sincroniza `profile_areas` en la misma transacción. No escribir directamente la tabla puente desde Flutter.
- Nuevas asignaciones solo admiten áreas habilitadas. Un usuario existente puede conservar una asignación deshabilitada; no quitarla silenciosamente al editar otros datos.
- El alta de usuarios requiere un servicio autorizado para Supabase Auth; no insertar usuarios mediante una service-role key en Flutter. Las restricciones de HU-002 siguen vigentes y protegen los nuevos campos del perfil.
- El correo de Drive es configuración; no equivale a una autorización OAuth.

## API de escritura

La aplicación llama `administrar_catalogo_hu012(p_entidad,p_accion,p_id,p_datos)`. Entidades: AREA/FINANCIAMIENTO. Acciones: GUARDAR/ESTADO/ELIMINAR. La función exige Administrador activo, comprueba asociaciones, bloquea filas y registra usuario, antes y después en auditoría. Las tablas de catálogo se consultan con SELECT; sus cambios no se envían con INSERT/UPDATE/DELETE directos desde Flutter.

## Comprobación manual sugerida al equipo

1. Crear un área, editar código/nombre/descripcion y comprobar unicidad. Confirmar que la lista refleja los cambios después de recargar.
2. Deshabilitarla: debe seguir en el filtro Deshabilitados y conservar su historial. Al implementar fichas/usuarios, comprobar que no aparece en nuevas selecciones y que un intento directo de nueva asignación se rechaza.
3. Eliminar un área nueva sin asociaciones. Intentar eliminar una con asignaciones, movimientos o stock: debe bloquearse sin borrar referencias.
4. Crear seguro y convenio con cobertura diferente. Editar porcentaje y lista, buscar medicamentos, usar Solo seleccionados y guardar. Recargar y comprobar que la selección persiste.
5. Probar porcentaje vacío, negativo, superior a 100 y códigos/nombres duplicados. No deben guardarse.
6. Usar un medicamento incluido y otro no incluido: la cotización del primero lleva descuento y la del segundo Kairos completo. Kairos ausente debe pedir registrar el precio.
7. Confirmar con un usuario no Administrador que no puede abrir la ruta ni ejecutar la RPC de gestión.
8. Revisar auditoría y luego el flujo de abastecimiento existente: los códigos visibles nuevos no deben cambiar los alias FARMACIA/ALMACEN utilizados por stock y pedidos.

Estos pasos son para que Walter y David validen la entrega; no se ejecutaron automáticamente.
