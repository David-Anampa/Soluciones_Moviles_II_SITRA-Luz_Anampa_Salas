# Plan de revisión y cierre — Sprints 6, 7 y 8

Fecha: **22/11/2026**. Estado: **plan preparado; correcciones y pruebas pendientes**.

**Avance HU-003 del 22/11:** los tres defectos de receptor, médico manual y
guardado/refresco están corregidos en código y la migración incremental está
aplicada/verificada en Supabase. También se reutiliza el validador del receptor al
entregar. Ver [guía de corrección y pruebas](../supabase/GUIA_HU003_RECEPTOR_MEDICO_2026_11_22.md).
Pruebas dirigidas y análisis estático aprobados; comprobación manual con el usuario
todavía pendiente. Las descripciones originales siguientes son el diagnóstico
base: no interpretar estos tres defectos como aún presentes en la versión corregida.

## 1. Alcance y forma de interpretar este documento

Revisión estática del código y SQL de `Sprint-08`, commit base `40d65bb`.
Incluye las funcionalidades de Sprint 6 y 7 y el primer avance de HU-025.
Las referencias remotas consultadas coinciden con los commits conocidos:
Sprint-06 `809e652`, Sprint-07 `bb44dd7`, Sprint-08 `40d65bb`.
Se revisan **15 historias**, no todas las historias de los sprints anteriores.

Fuentes de requisitos, en orden de prioridad:

1. Decisiones directas del usuario; reconocimiento y llenado por IA ya probados
   satisfactoriamente por él. No volver a describir esa función como simulada.
2. [Acuerdos de kits por área](ACUERDOS_KITS_POR_AREA_2026-10-26.md), especialmente
   solicitud, confirmación de faltantes, recepción final, cancelación y rechazo.
3. [Estado de historias y condiciones de aceptación](ESTADO_HISTORIAS_USUARIO_2026-10-13.md).
4. [Avance de HU-025](DAILY09_AVANCE_HU025_2026-11-19.md).

**Confirmado en código** significa que se leyó la implementación concreta. No
significa que esa versión de SQL esté instalada ni que la operación se haya
ejecutado en Supabase. **Por probar** no equivale a un defecto demostrado.
No se ejecutaron pruebas funcionales, llamadas a Gemini, migraciones ni movimientos
de stock durante esta revisión. No se consultaron ni reprodujeron valores de claves.
El último `flutter analyze` documentado corresponde al 19/11, sin observaciones;
deberá repetirse después de modificar código. No sustituye estas comprobaciones.

Las columnas Done del Project reflejan cierres administrativos por los dailys.
No acreditan por sí mismas la aceptación técnica de los requisitos siguientes.
Este plan no reabre issues ni modifica sus responsables automáticamente.

## 2. Resumen por historia

| Sprint | HU | Estado frente al alcance acordado | Principal pendiente |
|---|---|---|---|
| 6 | 003 | Parcial | Validar receptor en servidor y alinear médico con catálogo |
| 6 | 004 | Parcial | Excepción de kits verificable y consultas de catálogo completas |
| 6 | 005 | Parcial | Modal final y fotografía histórica de faltantes al enviar |
| 6 | 014 | Núcleo implementado; usuario confirma reconocimiento | Seguridad transversal de IA y errores/sin red |
| 6 | 015 | Núcleo implementado; cierre pendiente | Gestión segura de clave y guardado revisado sin duplicación |
| 7 | 006 | Parcial | Paginación, contadores y permisos de lectura coherentes |
| 7 | 007 | Implementada con deficiencias de consulta | Evitar detalle incompleto cuando falta la RPC |
| 7 | 008 | Parcial | Estado real/auditoría, notificación y dos confirmaciones distintas |
| 7 | 009 | Implementada con corrección compartida pendiente | Cantidades reales y coherencia de auditoría de preparación |
| 7 | 010 | Parcial | Receptor válido y cierre conforme a recepción del área |
| 7 | 011 | No conforme con el último acuerdo | Separar rechazo/cancelación e impedir anular consumo confirmado |
| 8 | 025 | Primer avance implementado | Lotes, valores históricos, paginación y conciliación |
| 8 | 026 | Pendiente de desarrollo | Exportación real y aceptación del formato oficial |
| 8 | 027 | Pendiente de desarrollo | Autorización/destino Drive, subida, reintentos y duplicados |
| 8 | 028 | Prototipo; no dashboard real | Sustituir cifras fijas por indicadores verificados |

