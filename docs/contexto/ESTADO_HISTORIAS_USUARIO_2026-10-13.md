# Estado de las historias de usuario — SITRA-Luz

Fecha: 13 de octubre de 2026.

Revisé el código contra las historias documentadas. **Hay 11 HU con desarrollo real y 19 pendientes**, pero varias de las desarrolladas todavía tienen partes incompletas o problemas por corregir.

Esta fue una revisión estática: **no ejecuté pruebas ni modifiqué archivos**. “Implementada” significa que existe el flujo principal; todavía requiere tu validación funcional para pasar a **Listo** en Scrum.

Actualización posterior del 13 de octubre: por solicitud del usuario se ejecutó `flutter analyze`, se corrigió el import de la extensión de roles y el resultado fue `No issues found!`. Después se consultó exclusivamente la estructura de Supabase y se corrigió el `setup` local. No se ejecutaron pruebas funcionales ni SQL de modificación en la base remota; el análisis anterior no valida la reconstrucción ni las correcciones posteriores del script.

## 1. Autenticación y acceso

| HU | Historia | Estado y observación |
|---|---|---|
| HU-001 | Autenticar usuario | **Implementada.** Login real con Supabase, consulta de perfil y rechazo de usuarios deshabilitados. |
| HU-002 | Gestionar sesión y permisos por rol | **Implementada; pendiente de validación funcional manual.** La consulta de estructura de Supabase confirmó que las funciones y políticas HU-002 ya están instaladas. Se bloquearon rutas ajenas al rol, se sincronizó la sesión y se invalidan datos al cambiar de usuario. Administrador tiene menú de acceso a los módulos; Enfermería consulta stock de Farmacia, Almacén y sus áreas, sin modificarlo. Ver `HU-002_SESION_PERMISOS_2026-10-13.md`. |

## 2. Catálogo y registro de medicamentos

| HU | Historia | Estado y observación |
|---|---|---|
| HU-013 | Gestionar catálogo de medicamentos e insumos | **Implementada según el alcance del sprint; pendiente de validación funcional manual.** Consulta a PostgreSQL, búsqueda y filtros. Empezar sin productos o cargarlos mediante SQL no implica que la HU esté incompleta. La gestión corresponde a Almacén/Logística y Administrador. El Kardex se desarrolla en HU-025; las mejoras del catálogo se documentan como trabajo futuro. |
| HU-014 | Registrar mediante escaneo GTIN y fotografía | **Parcial.** Existen cámara, lectura del código y fotografía. La validación cruzada con IA todavía es simulada. |
| HU-015 | Revisar y corregir datos extraídos por IA | **Parcial.** El formulario permite revisar y guardar, pero no recibe una extracción real de Gemini/OCR. |
| HU-016 | Editar medicamento registrado | **Implementada en código; pendiente de validación funcional manual.** Existe formulario precargado y actualización en Supabase. La consulta remota confirmó `presentacion` y `laboratorio`; se corrigió el `setup` para reconstruir esos mismos campos. Edición por Almacén/Logística y Administrador. |

## 3. Inventario y trazabilidad

| HU | Historia | Estado y observación |
|---|---|---|
| HU-023 | Visualizar stock de Farmacia y Almacén | **Implementada; pendiente de aceptación funcional.** Existencias separadas de Farmacia, Almacén y En tránsito. Ver acuerdos del 26/10. |
| HU-024 | Registrar entrada de stock | **Implementada; pendiente de aceptación funcional.** Ingreso atómico de medicamento/lote, stock y auditoría; correcciones justificadas. Entradas externas en Almacén; Farmacia se abastece por traslado y recepción, sin duplicar una compra. Ver guía HU-024 del 26/10. |
| HU-025 | Visualizar trazabilidad de un ítem | **Parcial.** Se registran movimientos, pero falta la pantalla para consultar el historial completo por medicamento o insumo. |

## 4. Abastecimiento Farmacia → Almacén

| HU | Historia | Estado y observación |
|---|---|---|
| HU-029 | Registrar solicitud por faltantes de guardia | **Implementada; pendiente de aceptación funcional.** Creación atómica de cabecera, ítems y auditoría, con reintentos; conserva cancelación con motivo y solicitante desde sesión. Ver guía de abastecimiento del 25/10. |
| HU-030 | Visualizar y atender solicitudes | **Implementada; pendiente de validación funcional.** Incluye toma confirmada, preparación, rechazo, despacho, modalidad ENTREGA/RECOJO, recepción conforme, devolución por lote y auditoría mediante función transaccional. |

## 5. Fichas y pedidos Áreas → Farmacia

Estas historias **no quedan cubiertas por HU-029/HU-030**: corresponden a otro flujo.

| HU | Historia | Estado |
|---|---|---|
| HU-003 | Registrar ficha General o Neonatología | **Pendiente** |
| HU-004 | Seleccionar medicamentos e insumos con stock disponible | **Pendiente** |
| HU-005 | Aplicar kit al registrar ficha de Neonatología | **Pendiente** |
| HU-006 | Listar fichas con filtros | **Pendiente** |
| HU-007 | Mostrar detalle completo e historial de la ficha | **Pendiente** |
| HU-008 | Actualizar estados de preparación y despacho | **Pendiente** |
| HU-009 | Registrar cantidades despachadas y observaciones por ítem | **Pendiente** |
| HU-010 | Confirmar recojo y descontar stock de Farmacia | **Pendiente** |
| HU-011 | Anular ficha con motivo y permisos correspondientes | **Pendiente** |

Existen tablas base de dispensación, pero no el flujo completo de estas historias.