## 3. Reglas ya acordadas: no volver a inventarlas

- Cada área tiene sus plantillas de kits. El CRUD de plantillas no equivale al
  pedido: el pedido se materializa en una ficha enviada a Farmacia.
- Copiar un kit no modifica su plantilla ni las cantidades de fichas anteriores.
- Se permite pedir/entregar incompleto, informando qué falta. Almacén y tránsito
  no son stock disponible de Farmacia.
- Antes del envío se confirma completo/incompleto y se conserva esa decisión
  con cantidades, fecha/hora y responsable en historial/auditoría.
- Farmacia recibe la solicitud y prepara. El área confirma recepción física.
  Son actos diferentes y deben distinguirse en datos, permisos e historial.
- Solo lo efectivamente entregado y recibido se considera consumo operativo.
  No contabilizar cobro ni uso clínico efectivo por el simple hecho de entregar.
- Después de la recepción final el pedido queda consultable y sin modificaciones.
  No devolver stock por una anulación administrativa de un consumo confirmado.
- Cancelación del solicitante y rechazo de Farmacia requieren justificación y
  eventos diferenciados.
- Jefatura consulta y supervisa; Almacén no debe obtener acceso clínico global
  por una diferencia entre pantalla y SQL.
- La consulta de stock no reserva unidades por sí sola. No imponer una reserva
  nueva como condición de cierre sin acordar su mecanismo y consecuencias.

## 4. Sprint 6 — revisión por historia

### HU-003 — Registrar ficha General o Neonatología