## 6. Kits de Neonatología y Quirófano

| HU | Historia | Estado |
|---|---|---|
| HU-017 | Listar y habilitar/inhabilitar kits | **Implementada en código el 22 de octubre por David Anampa; pendiente de ejecutar migración y validación manual.** Consulta kits reales con total de insumos, filtros dinámicos por estado y área, búsqueda en tiempo real, desglose expandible de medicamentos y activación/desactivación con confirmación (conserva historial). Ver `docs/supabase/GUIA_HU017_HU018_HU019_KITS.md`. |
| HU-018 | Crear kit | **Implementada en código el 22 de octubre por David Anampa.** Formulario reutilizable con selector dinámico de áreas activas y buscador de medicamentos del catálogo maestro de Supabase; guardado atómico mediante RPC transaccional `administrar_kit_hu018` con auditoría. |
| HU-019 | Editar kit | **Implementada en código el 22 de octubre por David Anampa.** Reutiliza el formulario de HU-018 con carga previa de ítems y cantidades. Cumple la regla de preservación estricta de historial clínico: la edición de la plantilla no altera las fichas o dispensaciones pasadas ni sus ítems previamente despachados; bloquea la eliminación si existen dispensaciones asociadas. |

**Actualización del 26/10 que sustituye el alcance de las filas anteriores:** HU-017/HU-018/HU-019 incluyen ahora permisos por área, checkbox para Técnica/Enfermera, selección de área de trabajo, lectura para Jefatura/Farmacia, variantes por duplicación, personalizados y consulta real de disponibilidad/laboratorio. Se corrigieron RPC ausente sin fallback, rol nulo y código canónico de área. La edición conserva el área histórica deshabilitada; no permite nuevas asignaciones allí. Migración vigente: `migracion_kits_por_area_2026_10_26.sql`, incluida al final del setup. **Implementación local terminada, pendiente de migración y validación manual; no marcar Listo todavía.** Ver `docs/supabase/GUIA_KITS_POR_AREA_2026_10_26.md`. No se ejecutaron suites de pruebas para esta actualización ni se certifica cobertura del 100%.

## 7. Administración

| HU | Historia | Estado |
|---|---|---|
| HU-012 | Gestionar financiamientos, seguros y áreas | **Implementada en código el 15 de octubre; pendiente de ejecutar migración y validación manual.** Administrador dispone de dos pestañas con búsqueda, filtros, creación, edición, habilitación y eliminación controlada. Seguros y Convenios incluyen porcentaje y lista de medicamentos con descuento sobre Kairos. Ver `docs/supabase/GUIA_HU012_Y_CONTRATO_HU020.md`. |
| HU-020 | Gestionar usuarios | **Implementada en código (habilitación el 22 de octubre); pendiente de ejecutar migraciones y validación manual.** Usuarios reales con tarjetas/detalle, búsqueda, filtros y orden. Activación/desactivación con confirmación, integrada con crear/editar. Solo pasa a Listo tras revisión y pruebas. |
| HU-021 | Crear usuario | **Implementada en código el 22 de octubre; pendiente de ejecutar migración, desplegar la función `crear-usuario` y validar manualmente.** Ver `docs/supabase/GUIA_HU020_HU021_HU022_GESTION_USUARIOS.md`. |
| HU-022 | Editar usuario | **Implementada en código el 22 de octubre; pendiente de ejecutar migración y validar manualmente.** |

Actualización de planificación: el equipo decidió empezar los próximos cinco sprints por Administración. Ver el plan de trabajo al final del documento.

### HU-012: alcance y reglas confirmadas

Actualización local del 26/10: Gestión de áreas incluye selección y vista previa de tema (Rojo, Azul, Celeste, Lavanda, Rosa y Gris azulado), persistido en `areas.tema_color`. Cada opción utiliza principal y pastel. Kits aplica el tema del área de trabajo; los mensajes mantienen colores semánticos independientes mediante un componente común en Administración/Kits. SQL adicional: `migracion_temas_areas_2026_10_26.sql`, después de Kits por área; también incorporado al setup. Pendiente de instalación remota y validación manual. Ver `docs/supabase/GUIA_TEMAS_AREAS_2026_10_26.md`.

- Nombre: **Gestionar financiamientos, seguros y áreas**. Se conserva la numeración HU-012; la gestión de áreas no se crea como una HU adicional.
- Solo Administrador gestiona estos catálogos. Permite listar, crear, editar, activar/desactivar y eliminar tanto áreas como tipos de financiamiento/seguro.
- La eliminación física solo se permite si el registro no tiene referencias: fichas, pedidos, stock, movimientos, kits, asignaciones de usuarios u otras asociaciones. Si existe alguna, bloquear la eliminación y ofrecer desactivación, conservando el historial. Regla confirmada por Walter Salas.
- La comprobación de referencias y la eliminación deben ser seguras también en la base de datos, sin borrado en cascada de registros operativos ni de auditoría.
- Regla confirmada: desactivar impide nuevas selecciones/asignaciones y conserva registros, stock y asignaciones existentes. Los pedidos anteriores pueden finalizarse; no se cancelan ni se elimina stock al desactivar. Las validaciones de nuevas asignaciones/pedidos se incluyen en la migración HU-012.
- Las áreas se utilizan en la asignación de usuarios HU-021/HU-022 y en las fichas HU-003. Mantener contratos estables para desarrollarlas en paralelo y preservar los vínculos al editar nombres o códigos.
- Reparto corregido y confirmado: **Walter Salas desarrolla HU-012 completa**, incluyendo estructura, interfaces y funcionalidad para listar, crear, editar, activar/desactivar y eliminar financiamientos, seguros y áreas con las restricciones acordadas. David revisa e integra con él las áreas necesarias para la gestión de usuarios.
- Mantener el trabajo dentro de las 10 horas semanales de Walter y las 7,5 horas de David. Si no cabe, renegociar tareas o alcance del sprint; no afirmar un cierre completo sin evidencia.

### HU-020, HU-021 y HU-022: columnas y nuevo reparto

Actualización del 15 de octubre: la tarjeta **Gestión de usuarios** y la ruta `/admin/usuarios` ya muestran perfiles reales, con resumen táctil, buscador, filtros, ordenación, actualización al deslizar y detalle completo. La entrega prepara `nombre_usuario`, `nombres` y `apellidos` mediante `migracion_hu020_estructura_usuarios_2026_10_15.sql`, incluida también en el setup. Se conserva el nombre completo anterior sin inferir apellidos. Contraseñas pertenecen a Supabase Auth y no se muestran ni se guardan en profiles. La migración no se ejecutó. Ver `docs/supabase/GUIA_HU020_LISTADO_USUARIOS.md`; la habilitación y HU-021/HU-022 permanecen a cargo de David.

- David Anampa desarrolla **HU-021 (crear usuario)** y **HU-022 (editar usuario)**.
- Walter Salas desarrolla **HU-012 completa** y ajusta la **estructura de HU-020 (tabla de gestión de usuarios y sus campos)**, acordando con David las columnas y datos requeridos. Este ajuste no implica completar por sí solo HU-020.
- David Anampa desarrolla la **funcionalidad restante de HU-020 (activación/desactivación e integración con crear/editar)**, además de HU-021 y HU-022. Walter ya preparó estructura y listado a petición del usuario. HU-020 mantiene una única tarjeta con subtareas para ambos; solo pasa a Listo cuando estén integradas y validadas.

Columnas previstas para la tabla de gestión de usuarios:

| Columna | Información / acción |
|---|---|
| Nombre completo | Identificación del integrante registrado. |
| Cargo | Cargo laboral; es independiente del rol de permisos del sistema. |
| Correo de acceso | Correo utilizado para autenticarse. |
| Rol | Administrador, Jefatura de Farmacia, Farmacia, Almacén o Enfermería/Técnico. |
| Áreas asignadas | Una o varias áreas provenientes del catálogo HU-012. |
| Estado | Activo o inactivo. |
| Acciones | Editar y activar/desactivar con confirmación; crear se ofrece como botón de la pantalla. |

El correo vinculado a Google Drive se muestra en el detalle/formulario, distinguiéndolo del correo de acceso si son diferentes. No mostrar contraseñas, tokens ni claves. No se agrega eliminación de usuarios: se conserva su historial mediante desactivación.

En móvil, presentar los mismos datos en tarjetas: nombre, cargo y estado visibles; rol y áreas debajo; correo y acciones accesibles en el detalle. Evitar una tabla horizontal de siete columnas en la pantalla pequeña. HU-020 puede utilizar tabla en una vista amplia y tarjetas en teléfono.

Verificar al implementar los campos de perfil necesarios para cargo y correo de Drive, porque documentarlos no significa que ya existan en el esquema actual. Todo cambio SQL irá acompañado de migración y actualización del setup.

La estructura implementada para HU-012 reutiliza áreas: UUID estable, código visible `codigo_interno` (AREA-001, editable y único), nombre, descripción, habilitación y configuración de stock propio. `areas.codigo` conserva el alias operativo usado por los pedidos actuales. Seguros/convenios tienen nombre, descripción, tipo SEGURO/CONVENIO, porcentaje y relación con los medicamentos incluidos. Particular no es un tercer tipo del catálogo: se utiliza en la ficha sin financiamiento asociado. Las acciones no son columnas de datos almacenadas.

### Entrega HU-012 — 15 de octubre de 2026

- Nueva ruta administrativa `/admin/catalogos`, enlazada desde el menú, con protección por rol existente. Dos pestañas y formularios móviles rojo/pastel/gris/blanco, hover, búsqueda, filtros y selección de cobertura con vista previa sobre Kairos.
- Script aparte: `docs/supabase/migracion_hu012_catalogos_2026_10_15.sql`, incorporado también al final del `setup`. Pendiente de ejecución por el usuario; no se modificó la base remota.
- Escritura de catálogo mediante RPC atómica con validación de Administrador, restricciones de eliminación y auditoría. La cobertura se guarda junto al porcentaje. Los importes históricos no se recalculan.
- Estructura para David: `profiles.cargo`, `profiles.correo_drive` y relaciones UUID `profile_areas`, sincronizadas con el array de áreas existente. HU-020/HU-021/HU-022 no tienen interfaces ni alta de usuarios implementadas en esta entrega.
- Preparados el tipo de atención Particular/Seguro/Convenio, la relación a financiamiento y campos de valoración histórica de ítems para próximas fichas. HU-003/HU-010 deberán integrar y guardar la cotización; no se implementa el flujo de fichas ni cobranza dentro de HU-012.
- La guía `docs/supabase/GUIA_HU012_Y_CONTRATO_HU020.md` explica los campos, contratos y pasos de validación manual. No se ejecutaron pruebas, análisis Flutter ni capturas en esta entrega. El `No issues found` de días anteriores no valida estos cambios nuevos.

## 8. Documentos y supervisión

| HU | Historia | Estado |
|---|---|---|
| HU-026 | Exportar ficha a PDF | **Pendiente** |
| HU-027 | Subir PDF a Google Drive | **Pendiente** |
| HU-028 | Dashboard de stock y movimientos para Jefatura | **Pendiente; hay un prototipo con valores fijos** |