**Existe:** formulario de ambos formatos, área/turno/prioridad, financiamiento,
médico, receptor, cabecera e ítems mediante una RPC transaccional; edición de
SOLICITADO y auditoría. [Formulario](../../app/lib/features/fichas/presentation/views/registro_ficha_view.dart#L362).

**Confirmado / por corregir:**

- [x] Añadida validación central de receptor activo, rol ENFERMERIA y pertenencia
  real al área, reutilizada al entregar. Corregido el respaldo del formulario que
  ofrecía personal de otras áreas. Migración aplicada y verificada en Supabase.
  [Corrección](../supabase/migracion_hu003_receptor_medico_2026_11_22.sql).
- [x] Médico obligatorio del catálogo activo en formulario y SQL; retirada la
  entrada manual. No se modifican fichas históricas, pero su edición requiere
  seleccionar un médico válido si antes tenían un nombre libre.
- [x] Separado el fallo de guardado del fallo posterior de refresco de lista/stock.
  Un guardado confirmado conserva su número y muestra advertencia de actualización,
  sin reenvío. Se mantiene el identificador de reintento ante un fallo de guardado.

**Por probar juntos:**

- [ ] P003-1: registrar una General y una Neonatología con datos de prueba;
  comprobar valores guardados y visualizados en Farmacia/Jefatura.
- [ ] P003-2: receptor de otra área, rol no permitido o desactivado: rechazo
  también en servidor, sin cabecera/ítems/auditoría parciales.
- [ ] P003-3: editar SOLICITADO; después de preparación debe bloquearse. Reintentar
  un guardado con el mismo identificador: una sola ficha.

**Decisión pendiente:** excepción de médico manual, solo si el usuario la necesita.

### HU-004 — Seleccionar medicamentos e insumos con stock

**Existe:** selector, cantidades positivas, productos activos, separación de
categorías y bloqueo de selección individual sin stock.

**Confirmado / por corregir:**

- [ ] La excepción de faltantes confía en `origen_kit` y `confirmar_faltante_kit`
  enviados por el cliente, sin acreditar que el ítem procede de la plantilla.
  Validar procedencia en servidor, considerando que la copia puede editarse sin
  cambiar el kit original. [SQL](../supabase/migracion_hu003_hu004_hu005_fichas_2026_11_06.sql#L726).
- [ ] El formulario carga hasta 300 productos y el selector filtra esa lista
  local; SQL busca stock en las primeras 500 filas de una consulta general.
  Consultar por producto/paginar: un producto fuera de esa ventana puede tratarse
  como sin stock. [Selector](../../app/lib/features/fichas/presentation/widgets/selector_item_ficha_dialog.dart#L53),
  [SQL](../supabase/migracion_hu003_hu004_hu005_fichas_2026_11_06.sql#L774).

**Por probar:**

- [ ] P004-1: producto sin stock, cantidad cero/negativa, mayor que disponible,
  lote vencido/inactivo y existencias solo en Almacén/tránsito: rechazo correcto.
- [ ] P004-2: petición modificada con `origen_kit=true` sin kit válido: no saltar
  la restricción. Comprobación por terminal en carpeta externa al proyecto.
- [ ] P004-3: producto fuera de las primeras páginas y stock cambiado desde otro
  dispositivo: consultar y validar la disponibilidad real, sin falsos ceros.

**Definir al implementar:** cómo acreditar la procedencia del ítem copiado cuando
se conservan productos previos o se cambia la plantilla; no prohibir variantes.

### HU-005 — Aplicar kit a la ficha

**Existe:** copia editable independiente, mezcla de ítems, selector de kits del
área y confirmación al copiar con faltantes.
[Copia](../../app/lib/features/fichas/domain/ficha_borrador.dart#L190).

**Confirmado / por desarrollar:**

- [ ] El diálogo actual confirma la copia, no el estado final antes de enviar.
  `_guardarFicha` no presenta el modal completo/incompleto exigido. Consultar
  disponibilidad actual, mostrar solicitado/disponible/faltante y permitir volver.
- [ ] Guardar fotografía de la confirmación final y sus faltantes calculados
  por servidor, y mostrarla a Farmacia/historial. **Sí se envía y persiste el booleano**
  `confirmar_faltante_kit` dentro de `solicitud_datos`; no afirmar que no se guarda
  nada. Ese booleano no sustituye el desglose histórico de disponibilidad.
  [Payload](../../app/lib/features/fichas/domain/ficha_borrador.dart#L380),
  [guardado](../supabase/migracion_hu003_hu004_hu005_fichas_2026_11_06.sql#L878).
- [ ] La copia omite componentes deshabilitados mediante `if (!kItem.activo)
  continue`. Informar explícitamente cuáles se excluyeron y conservarlos en el
  diagnóstico de faltantes; no registrarlos como disponibles ni omitirlos sin aviso.

**Por probar:**

- [ ] P005-1: aplicar kit, modificar cantidades/agregar/quitar; guardar ficha,
  editar luego la plantilla y comprobar que la ficha conserva su composición.
- [ ] P005-2: kit completo al copiar e incompleto al enviar: modal actualizado,
  decisión expresa y faltantes persistidos; no acreditar stock de Almacén.
- [ ] P005-3: kit de otra área o deshabilitado: no usarlo para nueva ficha;
  comprobar edición histórica según las reglas del servidor.

**No pendiente de redefinición:** el modal y su auditoría ya fueron acordados.

### HU-014 — Reconocimiento GTIN/fotografía

**Existe y usuario confirma funcionamiento:** escaneo local GS1/GTIN, lectura de
fotografías con Gemini y llenado de campos; catálogo y borrador local ante fallos.
[Servicio](../../app/lib/features/almacen/data/services/medicamento_ia_service.dart#L461).

**Por corregir / completar:**

- [ ] Sustituir la llamada directa desde el móvil por una función autenticada
  de servidor que use un secreto. La ruta alternativa invoca `extraer-medicamento-ia`,
  pero **no existe su implementación versionada en `supabase/functions`**. No
  inferir por eso si está o no desplegada remotamente.
- [ ] Comprobar mensajes de clave inválida, cuota agotada, tiempo de espera y
  sin red; no mezclar éxito de catálogo/GS1 con extracción IA exitosa.

**Por probar:**

- [ ] P014-1: reutilizar una captura que ya funcionó; validar GTIN/lote/fecha,
  fotos múltiples, cancelación y corrección manual sin pérdida durante el flujo.
- [ ] P014-2: sin red, foto ilegible, cuota/clave inválida: aviso comprensible,
  sin datos ficticios ni registro automático de datos no revisados.

**Decisión opcional:** persistir borradores tras cerrar la app es alcance adicional
si se solicita; conservarlos durante el flujo ya es requisito.

### HU-015 — Revisar, corregir y guardar extracción

**Existe:** formulario editable, categoría, revisión antes del guardado e ingreso
mediante el flujo atómico de HU-024. La IA no debe registrar directamente sin revisión.
[Guardado](../../app/lib/features/almacen/presentation/views/registro_medicamento_view.dart#L884).

**Confirmado / por corregir, compartido con HU-014:**

- [ ] `guardarApiKey` guarda la clave completa en SharedPreferences y en
  `auditoria_trazabilidad.estado_nuevo`; eliminar ese diseño, no solo ocultar
  el botón. Auditoría debe guardar quién/cuándo/cambió, nunca el secreto.
  [Servicio](../../app/lib/features/almacen/data/services/medicamento_ia_service.dart#L174).
- [ ] El servicio captura el fallo de sincronización y el diálogo puede mostrar
  éxito global de todos modos. Devolver resultado real, bloquear doble guardado y
  mostrar estados claros. [Diálogo](../../app/lib/features/almacen/presentation/widgets/configurar_gemini_dialog.dart#L96).
- [ ] Si se guardó una clave real con este mecanismo, preparar rotación y retirada
  del valor de los eventos afectados mediante una intervención específica que
  preserve los demás datos de auditoría; no borrar la auditoría completa.

**Por probar:**

- [ ] P015-1: corregir lo reconocido, guardar y volver a consultar: cambios
  persistidos; lote duplicado bloqueado y stock registrado solo en Almacén.
- [ ] P015-2: reintento/doble toque y fallo de red: sin producto/lote/stock parcial.
- [ ] P015-3: otro dispositivo de Almacén usa IA sin leer/ingresar la clave;
  rol no autorizado no configura ni ejecuta extracción; error al guardar no es éxito.

**Definir:** administración/rotación del secreto en servidor y límites de uso por
rol/usuario. El reconocimiento funcional no necesita rehacerse.

## 5. Sprint 7 — revisión por historia

### HU-006 — Listar fichas con filtros

**Existe:** listado, filtros de área/estado/tipo/prioridad/turno, búsqueda y contadores.

**Confirmado / por corregir:**

- [ ] Se consultan hasta 120 fichas; los contadores se calculan sobre ese conjunto.
  Añadir paginación y totales independientes o identificar claramente los límites.
  [Vista](../../app/lib/features/fichas/presentation/views/fichas_listado_view.dart#L87).
- [ ] El respaldo usa fichas recientes si falta la RPC: no aparentar que una
  instalación incompleta cumple los filtros. Fallo explícito o modo limitado visible.
  [Repositorio](../../app/lib/features/fichas/data/repositories/fichas_repository.dart#L95).
- [ ] Alinear permisos: SQL incluye ALMACEN entre lectores globales aunque la
  ruta compartida no lo admite; resolver según la matriz de acceso clínico.
  [SQL](../supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql#L278).
- [ ] Revisar normalización de `areaInicial.toUpperCase()` frente a códigos
  canónicos que pueden contener UUID. Es una incompatibilidad potencial a probar,
  no evidencia de que todas las áreas fallen.

**Por probar:**

- [ ] P006-1: ficha creada en área aparece en Farmacia después de actualizar;
  buscar por su número y probar cada filtro/restablecimiento.
- [ ] P006-2: varios roles/áreas y más de 120 registros controlados: permisos,
  páginas y contadores correctos. No generar masivamente registros reales para probar.

**Pendiente transversal:** actualizar a mano permite consultar; no equivale a notificación.

### HU-007 — Detalle completo e historial

**Existe:** cabecera, ítems por categoría, valoración, lotes e historial mediante RPC.

**Confirmado / por corregir:**

- [ ] Si falta la RPC de detalle, el repositorio busca entre 100 fichas recientes;
  no garantiza ni encontrar una ficha antigua ni entregar su historial completo.
  Evitar ese respaldo silencioso. [Repositorio](../../app/lib/features/fichas/data/repositories/fichas_repository.dart#L151).
- [ ] Alinear las etiquetas y datos de confirmación inicial de Farmacia y
  recepción física del área, y exponer la confirmación histórica de faltantes.

**Por probar:**

- [ ] P007-1: misma ficha desde área, Farmacia y Jefatura: encabezado, médico,
  seguro, solicitante, fechas y cantidades coinciden; Jefatura no opera estados.
- [ ] P007-2: recorrer su historial y comparar cada estado/evento con la cabecera,
  incluyendo una ficha antigua; fallo de RPC no aparece como historial vacío normal.

**Dependencias:** corregir auditoría HU-008/009 y definir las acciones HU-010/011.

### HU-008 — Estados de preparación y despacho

**Existe:** SOLICITADO → EN_PREPARACION → LISTO_PARA_RECOJO → ENTREGADO,
RPC con bloqueo por ficha e identificador de operación.

**Confirmado / por corregir:**

- [ ] Guardar preparación desde LISTO_PARA_RECOJO conserva ese estado en cabecera,
  pero auditoría escribe EN_PREPARACION. Unificar usando el estado realmente
  persistido. [SQL estado](../supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql#L881),
  [SQL auditoría](../supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql#L920).
- [ ] Falta notificación operativa acordada: `enablePushNotifications=false` y
  no hay suscripción en tiempo real en el listado. Implementar un canal explícito
  de aviso de solicitud/listo, con navegación a ficha y sin duplicar avisos.
  [Servicio](../../app/lib/core/services/notification_service.dart#L26).
- [ ] La idempotencia compara solo `operacion_atencion_id` de la última operación.
  Probar reintentos antiguos después de otra transición; es un riesgo de cobertura,
  no prueba de doble descuento. Reforzar con registro de operaciones si falla.

**Por probar:**

- [ ] P008-1: preparación/listo y guardar nuevamente; cabecera e historial
  coinciden y los usuarios solo ven las acciones permitidas.
- [ ] P008-2: doble toque, reintento tras corte y dos operadores: una transición
  lógica, sin auditoría duplicada ni retroceso por un reintento antiguo.
- [ ] P008-3: solicitud/listo genera el aviso al destinatario y abre la ficha correcta.

**Definir:** aviso dentro de la app, push con app cerrada o ambos. El acuerdo pide
notificación; no asumir que simplemente refrescar la lista cumple ese requisito.

### HU-009 — Cantidades reales y observaciones

**Existe:** 0 ≤ entregado ≤ solicitado, verificación de stock, motivo de entrega
parcial y datos por ítem; también hay comprobación de motivo en SQL al entregar.

**Por corregir / comprobar:**

- [ ] Aplicar la corrección de auditoría compartida con HU-008.
- [ ] Revisar notas globales frente al acuerdo de observaciones por ítem: el
  código admite una nota global como justificación de varios faltantes.
- [ ] Mantener diferencias solicitado/preparado/entregado sin convertir toda
  cantidad solicitada o sugerida en consumo real.

**Por probar:**

- [ ] P009-1: cantidades 0, negativa, superior a solicitada y superior a stock;
  rechazo consistente entre interfaz y SQL.
- [ ] P009-2: solicitar 5 y entregar 3: exige motivo, conserva solicitado=5,
  entregado=3 y solo esas 3 unidades se consumen después de recepción final.

**Definir:** si la nota global es suficiente o se exige una justificación separada
en cada línea parcial; no eliminar sin más una opción que el sistema ya admite.

### HU-010 — Confirmar recepción y descontar stock

**Existe:** bloqueo transaccional, FEFO sobre lotes activos/vigentes, desglose por
lote, datos económicos y eventos de consumo. Rechaza una segunda entrega y una
ficha que ya tenga detalle de descuento por lote.

**Confirmado / por corregir:**

- [ ] La consulta del receptor al entregar solo exige su ID, sin activo/rol/área.
  Revalidar también después de preparar por si el perfil fue desactivado.
  [SQL](../supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql#L1004).
- [ ] Farmacia/Admin pueden confirmar desde EN_PREPARACION, sin paso LISTO ni
  confirmación del área. Alinear con las dos recepciones acordadas. Una recepción
  delegada necesitaría regla y auditoría explícitas, no una sustitución silenciosa.
  [SQL](../supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql#L946).
- [ ] Al finalizar, dejar solo consulta y no modificar/anular desde otras acciones.

**Por probar:**

- [ ] P010-1: dos lotes vigentes con vencimientos diferentes: descuento FEFO,
  cantidades exactas y responsable/área/ficha/lotes identificados.
- [ ] P010-2: doble confirmación y dos fichas compitiendo por el mismo stock:
  sin stock negativo, doble consumo ni transacción parcialmente persistida.
- [ ] P010-3: usuario de área ajena o receptor desactivado después de preparar:
  rechazo sin descontar; confirmación válida cierra definitivamente.
- [ ] P010-4: precio de catálogo editado después: consumo previo conserva valores
  históricos; comparar costo por lote y precio aplicado antes de reportar margen.

**No exigir como requisito nuevo:** reserva durante preparación. Primero comprobar
la validación final y atomicidad existentes. Acordar reserva solo si el flujo la necesita.

### HU-011 — Cancelación y rechazo con justificación

**Existe:** ANULAR_FICHA, motivo obligatorio y eventos auditados; restricciones por estado.

**Incumplimientos confirmados:**

- [ ] La anulación de ENTREGADO reintegra stock a Farmacia. Bloquearla según el
  acuerdo de consumo final; revisar datos históricos ya afectados sin modificarlos
  a ciegas. [SQL](../supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql#L1238).
- [ ] Cancelación del área y rechazo de Farmacia no están separados: hay una
  acción ANULAR_FICHA y estado CANCELADO. Diferenciar acción, actor, motivo e
  historial. No imponer un estado RECHAZADO si basta una clasificación auditada,
  pero la distinción debe ser visible y persistente.

**Por probar:**

- [ ] P011-1: cancelar antes de preparación y rechazar desde Farmacia: ambos
  exigen motivo, se distinguen y no mueven stock.
- [ ] P011-2: solicitante intenta cancelar después de que Farmacia tomó el
  pedido: bloqueado según la regla; acciones de Farmacia coherentes con el estado.
- [ ] P011-3: ficha recibida: UI sin opciones y petición directa de anulación
  rechazada; no reingreso ni edición de consumo ni borrado de historial.

**No reabrir el acuerdo:** el pedido recibido queda cerrado. Una devolución física
excepcional sería una operación independiente, a definir fuera de la anulación común.

## 6. Sprint 8 — desarrollo y aceptación

### HU-025 — Kardex por producto

**Existe:** pantalla accesible desde stock/Jefatura, resumen al abrir, movimientos,
búsqueda y filtro tipo/lote, consulta 150 ampliable a 500.
[Vista](../../app/lib/features/almacen/presentation/views/kardex_producto_view.dart#L38).

**Por desarrollar / corregir:**

- [ ] Lotes con cantidades por ubicación, vencimientos y costos; el filtro por
  lotes presentes en movimientos recientes no equivale a ese inventario.
- [ ] Detalle de movimiento con documento/pedido, motivo, costo unitario/total y
  valoración histórica. La RPC tiene `detalles_extra`, pero el modelo Dart actual
  no lo expone; no afirmar que los costos históricos no existen en la base.
- [ ] Paginación de historial completo y filtros de periodo; no tratar 500 como total.
- [ ] Actualizar el resumen de stock al refrescar: actualmente es el objeto recibido
  al abrir y la actualización solo consulta movimientos. La pantalla lo avisa,
  pero todavía no satisface una actualización conjunta de resumen/historial.
- [ ] Revisar clasificación de eventos de devolución/corrección: hay un ELSE
  AJUSTE y una lista de eventos conocidos; verificar cada flujo real antes de
  sumar entradas/salidas. Despacho y recepción internos no son dos consumos.

**Por probar:**

- [ ] P025-1: seguir ingreso → traslado → recepción → consumo con el mismo lote;
  conciliar saldos por ubicación sin sumar dos veces las etapas.
- [ ] P025-2: devolución/ajuste real y sus motivos; valores anteriores estables
  al editar precios actuales; consulta amplia sin perder eventos viejos.
- [ ] P025-3: movimiento desde otro dispositivo y actualizar: resumen e historial
  coherentes. Antes del desarrollo se espera que el resumen siga siendo la foto inicial.

**Dependencias:** estabilizar HU-008 a HU-011 antes de aceptar la conciliación.

### HU-026 — Exportar ficha a PDF

**Evidencia de ausencia en el código revisado:** no se encontró generador de PDF
ni integración de exportación en `app/lib`; `pubspec.yaml` no tiene dependencias
de PDF/impresión. No se acredita implementación por tener la HU documentada.

**Por definir / desarrollar:**

- [ ] Disponer del formato oficial aceptado y decidir si el documento usa los
  datos solicitados o entregados según el estado, identificándolo claramente.
- [ ] Generador con cabecera, médico, área, financiamiento, fechas/usuarios y
  tablas separadas medicamentos/dispositivos, sin depender de datos actuales que
  reescriban la historia. Paginación, nombres largos, tildes y totales legibles.
- [ ] Acción visible para exportar/compartir y errores sin fingir que se creó archivo.

**Por probar:**

- [ ] P026-1: General/Neonatología, varias páginas y entrega parcial: PDF fiel al
  formato y a la ficha guardada, sin ítems cortados ni cantidades intercambiadas.
- [ ] P026-2: archivo abre y se comparte correctamente; falla de escritura/cancelación
  no altera ficha ni stock. Validación visual del archivo, no solo análisis Dart.

### HU-027 — Subir PDF a Google Drive

**Evidencia de ausencia:** no se encontró cliente, autorización ni subida a Drive
en el código de la app. Un correo en perfil y una clave Gemini no conceden ese acceso.

**Por definir / desarrollar:**

- [ ] Elegir identidad autorizada, propietario de carpeta y permisos: OAuth de
  usuario o servicio de servidor autorizado. Confirmar si el destino es personal
  o compartido antes de elegir una solución; no poner secretos administrativos en Flutter.
- [ ] Subir el PDF real de HU-026, mostrar éxito/error y guardar identificador/link
  del archivo y relación con ficha/versión, fecha y responsable.
- [ ] Clave de operación para reintentos, política de versiones y recuperación
  cuando Drive recibió el archivo pero la app perdió la respuesta.

**Por probar:**

- [ ] P027-1: autorización, carpeta correcta, acceso denegado y revocación.
- [ ] P027-2: pérdida de red/reintento y doble toque: un resultado coherente sin
  duplicar documentos; actualizar PDF según la política acordada.

**Dependencia obligatoria:** HU-026; validar acceso externo desde ahora.

### HU-028 — Dashboard de Jefatura

**Existe:** pantalla y accesos a consultas. **Defecto confirmado:** cifras fijas
`3`, `14`, `5`, `98.4%` en las tarjetas. No son indicadores calculados.
[Vista](../../app/lib/features/dashboard_jefatura/presentation/views/jefatura_dashboard_view.dart#L237).

**Por definir / desarrollar:**

- [ ] Acordar umbral de stock crítico, periodo, filtros por área y alcance de
  indicadores. No desarrollar autorizaciones de alto costo solo porque el prototipo
  tiene esa tarjeta: no forma parte automática del alcance acordado.
- [ ] Consultas reales: stock/vencimientos, fichas por estado, consumo y costo/valor
  por área. Distinguir traslado, consumo, corrección y devolución sin duplicación.
- [ ] Cambiar las cifras fijas por datos verificables y estados carga/vacío/error,
  con acceso de lectura y navegación al origen de cada indicador.
- [ ] Mostrar costo, valor de venta/cargo y margen bruto; no dinero cobrado ni
  utilidad neta sin un mecanismo de cobranza que lo acredite.

**Por probar:**

- [ ] P028-1: comparar un área/periodo pequeño contra fichas, lotes y movimientos
  conocidos; cero datos debe mostrar cero/vacío real, nunca cifras de ejemplo.
- [ ] P028-2: cambiar filtro, operar desde otro dispositivo y actualizar;
  Jefatura puede rastrear el dato pero no modificar consumo/stock.

**Dependencias:** HU-025 y eventos consistentes de HU-010/011; costo y precio
históricos. Facturación/cobranza no se presume incluida.

## 7. Orden de trabajo conjunto

### Paso 0 — Asegurar que abrimos el mismo proyecto

- Carpeta habitual del escritorio: está en `Sprint-07`, commit `bb44dd7`.
- Copia de trabajo con el avance de Sprint 8 y este plan:
  `C:\Users\ASUS\Documents\Codex\2026-10-25\empe\work\sprint08-implementation`.
- [ ] Abrir en VS Code la copia acordada y comprobar rama/commit con `git status`
  y `git log -1`. No forzar un checkout ni borrar cambios locales.
- [ ] Identificar el proyecto Supabase al que apunta esa ejecución y la versión
  de las RPC instaladas, mediante inspección de solo lectura, sin leer claves de
  Gemini ni datos clínicos innecesarios.
- [ ] Acordar cuentas/áreas/productos de prueba y capturar stock inicial antes
  de operar. No usar una entrega real como prueba destructiva.
- [ ] Abrir Pixel 8 desde Android Studio; los cambios de código los realizaremos
  desde la misma carpeta que se ejecuta en ese emulador.

### Paso 1 — Recorrido corto antes de corregir

Crear una ficha con un kit ya probado por el usuario; anotar número/área y buscar
en Farmacia después de actualizar. Ver cabecera e historial con Jefatura. No
confirmar todavía consumo ni anular una ficha entregada. Así aislamos si el problema
es registro, permisos, actualización de pantalla o versión de SQL.

### Paso 2 — Corregir contratos que alimentan stock e historial

Receptor y pertenencia al área (003/010); procedencia de kit y confirmación final
(004/005); estado/auditoría (008/009); recepción final y cancelación/rechazo (010/011).
Cada cambio SQL debe ser una migración incremental revisable y reflejarse en setup.
No ejecutar el setup completo ni la migración vieja del Sprint 6 sobre datos existentes:
esta contiene semillas que crean/actualizan usuarios y contraseñas de demostración.

### Paso 3 — Comprobar operación y permisos

Pruebas manuales pequeñas de 003–011, una corrección por vez. Comprobaciones por
terminal de permisos, concurrencia y atomicidad en carpeta externa al proyecto,
cuando sean necesarias. No repetir suites extensas ni probar casos irrelevantes.

### Paso 4 — Asegurar IA sin rehacer el reconocimiento

Mover clave/llamadas a servidor y corregir mensajes/resultados de configuración.
Reutilizar una foto que el usuario ya validó; comprobar fallo de red y rol no autorizado.
La rotación o saneamiento de secretos será una intervención específica, no una
reescritura general de auditoría ni una exposición de valores en consola/commits.

### Paso 5 — Completar consultas y Sprint 8

Paginación/permisos/detalle (006/007); después Kardex conciliado (025) y dashboard
real (028). En paralelo puede prepararse el formato PDF y verificarse el permiso
de Drive; desarrollar 026 antes de la subida 027. Mantener WIP pequeño y cierres
separados: una pantalla nueva no acredita por sí sola toda la HU.

## 8. Decisiones que revisaremos cuando toque, sin repetir lo ya acordado

1. ¿Se necesita realmente médico manual? Por defecto, catálogo según el acuerdo.
2. ¿Quién puede recibir por delegación del área y cómo se acredita? Por defecto,
   el área confirma la recepción física; no confirma Farmacia silenciosamente.
3. ¿Observación individual obligatoria o nota global suficiente para varios faltantes?
4. ¿Aviso dentro de app, push con app cerrada o ambos? ¿Quién recibe cada aviso?
5. ¿Hay necesidad operativa de reservar stock mientras se prepara? No es una
   corrección automática; requiere regla de liberación y revisión de stock disponible.
6. ¿Formato oficial PDF y política de versiones? ¿Qué estados permiten exportarlo?
7. ¿Cuenta/carpeta/permisos de Drive y destino personal o compartido?
8. ¿Umbrales/periodos del dashboard y qué precio histórico se interpreta como cargo?

## 9. Registro de resultados y criterio de cierre

Todavía **no se marca ninguna prueba funcional como aprobada por esta revisión**.
El usuario sí ha confirmado que sus kits y el reconocimiento/llenado funcionan;
se conserva esa evidencia sin extenderla al envío, permisos o consumo no probados.

Usar una fila por prueba Pxxx y actualizar este mismo documento al avanzar:

| Prueba | Fecha | Versión app/RPC | Resultado observado | Evidencia | Estado |
|---|---|---|---|---|---|
| P003-1 | — | — | Pendiente | — | Sin ejecutar |
| P005-1 | — | — | Usuario confirma CRUD de plantillas; falta copia/historia de ficha | Conversación | Parcial |
| P014-1 | — | — | Usuario confirma reconocimiento y llenado; faltan casos de error | Conversación | Parcial |
| HU-003 / regresiones de los tres defectos | 22/11/2026 | Migración receptor/médico 22/11 + código actualizado | 14 pruebas Dart, comprobaciones SQL locales y verificación remota sin cambios de datos | Guía HU-003 del 22/11 | Aprobado en código/contrato; manual pendiente |

Para cerrar cada HU:

- [ ] Requisitos de su sección implementados y decisiones necesarias registradas.
- [ ] Migración incremental aplicada/verificada cuando corresponda, sin perder datos.
- [ ] Pruebas acordadas de la HU aprobadas con resultado/evidencia identificables.
- [ ] Diseño móvil, permisos, historial y efectos de stock coherentes.
- [ ] `flutter analyze` sin observaciones tras los cambios y revisión del diff.
- [ ] Commit breve y push a Sprint-08; actualizar documentación y Project con el
  estado real, sin usar una proyección de daily como evidencia de prueba ejecutada.

Este archivo es el plan operativo vigente para esta revisión. No sustituye las
fechas históricas de entrega académica ni borra las observaciones anteriores:
permite cerrar sus discrepancias con evidencia nueva y pasos verificables.