## Problemas que deben corregirse antes de considerar terminado lo desarrollado

- **IA simulada:** `medicamento_ia_service.dart` utiliza un catálogo fijo y genera datos aleatorios para códigos desconocidos. No realiza una llamada a Gemini ni procesa la fotografía.
- **Desfase del setup corregido:** Supabase ya utiliza `presentacion` y `laboratorio`. Se actualizaron la definición y las semillas del `setup`, el laboratorio por lote y `fecha_recepcion` de pedidos. El detalle de pedidos también lee ahora `presentacion`. No se modificó la base remota ni se ejecutó el script de reconstrucción.
- **Datos de demostración ante errores:** las consultas de catálogo e inventario devuelven datos ficticios cuando falla Supabase, ocultando el problema real.
- **Seguridad — actualización HU-002:** la consulta remota confirmó las funciones y 34 políticas de HU-002 instaladas. Se protegió el perfil y se retiró UPDATE/DELETE de auditoría para los roles de la aplicación. Falta la validación funcional manual por rol. El setup utiliza el alta segura de perfiles desde el comienzo.
- **Operaciones separadas:** la creación de pedidos, las entradas de lotes y la transferencia directa todavía pueden quedar incompletas si falla una llamada intermedia.

Por lo tanto, **HU-001, HU-029 y HU-030 son las más avanzadas**, pero primero conviene corregir esos puntos y validar su funcionamiento. Después podemos completar catálogo/inventario y continuar con las fichas de Áreas → Farmacia.

## Acuerdos de catálogo, edición y Kardex — 13 de octubre de 2026

Estos acuerdos definen trabajo pendiente; no significan que las pantallas, cambios SQL o reportes descritos ya estén implementados.

### HU-013 y HU-016: responsabilidades y correcciones

- Almacén/Logística registra y edita medicamentos e insumos, gestiona lotes, ingresos, abastecimiento y precios de compra y venta. Administrador conserva el acceso acordado a todos los módulos.
- Farmacia consulta el catálogo, solicita abastecimiento y confirma recepción. Enfermería consulta disponibilidad y, en próximos sprints, solicita productos o kits. Jefatura consulta y supervisa.
- El catálogo debe listar productos aunque no tengan lotes o stock, con búsqueda y filtros. No confundir la ficha maestra del producto con sus existencias por lote.
- Comparación realizada mediante lectura del esquema de Supabase: `medicamentos.presentacion`, `medicamentos.laboratorio` y `lotes.laboratorio` ya existen. Se alineó el `setup` y su inserción inicial, y se conservó `pedidos_abastecimiento.fecha_recepcion`, existente en remoto. No hace falta una migración de estos campos para la base actual.
- Toda migración resultante se incorporará también a `docs/supabase/setup_sitra_luz.sql` para reconstruir una base completa. No ejecutar el `setup` sobre una base existente como sustituto de una migración.
- Evitar mostrar datos ficticios como existencias reales cuando falle la consulta a Supabase.

### HU-025: detalle móvil y Kardex por producto

- Al tocar un producto de la lista, abrir una pantalla de detalle con resumen, movimientos y lotes. Mantener la lista principal compacta.
- Resumen: producto, presentación, cantidades separadas por ubicación y valor del inventario al costo.
- Movimientos: tarjetas con fecha, tipo, cantidad, origen/destino y responsable. Al abrir una tarjeta, mostrar justificación, lote, pedido/documento relacionado, costo unitario y total. Evitar tablas de muchas columnas en móvil.
- Lotes: cantidades, vencimientos y costos correspondientes.
- Conservar cantidades y valores históricos por movimiento: editar el precio actual del catálogo no debe recalcular operaciones anteriores.
- Primera etapa: compras/ingresos a Almacén, abastecimiento a Farmacia y devoluciones. Después integrar fichas, kits y entregas a áreas sin perder el recorrido del lote.
- Almacén → Farmacia es un traslado interno: modifica las existencias por ubicación y registra el valor trasladado; no genera por sí mismo consumo del área ni ingreso por venta.
- Las correcciones deben quedar como cancelación antes del despacho o movimiento de devolución/contra-asiento después, con motivo y responsable, preservando el historial.

### Próximos sprints: consumo de kits y visión económica de Jefatura

El usuario indica que los pacientes pagan los kits solicitados por las áreas. Para el seguimiento operativo, la entrega efectiva del kit al área se considerará consumo imputado a esa área y al paciente/ficha correspondiente. La mera solicitud o preparación no debe contabilizar consumo ni descontarlo dos veces.

- Desglosar cada kit en productos, cantidades y lotes para trazar la salida de Farmacia y calcular su costo y valor de venta.
- Definir junto con el flujo de fichas cómo se registra la ubicación destino: si la entrega se contabiliza como consumo, esas mismas unidades no deben quedar además como stock disponible del área. La gestión de botiquines con existencias requerirá distinguir reposición de consumo.
- Registrar devoluciones y cantidades no entregadas para corregir el consumo y sus importes conservando la trazabilidad.
- Mostrar a Jefatura, por área y período, cantidades consumidas, costo de los productos entregados, importe de venta asociado a kits y margen bruto (importe de venta menos costo). Este margen no equivale a utilidad neta porque no incluye otros gastos de la clínica.
- Separar ventas de Farmacia de los cargos por kits de áreas para compararlos sin duplicar importes.
- Distinguir importe por cobrar, importe facturado e importe efectivamente cobrado cuando exista un registro o integración de cobro. El precio de venta o la entrega de un kit no demuestra que el paciente ya pagó.
- El mecanismo de confirmación de cobro, seguros/financiamiento, devoluciones económicas y valoración del costo queda pendiente de definición antes de implementar los reportes. No se ha desarrollado facturación ni cobro en este acuerdo.

El Kardex se vincula a HU-025; su resumen de existencias a HU-023; la visión de Jefatura a HU-028; y los movimientos de kits/áreas a las HU de fichas y kits. HU-013 se considera implementada según el checklist del sprint y HU-016 tiene resuelto el desfase del setup; ambas requieren la validación funcional del usuario. El trabajo de Kardex y reportes sigue pendiente.

## Plan de las próximas cinco semanas — Sprints 4 a 8

Plan acordado el 13 de octubre de 2026 y actualizado el 14 de octubre a un daily por semana, para dos integrantes: **Walter Salas (10 horas semanales)** y **David Anampa (7,5 horas semanales)**. Se conserva el informe anterior como diagnóstico; las tablas siguientes son una proyección de trabajo, no evidencias de tareas ya ejecutadas.

### Organización y capacidad

Se proponen cinco sprints de una semana, numerados del 4 al 8. Cada sprint tiene una meta y **un único registro de daily semanal**, al cierre de la semana, que reúne el trabajo de ambos integrantes y una única tabla del estado del Project. La unidad tendrá cinco sprints y cinco registros; no se divide cada semana en dos dailys. Las fechas son una referencia tomando como semana actual el 12–18 de octubre; ajustarlas si el calendario de la unidad utiliza otros días.

En Scrum, el Daily Scrum es una reunión breve de cada día de trabajo. El registro semanal de este documento es la evidencia académica solicitada; no sustituye la coordinación diaria del equipo. Mantener una planificación al inicio, revisión del incremento y retrospectiva breve al cierre. Referencia: [Guía Scrum oficial — Sprint y Daily Scrum](https://scrumguides.org/scrum-guide.html).

| Integrante | Desarrollo por semana | Revisión, pruebas manuales e integración | Total semanal | Total de cinco semanas |
|---|---:|---:|---:|---:|
| Walter Salas | 8 h | 2 h | 10 h | 50 h |
| David Anampa | 6 h | 1,5 h | 7,5 h | 37,5 h |
| Equipo | 14 h | 3,5 h | 17,5 h | 87,5 h |

Las horas de desarrollo son un presupuesto, no una estimación de que cada HU necesariamente cabe en él. No tenemos una velocidad medida del equipo para garantizar las 24 HU en 70 horas de desarrollo efectivo. El plan cubre todas como objetivo de la unidad, con riesgo de alcance: al cerrar cada semana se compara tiempo real y resultado, y se renegocia lo que no cabe. No superar las horas de cada integrante ni compensar retrasos eliminando las pruebas.

Walter asume principalmente integridad de datos, permisos, IA y stock; David asume principalmente gestión, formularios y documentos. Ambos desarrollan flujos completos cuando sea viable y revisan el trabajo del otro. Las responsabilidades de implementación no equivalen a los permisos de los usuarios de la aplicación.

### Reparto general por sprint

| Semana / sprint | Meta del sprint | Walter Salas — hasta 8 h de desarrollo | David Anampa — hasta 6 h de desarrollo |
|---|---|---|---|
| 1 · Sprint 4 · 12–18 oct. | Administrar usuarios, financiamientos, seguros y áreas desde la aplicación. | HU-012 completa: estructura, interfaces y gestión de financiamientos, seguros y áreas. Ajustar estructura y columnas de la tabla de usuarios HU-020 y acordar su contrato con David. Revisar permisos e integración. | Funcionalidad restante de HU-020: listado y activación/desactivación de usuarios. HU-021 y HU-022: crear y editar usuarios con roles y áreas. Integrar la estructura de HU-020 entregada por Walter. |
| 2 · Sprint 5 · 19–25 oct. | Contar con stock coherente y plantillas de kits administrables. | HU-023 y HU-024: stock consolidado y entradas atómicas. Ajuste pendiente de HU-029: creación atómica de cabecera, ítems y auditoría, reutilizando las reglas existentes. | HU-017, HU-018 y HU-019: listado, creación y edición de kits. |
| 3 · Sprint 6 · 26 oct.–1 nov. | Registrar fichas con productos/kits y completar registro asistido por IA. | HU-014 y HU-015 sincronizadas: extracción real, revisión humana y guardado. Preparar con David el contrato de persistencia de HU-003/HU-004/HU-005. | HU-003, HU-004 y HU-005: creación de ficha General/Neonatología, selección con stock y aplicación de kit. |
| 4 · Sprint 7 · 2–8 nov. | Completar el recorrido de la ficha hasta la entrega física y anulación permitida. | HU-008, HU-009, HU-010 y HU-011: estados, despacho por ítem, confirmación con descuento atómico y anulación auditada. | HU-006 y HU-007: lista con filtros, detalle e historial. Preparar navegación y contrato del Kardex HU-025 cuando estas dos HU estén aceptadas. |
| 5 · Sprint 8 · 9–15 nov. | Consultar trazabilidad real y entregar documentos y supervisión. | HU-025: completar Kardex con movimientos reales. HU-028: dashboard de Jefatura con stock, fichas, movimientos y consumo/valor por área. | HU-026: PDF fiel al formato de ficha. HU-027: subida del PDF a Google Drive con autenticación y control de errores. |

Las HU-001, HU-002, HU-013 y HU-016 ya tienen implementación; HU-029 y HU-030 tienen flujo principal. Su validación y ajustes se mantienen en sus tarjetas originales: no crear nuevas HU para el mismo trabajo. El Kardex no vuelve a abrir HU-013. HU-029 recibe su ajuste transaccional en Sprint 5 y HU-030 se valida junto al stock de ese sprint.

### Dependencias y condiciones de aceptación

- **Sprint 4:** el alta de usuarios utiliza un servicio autorizado para Supabase Auth; ninguna clave administrativa se incluye en Flutter. Crear/editar perfil debe respetar HU-002, asignación de áreas y auditoría. Definir credenciales de Gemini, permisos de Drive y disponer del formato físico del PDF esta semana, para detectar impedimentos con anticipación.
- **Sprint 5:** HU-018 depende del catálogo existente; HU-019 no modifica los kits ya copiados a fichas históricas. HU-024 conserva la regla acordada: Almacén/Logística registra ingresos; el traslado a Farmacia se distingue de una compra para no duplicar existencias ni valor. Precisar qué entradas directas a Farmacia están permitidas antes de implementarlas. HU-029 debe guardar toda la solicitud o no guardar nada.
- **Sprint 6:** HU-014 entrega el resultado a HU-015; se revisan juntas aunque tengan tarjetas separadas. El escaneo sigue funcionando offline, pero extracción y guardado requieren conectividad. No generar datos aleatorios ante fallos de IA. HU-003 integra financiamiento, área, paciente, doctor y receptor según requerimientos; HU-005 copia la composición del kit del momento, sin depender de futuras ediciones. La consulta de stock no reserva por sí misma unidades.
- **Sprint 7:** HU-006/HU-007 exponen las fichas creadas en Sprint 6. HU-009 define las cantidades reales que HU-010 confirma. Descontar una sola vez al confirmar el recojo; validar stock nuevamente y conservar lote, responsable, área y movimiento. HU-011 aplica permisos y motivo: después de una entrega no debe borrar ni recuperar stock silenciosamente; requiere el contra-asiento definido para ese caso. La regla exacta de anulación después de preparación debe precisarse antes del desarrollo.
- **Sprint 8:** HU-025 consulta movimientos producidos por los sprints anteriores; HU-028 utiliza datos reales. El PDF HU-026 precede a la subida HU-027. Un correo configurado no concede permisos de Drive: deben existir autorización, destino y manejo de reintentos sin duplicar documentos.
- **En todas las HU:** conservar diseño móvil rojo/blanco/gris, iconos Material, campos legibles, permisos por rol y auditoría. Cada migración se acompaña de actualización del `setup`. Las pruebas funcionales las realizan los integrantes; esta planificación no ejecuta pruebas ni modifica la aplicación.

### Alcance de consumo y dinero en esta unidad

En HU-010 la entrega de un kit se registra como consumo imputado al área y ficha/paciente, según el acuerdo del usuario. La solicitud no es consumo. En HU-025/HU-028 se muestran costo y valor de venta de los productos efectivamente entregados, con valores históricos y margen bruto por área. Almacén → Farmacia sigue siendo un traslado interno.

No se presupone un módulo de caja/facturación/cobranza ya desarrollado. Los importes de venta se identifican como valor de venta o cargo asociado, no como dinero cobrado sin evidencia de pago. Confirmar con Jefatura qué información necesita presentar en esta unidad. Integrar facturación externa o utilidad neta sería trabajo adicional a estimar, no horas ocultas dentro de HU-028.

### Reglas del Project de GitHub y Definition of Done

| Columna | Uso | WIP del equipo |
|---|---|---:|
| Product Backlog | HU de próximas semanas o trabajo no comprometido en el sprint activo. | Sin límite |
| Sprint Backlog | HU comprometidas en la semana que aún no comenzaron. | Sin límite de WIP; alcance limitado por capacidad |
| En progreso | Implementación activa; una tarjeta por integrante. | 2 |
| En revisión | Código terminado esperando revisión del otro integrante. | 3 |
| En pruebas | Revisión superada, pendiente de pruebas funcionales manuales. | 2 |
| Listo | HU aceptada, integrada y documentada. | Sin límite |

El WIP cuenta tarjetas, no personas ni grupos: HU-014 y HU-015 son dos tarjetas. Si se desarrollan juntas, deben coordinarse para respetar las dos tarjetas activas del equipo. Si las columnas de revisión o pruebas se llenan, terminar esas tarjetas antes de empezar otra. Etiquetar bloqueos dentro de la tarjeta y registrarlos en el daily, conservando su columna.

Una HU pasa a **Listo** cuando cumple sus criterios, fue revisada por el compañero, tiene pruebas manuales satisfactorias, está integrada en la rama de trabajo acordada y tiene migración/setup y documentación actualizados cuando corresponda. El análisis estático no reemplaza las pruebas de stock, roles o conexión. No se publica ni se mueve nada en GitHub mediante este documento.

En las tablas siguientes, **Base aceptada** significa las HU previas (001, 002, 013, 016, 029 y 030) únicamente cuando realmente superen su validación; mientras tanto se mantienen en revisión o pruebas respetando WIP. **Listo acumulado** son los resultados de los cierres anteriores, también sujetos a aceptación real.

Los estados y textos de los cinco registros semanales son **objetivos proyectados**. Al celebrar la reunión se sustituyen por lo realizado y los impedimentos reales. “Por confirmar” no significa “No hay bloqueos”. Si no se cumple la proyección, el tablero conserva la situación real.

### Semana 1 · Sprint 4 · Administración

Meta: crear, editar y gestionar usuarios con permisos correctos, y administrar financiamientos, seguros y áreas.

#### Daily semanal — registro proyectado al cierre del sprint

**4. Registro del daily**

| Integrante | ¿Qué realizó? — objetivo previsto de la semana | ¿Algo lo bloquea? |
|---|---|---|
| Walter Salas | Completar HU-012: estructura, interfaces y gestión de financiamientos, seguros y áreas; bloquear eliminación con asociaciones. Ajustar la estructura y columnas de HU-020, acordar su contrato con David y actualizar migración/setup cuando corresponda. | Por confirmar: referencias, reglas de desactivación e integración con usuarios; respetar las 10 horas semanales. |
| David Anampa | Completar la funcionalidad restante de HU-020 y HU-021/HU-022: listado, activación/desactivación, alta segura y edición de usuarios, roles y áreas asignadas. Integrar la estructura de HU-020 de Walter y revisar HU-012. | Por confirmar: contrato de HU-020 y validación de Supabase Auth/roles; respetar las 7,5 horas semanales. Si no cabe, registrar arrastre y replanificar. |

**5. Estado del tablero al cerrar la sesión — proyección**

| Columna | Historias / ítems | Límite de trabajo en curso | ¿Se respeta? |
|---|---|---|---|
| Product Backlog | HU-003 a HU-011, HU-014/HU-015, HU-017 a HU-019 y HU-023 a HU-028; ajuste HU-029. | — | — |
| Sprint Backlog | —. | — | — |
| En progreso | —. | 2 | Sí, si se alcanza el cierre previsto. |
| En revisión | —. | 3 | Sí, si se alcanza el cierre previsto. |
| En pruebas | —. | 2 | Sí, si se alcanza el cierre previsto. |
| Listo | HU-012, HU-020, HU-021 y HU-022; más Base aceptada. | — | Solo con aceptación real. |

### Semana 2 · Sprint 5 · Kits e inventario

Meta: configurar kits y registrar existencias sin operaciones parciales. El ajuste de HU-029 se aborda después de cerrar el núcleo de HU-024; si no cabe, se explicita el arrastre y se replanifica.

#### Daily semanal — registro proyectado al cierre del sprint

**4. Registro del daily**

| Integrante | ¿Qué realizó? — objetivo previsto de la semana | ¿Algo lo bloquea? |
|---|---|---|
| Walter Salas | Completar HU-023 con stock separado de Farmacia/Almacén, HU-024 con guardado atómico de lote, stock y auditoría, y el ajuste transaccional de HU-029; validar con David HU-030, recepción y devolución, sin duplicar movimientos. | Por confirmar: casos de fallo parcial, doble confirmación y existencias concurrentes. |
| David Anampa | Completar HU-017/HU-018/HU-019: listado, habilitación, creación y edición de kits reutilizando el formulario y conservando sus usos históricos; revisar con Walter inventario, entradas y abastecimiento. | Por confirmar: integración de kits y preservación de sus futuros usos históricos. |

**5. Estado del tablero al cerrar la sesión — proyección**

| Columna | Historias / ítems | Límite de trabajo en curso | ¿Se respeta? |
|---|---|---|---|
| Product Backlog | HU-003 a HU-011, HU-014/HU-015 y HU-025 a HU-028. | — | — |
| Sprint Backlog | —. | — | — |
| En progreso | —. | 2 | Sí, si se alcanza el cierre previsto. |
| En revisión | —. | 3 | Sí, si se alcanza el cierre previsto. |
| En pruebas | —. | 2 | Sí, si se alcanza el cierre previsto. |
| Listo | HU-017, HU-018, HU-019, HU-023 y HU-024; HU-029/HU-030 aceptadas después de sus ajustes/validación; más Listo acumulado. | — | Solo con aceptación real. |

### Semana 3 · Sprint 6 · IA y creación de fichas

Meta: capturar productos con asistencia real de IA y crear fichas a partir del catálogo y kits existentes. Es el sprint de mayor riesgo de integración; HU-003 y el guardado de HU-015 comparten la necesidad de contratos estables, no deben competir por cambios incompatibles de esquema.

#### Daily semanal — registro proyectado al cierre del sprint

**4. Registro del daily**

| Integrante | ¿Qué realizó? — objetivo previsto de la semana | ¿Algo lo bloquea? |
|---|---|---|
| Walter Salas | Completar HU-014/HU-015 sincronizadas: GTIN/foto, extracción real y estructurada, revisión editable, validaciones y guardado; acordar el contrato de persistencia de fichas y revisar el trabajo de David. | Por confirmar: extracción con fotografías reales y comportamiento sin red. |
| David Anampa | Completar HU-003/HU-004/HU-005: ficha con paciente, área, doctor, financiamiento y receptor, selección de productos con stock y aplicación del kit como copia de sus ítems; revisar el formulario de IA. | Por confirmar: registro completo, cantidades válidas y conservación del contenido del kit. |

**5. Estado del tablero al cerrar la sesión — proyección**

| Columna | Historias / ítems | Límite de trabajo en curso | ¿Se respeta? |
|---|---|---|---|
| Product Backlog | HU-006 a HU-011 y HU-025 a HU-028. | — | — |
| Sprint Backlog | —. | — | — |
| En progreso | —. | 2 | Sí, si se alcanza el cierre previsto. |
| En revisión | —. | 3 | Sí, si se alcanza el cierre previsto. |
| En pruebas | —. | 2 | Sí, si se alcanza el cierre previsto. |
| Listo | HU-003, HU-004, HU-005, HU-014 y HU-015; más Listo acumulado. | — | Solo con aceptación real. |

### Semana 4 · Sprint 7 · Atención y entrega de fichas

Meta: operar fichas de principio a fin con cantidades reales, permisos y trazabilidad. Es el sprint de mayor riesgo de stock: las cuatro HU de Walter se desarrollan secuencialmente aprovechando la misma máquina de estados y operación transaccional.

#### Daily semanal — registro proyectado al cierre del sprint

**4. Registro del daily**

| Integrante | ¿Qué realizó? — objetivo previsto de la semana | ¿Algo lo bloquea? |
|---|---|---|
| Walter Salas | Completar HU-008/HU-009/HU-010/HU-011: estados de preparación, despacho parcial por ítem con observaciones, entrega confirmada, descuento único por lote y anulación con motivo, sin borrar movimientos. | Por confirmar: stock insuficiente, doble pulsación, permisos y cancelación según estado. |
| David Anampa | Completar HU-006/HU-007: listado con filtros, detalle completo e historial; validar con Walter el recorrido de fichas y refinar el detalle/Kardex HU-025 para Sprint 8. | Por confirmar: legibilidad móvil, historial completo y validación de Jefatura. |

**5. Estado del tablero al cerrar la sesión — proyección**

| Columna | Historias / ítems | Límite de trabajo en curso | ¿Se respeta? |
|---|---|---|---|
| Product Backlog | HU-025, HU-026, HU-027 y HU-028. HU-025 permanece aquí si solo se refinó su contrato. | — | — |
| Sprint Backlog | —. | — | — |
| En progreso | —. Si comenzó código de HU-025, colocar esa única tarjeta aquí y registrarla como trabajo arrastrado. | 2 | Sí, con 0 o 1 tarjeta. |
| En revisión | —. | 3 | Sí, si se alcanza el cierre previsto. |
| En pruebas | —. | 2 | Sí, si se alcanza el cierre previsto. |
| Listo | HU-006, HU-007, HU-008, HU-009, HU-010 y HU-011; más Listo acumulado. | — | Solo con aceptación real. |

### Semana 5 · Sprint 8 · Kardex, documentos y supervisión

Meta: consultar el recorrido real de los productos, exportar la ficha y supervisar stock/consumo. Evitar que Google Drive descubra una dependencia de credenciales al final: el acceso debe haberse confirmado en Sprint 4.

#### Daily semanal — registro proyectado al cierre del sprint

**4. Registro del daily**

| Integrante | ¿Qué realizó? — objetivo previsto de la semana | ¿Algo lo bloquea? |
|---|---|---|
| Walter Salas | Completar HU-025/HU-028: detalle móvil/Kardex con resumen, lotes y movimientos reales de compra, traslado, devolución y consumo por ficha; dashboard con stock crítico, fichas por estado y consumo/valor por área; consolidar migraciones y documentación. | Por confirmar: conciliación de cantidades e importes con operaciones reales. |
| David Anampa | Completar HU-026/HU-027: PDF fiel al formato oficial, datos de ficha y tablas separadas de medicamentos/dispositivos; subida al destino autorizado de Drive con resultado visible, reintentos y prevención de duplicados; revisar el flujo completo con Walter. | Por confirmar: aceptación del PDF, autorización externa y carga correcta del documento. |

**5. Estado del tablero al cerrar la sesión — objetivo final, no estado actual**

| Columna | Historias / ítems | Límite de trabajo en curso | ¿Se respeta? |
|---|---|---|---|
| Product Backlog | Mejoras explícitamente fuera de alcance; ninguna HU de la unidad omitida sin acuerdo. | — | — |
| Sprint Backlog | — si todo el alcance fue aceptado. | — | — |
| En progreso | — si todo el alcance fue aceptado. | 2 | Sí, condicionado al resultado real. |
| En revisión | — si todo el alcance fue aceptado. | 3 | Sí, condicionado al resultado real. |
| En pruebas | — si todo el alcance fue aceptado. | 2 | Sí, condicionado al resultado real. |
| Listo | HU-025, HU-026, HU-027 y HU-028; más Listo acumulado. Objetivo: HU-001 a HU-030 aceptadas. | — | Solo con evidencia real de aceptación. |

### Manejo de retrasos y cierre honesto de la unidad

1. Al inicio de cada sprint, tomar solo lo que cabe después de considerar pendientes arrastrados. El estado futuro del tablero no es una obligación de mover tarjetas sin terminar.
2. Si una HU permanece bloqueada o supera el presupuesto, ayudar a resolverla antes de abrir más trabajo. Revisar con el docente/Product Owner alcance o capacidad; no asumir horas extras de David o Walter.
3. Priorizar seguridad y el flujo stock → ficha → entrega → trazabilidad. Si es necesario renegociar, HU-027 (Drive, prioridad baja) es la primera candidata a diferirse con acuerdo explícito; luego mejoras económicas adicionales que no formen parte de los criterios comprometidos. Mantenerlas visibles como pendientes.
4. No dar HU-014/HU-015 por completas usando IA simulada, ni HU-025/HU-028 con movimientos o métricas ficticias. No esconder falta de conectividad detrás de datos de demostración.
5. En el último cierre, registrar qué HU quedaron realmente Listo, cuáles siguen en revisión/pruebas y qué ajustes fueron acordados. El objetivo de terminar las 30 HU no equivale a afirmar que ya están terminadas.

Este plan distribuye las **24 HU pendientes o parciales**: 4 en Sprint 4; 5 en Sprint 5; 5 en Sprint 6; 6 en Sprint 7; y 4 en Sprint 8. Añade el ajuste de HU-029 y la validación de las seis HU previamente desarrolladas sin duplicar su numeración. La distribución deberá recalibrarse con las horas y resultados reales del primer sprint.
