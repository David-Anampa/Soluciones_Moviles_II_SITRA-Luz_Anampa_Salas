# Plan de revisión y cierre — Sprints 6, 7 y 8

Fecha: **22/11/2026**. Estado: **plan preparado; correcciones y pruebas pendientes**.

**Avance HU-003 del 22/11:** los tres defectos de receptor, médico manual y
guardado/refresco están corregidos en código y la migración incremental está
aplicada/verificada en Supabase. También se reutiliza el validador del receptor al
entregar. Ver [guía de corrección y pruebas](../supabase/GUIA_HU003_RECEPTOR_MEDICO_2026_11_22.md).
Pruebas dirigidas y análisis estático aprobados; comprobación manual con el usuario
todavía pendiente. Las descripciones originales siguientes son el diagnóstico
base: no interpretar estos tres defectos como aún presentes en la versión corregida.

**Diseño HU-003 del 22/11:** formulario y selector individual adaptados a ancho,
texto ampliado y teclado. Se conservan tema y tamaños tipográficos existentes.
Ver [alcance y emulador de trabajo](HU003_DISENO_ADAPTABLE_Y_EMULADOR_2026-11-22.md).

**Ajuste visual HU-003 del 27/11:** Nueva ficha usa dos pestañas anchas para
Otras áreas / Neonatología y colores del módulo en todo el formulario y selectores.
Enfermería/Técnico rojo, Farmacia verde; no toma el azul del área seleccionada.
Se conservan las áreas autorizadas y la lógica de registro. `flutter analyze`
aprobado; P003-1 y las demás pruebas manuales siguen pendientes de confirmación.

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


**Guía de ejecución por roles actualizada el 27/11/2026:** cada prueba Pxxx
indica ejecutor, destinatario/consulta, estado y preparación. La revisión funcional
actual está en **HU-003**; ninguna casilla se aprueba por esta actualización.
Los hallazgos de código conservan su fecha base salvo actualización expresa.

### Cómo usar las cuentas y registrar una prueba

| Rol de prueba | Cuenta inicial documentada | Papel |
|---|---|---|
| Enfermería/Técnico | `enfermeria@sitraluz.pe` | Solicita para sus áreas autorizadas y confirma recepción física. |
| Farmacia | `farmacia@sitraluz.pe` | Recibe pedidos clínicos, prepara y despacha; solicita/recibe abastecimiento de Almacén. |
| Almacén | `almacen@sitraluz.pe` | Reconocimiento/ingresos y abastecimiento; no solicitante clínico ni receptor del área. |
| Jefatura | `jefatura@sitraluz.pe` | Consulta, compara historial y supervisa; no opera el consumo. |
| Administración | `admin@sitraluz.pe` | Prepara perfiles/catálogos de prueba y configuración de integración cuando procede. |

- Son cuentas documentadas, no una verificación nueva de acceso/estado/áreas en
  Supabase. Confirmar perfiles y asignaciones antes de probar; no guardar claves aquí.
- No usar Administración abriendo el menú de otro rol para acreditar permisos
  de ese rol: el color del módulo es visual, la identidad sigue siendo Administrador.
- En el flujo normal de HU-003, **Enfermería del área solicita a Farmacia**.
  Farmacia también puede capturar una ficha: es un caso alternativo, cuyo autor
  registrado será el usuario de Farmacia, no el técnico del área elegida. Anotarlo
  por separado; no sustituye la comprobación del solicitante de Enfermería.
- Verificar qué áreas tiene la cuenta de Enfermería. Si no incluye Neonatología,
  falta preparar una cuenta/asignación autorizada antes de probar ese formato;
  no asumir que la cuenta inicial cubre todas las áreas.
- Anotar para cada paso: cuenta/rol real, área, número de ficha/pedido,
  estado anterior, acción, resultado/estado posterior y dispositivo si hay dos.
- Las preparaciones de cuentas, datos, concurrencia y peticiones negativas son
  instrucciones para cuando se autorice esa prueba; no se ejecutan al editar este
  Markdown. No crear fichas masivas ni tocar usuarios, entregas o stock reales.
- Las funciones aún sin desarrollar se registran como no ejecutables; los roles
  sugeridos de PDF/Drive son propuestas, no permisos ya implementados/acordados.

## 2. Resumen por historia

| Sprint | HU | Estado frente al alcance acordado | Principal pendiente |
|---|---|---|---|
| 6 | 003 | Correcciones implementadas; aceptación manual pendiente | Comprobar registro/edición con receptor y médico válidos y diseño en el dispositivo |
| 6 | 004 | Parcial | Excepción de kits verificable y consultas de catálogo completas |
| 6 | 005 | Parcial | Modal final y fotografía histórica de faltantes al enviar |
| 6 | 014 | Reconocimiento implementado; servidor seguro desplegado | Comprobar extracción mediante servidor, errores y sin red |
| 6 | 015 | Gestión cifrada de claves implementada; aceptación pendiente | Comprobar nueva gestión y guardado de reconocimiento sin duplicación |
| 7 | 006 | Parcial | Paginación, contadores y permisos de lectura coherentes |
| 7 | 007 | Implementada con deficiencias de consulta | Evitar detalle incompleto cuando falta la RPC |
| 7 | 008 | Parcial | Estado real/auditoría, notificación y dos confirmaciones distintas |
| 7 | 009 | Implementada con corrección compartida pendiente | Cantidades reales y coherencia de auditoría de preparación |
| 7 | 010 | Parcial | Receptor válido y cierre conforme a recepción del área |
| 7 | 011 | No conforme con el último acuerdo | Separar rechazo/cancelación e impedir anular consumo confirmado |
| 8 | 025 | Primer avance implementado | Lotes, valores históricos, paginación y conciliación |
| 8 | 026 | Pendiente de desarrollo | Exportación real y aceptación del formato oficial |
| 8 | 027 | Pendiente de desarrollo | Autorización/destino Drive, subida, reintentos y duplicados |
| 8 | 028 | Menú uniformizado; dashboard real pendiente | Implementar indicadores verificados; las cifras fijas ya se retiraron |

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

- [ ] P003-1: **Ejecuta:** Enfermería/Técnico del área solicitante.
  **Recibe / consulta:** Farmacia consulta la ficha recibida; Jefatura comprueba datos e historial.
  **Partida:** Crear primero General y luego Neonatología. Cuenta activa autorizada para cada área, médico de catálogo, receptor válido y productos de prueba. Si la cuenta de Enfermería no tiene Neonatología, revisar la asignación antes; no sustituir silenciosamente al solicitante por Farmacia.
  **Comprobar:** registrar una General y una Neonatología con datos de prueba; comprobar valores guardados y visualizados en Farmacia/Jefatura.
- [ ] P003-2: **Ejecuta:** Enfermería/Técnico registra; Administración prepara perfiles exclusivamente de prueba.
  **Recibe / consulta:** Farmacia y Jefatura comprueban que no apareció una ficha incompleta.
  **Partida:** Borrador sin guardar; receptor de otra área, inactivo o con rol no permitido. Primero comprobar que no se ofrezca en UI. Para demostrar rechazo del servidor hace falta una petición controlada externa al proyecto; no manipular usuarios reales ni ejecutar automáticamente.
  **Comprobar:** receptor de otra área, rol no permitido o desactivado: rechazo también en servidor, sin cabecera/ítems/auditoría parciales.
- [ ] P003-3: **Ejecuta:** Enfermería/Técnico, autor de la ficha; Farmacia inicia preparación en un segundo momento.
  **Recibe / consulta:** Farmacia consulta; Jefatura revisa duplicados e historial.
  **Partida:** Ficha propia SOLICITADO. Probar edición/reintento en ese estado; después Farmacia pasa a EN_PREPARACION y el solicitante vuelve a intentar editar. Anotar número e identificador de reintento.
  **Comprobar:** editar SOLICITADO; después de preparación debe bloquearse. Reintentar un guardado con el mismo identificador: una sola ficha.

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

- [ ] P004-1: **Ejecuta:** Enfermería/Técnico, desde el registro de una ficha.
  **Recibe / consulta:** Farmacia consulta únicamente si el registro válido termina guardándose.
  **Partida:** Borrador General o Neonatología del área autorizada. Productos de prueba con stock disponible, sin stock, vencido/inactivo y existencias solo en Almacén o tránsito; registrar disponibilidad inicial.
  **Comprobar:** producto sin stock, cantidad cero/negativa, mayor que disponible, lote vencido/inactivo y existencias solo en Almacén/tránsito: rechazo correcto.
- [ ] P004-2: **Ejecuta:** Sesión de Enfermería/Técnico, mediante petición controlada por terminal.
  **Recibe / consulta:** Servidor debe rechazar; Jefatura puede comprobar ausencia de registros parciales.
  **Partida:** Entorno/datos de prueba, petición de registro alterada y sin kit autorizado. Preparar el script fuera del repositorio; la identidad debe ser la del rol que solicita, sin service_role que omita sus permisos.
  **Comprobar:** petición modificada con `origen_kit=true` sin kit válido: no saltar la restricción. Comprobación por terminal en carpeta externa al proyecto.
- [ ] P004-3: **Ejecuta:** Enfermería/Técnico selecciona; Farmacia opera stock de prueba desde otro dispositivo.
  **Recibe / consulta:** Enfermería vuelve a consultar disponibilidad; Jefatura puede verificar movimientos.
  **Partida:** Producto fuera de las primeras páginas y borrador aún no enviado. Registrar qué operación legítima cambió su disponibilidad; no editar stock directamente para simularlo.
  **Comprobar:** producto fuera de las primeras páginas y stock cambiado desde otro dispositivo: consultar y validar la disponibilidad real, sin falsos ceros.

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

- [ ] P005-1: **Ejecuta:** Enfermería/Técnico del área aplica el kit y registra la ficha.
  **Recibe / consulta:** Farmacia consulta la copia recibida; Jefatura compara historial.
  **Partida:** Plantilla activa del área y productos de prueba. Guardar número/composición de ficha; luego editar la plantilla con una cuenta autorizada para gestionarla. No confundir CRUD de plantilla con envío a Farmacia.
  **Comprobar:** aplicar kit, modificar cantidades/agregar/quitar; guardar ficha, editar luego la plantilla y comprobar que la ficha conserva su composición.
- [ ] P005-2: **Ejecuta:** Enfermería/Técnico solicita; Farmacia genera un cambio controlado de disponibilidad en otro dispositivo.
  **Recibe / consulta:** Farmacia debe ver los faltantes confirmados en la ficha; Jefatura consulta auditoría.
  **Partida:** Kit completo al copiar y con faltantes antes de enviar. Distinguir la confirmación al copiar de la confirmación final de envío; si esta última falta, registrar pendiente y no aprobar por el primer diálogo.
  **Comprobar:** kit completo al copiar e incompleto al enviar: modal actualizado, decisión expresa y faltantes persistidos; no acreditar stock de Almacén.
- [ ] P005-3: **Ejecuta:** Enfermería/Técnico del área A; una cuenta autorizada prepara un kit inactivo/de otra área de prueba.
  **Recibe / consulta:** Farmacia/Jefatura consultan únicamente la ficha histórica que corresponda.
  **Partida:** Una plantilla del área B, una deshabilitada y una ficha histórica ya creada. No conceder área B solo para conseguir que aparezca; comprobar precisamente la restricción.
  **Comprobar:** kit de otra área o deshabilitado: no usarlo para nueva ficha; comprobar edición histórica según las reglas del servidor.

**No pendiente de redefinición:** el modal y su auditoría ya fueron acordados.

### HU-014 — Reconocimiento GTIN/fotografía

**Existe y usuario confirma funcionamiento:** escaneo local GS1/GTIN, lectura de
fotografías con Gemini y llenado de campos; catálogo y borrador local ante fallos.
[Servicio](../../app/lib/features/almacen/data/services/medicamento_ia_service.dart#L461).

**Por corregir / completar:**

- [x] Llamada directa sustituida por `gemini-ia`, función autenticada desplegada
  el 22/11/2026. Solo Administrador y Almacén activos pueden invocarla; utiliza
  Vault sin devolver la credencial al móvil. Se mantiene el prompt multimodal
  y la normalización existentes. Retirado el respaldo sin implementación.
- [ ] Comprobar mensajes de clave inválida, cuota agotada, tiempo de espera y
  sin red; no mezclar éxito de catálogo/GS1 con extracción IA exitosa.

**Por probar:**

- [ ] P014-1: **Ejecuta:** Almacén realiza el reconocimiento.
  **Recibe / consulta:** Almacén revisa el resultado; no hay pedido a Farmacia en esta operación.
  **Partida:** Módulo Escanear/Registrar medicamento, imagen de prueba previamente validada y credencial activa de servidor. Administración solo prepara la clave si hace falta; Almacén no la escribe ni la lee.
  **Comprobar:** reutilizar una captura que ya funcionó; validar GTIN/lote/fecha, fotos múltiples, cancelación y corrección manual sin pérdida durante el flujo.
- [ ] P014-2: **Ejecuta:** Almacén intenta reconocer; Administración prepara configuración de error solo si procede.
  **Recibe / consulta:** Almacén recibe el aviso de error.
  **Partida:** Borrador sin guardar. Probar sin red/foto ilegible; cuota o clave inválida solo con configuración controlada de prueba, sin invalidar claves compartidas o provocar consumo innecesario.
  **Comprobar:** sin red, foto ilegible, cuota/clave inválida: aviso comprensible, sin datos ficticios ni registro automático de datos no revisados.

**Decisión opcional:** persistir borradores tras cerrar la app es alcance adicional
si se solicita; conservarlos durante el flujo ya es requisito.

### HU-015 — Revisar, corregir y guardar extracción

**Existe:** formulario editable, categoría, revisión antes del guardado e ingreso
mediante el flujo atómico de HU-024. La IA no debe registrar directamente sin revisión.
[Guardado](../../app/lib/features/almacen/presentation/views/registro_medicamento_view.dart#L884).

**Confirmado / por corregir, compartido con HU-014:**

- [x] Credenciales múltiples cifradas en Supabase Vault; metadatos y fechas
  separados. La app no obtiene el secreto. Gestión exclusiva de Administrador
  por ruta, vista y RPC; Almacén solo utiliza reconocimiento autenticado.
- [x] Retirados diálogo anterior, mostrar/ocultar y lectura/escritura de claves
  en preferencias y auditoría. Se limpian preferencias antiguas al iniciar.
  Guardado con resultado real, controles bloqueados durante la operación y
  refresco separado del resultado de persistencia.
- [x] Migración aplicada: no había eventos de claves que importar. Se conserva
  la auditoría y se retira solo el campo secreto si existiera en otra instalación.
  Administrador debe añadir la primera clave. No se ha probado Gemini con una
  clave real en este avance.

Ver [guía del módulo y despliegue](CLAVES_IA_Y_MENU_ADMIN_2026-11-22.md).

**Por probar:**

- [ ] P015-1: **Ejecuta:** Almacén revisa, corrige y guarda el reconocimiento.
  **Recibe / consulta:** Almacén vuelve a consultar el ingreso; Farmacia/Jefatura pueden consultar existencias.
  **Partida:** Reconocimiento completado y revisado; producto/lote de prueba. Registrar cantidad y ubicación inicial. No despachar a Farmacia como parte de esta comprobación.
  **Comprobar:** corregir lo reconocido, guardar y volver a consultar: cambios persistidos; lote duplicado bloqueado y stock registrado solo en Almacén.
- [ ] P015-2: **Ejecuta:** Almacén guarda el borrador de reconocimiento.
  **Recibe / consulta:** Almacén comprueba el registro; Jefatura consulta ingreso e historial.
  **Partida:** Mismo producto/lote e identificador de operación; simular corte/reintento de forma controlada. No crear un segundo ingreso como supuesto remedio al error.
  **Comprobar:** reintento/doble toque y fallo de red: sin producto/lote/stock parcial.
- [ ] P015-3: **Ejecuta:** Administración configura claves; Almacén usa IA desde otro dispositivo; Farmacia/Enfermería/Jefatura prueban denegación.
  **Recibe / consulta:** Almacén ve el reconocimiento; los roles no autorizados reciben denegación.
  **Partida:** Clave de servidor activa, perfiles separados. Distinguir permiso de Administrador para configurar, permiso de Almacén para reconocer y denegación a los demás. No mostrar secretos en capturas o registros.
  **Comprobar:** otro dispositivo de Almacén usa IA sin leer/ingresar la clave; rol no autorizado no configura ni ejecuta extracción; error al guardar no es éxito.

**Definido:** una clave en uso y varias guardadas; Administrador puede reemplazar,
activar o eliminar con confirmación y auditoría. No hay rotación automática por cuota.
**Por definir si se requiere:** límites adicionales por usuario. Actualmente se
comprueba rol/sesión y se informa el límite del proveedor.

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

- [ ] P006-1: **Ejecuta:** Enfermería/Técnico crea el pedido; Farmacia abre su listado y actualiza.
  **Recibe / consulta:** Farmacia lee la solicitud del área; Jefatura puede consultarla.
  **Partida:** Ficha SOLICITADO identificada por número y área; no preparar ni entregar para probar solo la consulta. Verificar entrada desde aviso, filtros y restablecimiento.
  **Comprobar:** ficha creada en área aparece en Farmacia después de actualizar; buscar por su número y probar cada filtro/restablecimiento.
- [ ] P006-2: **Ejecuta:** Enfermería de áreas A/B, Farmacia, Jefatura y Almacén en sesiones separadas.
  **Recibe / consulta:** Cada rol consulta su alcance permitido; Almacén no debe obtener lectura clínica global.
  **Partida:** Conjunto de datos aislado suficiente para paginación. Enfermería A no debe leer B sin autorización; Farmacia/Jefatura consultan según matriz acordada. No usar Administración como reemplazo de esos roles ni generar 120 fichas en producción.
  **Comprobar:** varios roles/áreas y más de 120 registros controlados: permisos, páginas y contadores correctos. No generar masivamente registros reales para probar.

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

- [ ] P007-1: **Ejecuta:** Enfermería/Técnico del área, Farmacia y Jefatura abren la misma ficha.
  **Recibe / consulta:** Los tres comparan datos; Jefatura solo consulta.
  **Partida:** Ficha de prueba ya guardada, con número/área conocidos. Verificar campos e historial sin cambiar estado durante la comparación.
  **Comprobar:** misma ficha desde área, Farmacia y Jefatura: encabezado, médico, seguro, solicitante, fechas y cantidades coinciden; Jefatura no opera estados.
- [ ] P007-2: **Ejecuta:** Farmacia consulta el detalle; Jefatura coteja el historial.
  **Recibe / consulta:** Enfermería consulta su ficha dentro de su área.
  **Partida:** Una ficha reciente y otra antigua con eventos conocidos. Fallo de RPC solo en entorno controlado; no borrar funciones del servidor compartido para provocar el error.
  **Comprobar:** recorrer su historial y comparar cada estado/evento con la cabecera, incluyendo una ficha antigua; fallo de RPC no aparece como historial vacío normal.

**Dependencias:** corregir auditoría HU-008/009 y definir las acciones HU-010/011.

### HU-008 — Estados de preparación y despacho

**Existe:** SOLICITADO → EN_PREPARACION → LISTO_PARA_RECOJO → ENTREGADO,
RPC con bloqueo por ficha e identificador de operación.

**Confirmado / por corregir:**

- [ ] Guardar preparación desde LISTO_PARA_RECOJO conserva ese estado en cabecera,
  pero auditoría escribe EN_PREPARACION. Unificar usando el estado realmente
  persistido. [SQL estado](../supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql#L881),
  [SQL auditoría](../supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql#L920).
- [ ] Falta conectar los eventos operativos de solicitud/listo. **Actualización
  27/11:** FCM ya está habilitado y el usuario confirmó recepción del push PRUEBA;
  hay registro de dispositivos y bandeja. Eso no acredita envío automático de
  pedidos ni apertura de la ficha correspondiente. Conectar esos eventos sin
  duplicar avisos; mantener separada lectura de aviso y atención del pedido.
  [Servicio](../../app/lib/core/services/notification_service.dart#L26).
- [ ] La idempotencia compara solo `operacion_atencion_id` de la última operación.
  Probar reintentos antiguos después de otra transición; es un riesgo de cobertura,
  no prueba de doble descuento. Reforzar con registro de operaciones si falla.

**Por probar:**

- [ ] P008-1: **Ejecuta:** Farmacia prepara, marca listo y guarda nuevamente si la UI lo permite.
  **Recibe / consulta:** Enfermería del área ve el estado; Jefatura compara cabecera e historial.
  **Partida:** Ficha SOLICITADO enviada por el área. Recorrer EN_PREPARACION y LISTO_PARA_RECOJO; detenerse antes de confirmar consumo. No marcar conforme si historial y cabecera discrepan.
  **Comprobar:** preparación/listo y guardar nuevamente; cabecera e historial coinciden y los usuarios solo ven las acciones permitidas.
- [ ] P008-2: **Ejecuta:** Dos operadores con cuentas Farmacia autorizadas, en dispositivos/sesiones separados.
  **Recibe / consulta:** Enfermería/Jefatura consultan resultado e historial.
  **Partida:** Misma ficha e identificadores de operaciones anotados; prueba de concurrencia con datos aislados. Conservar un identificador antiguo para comprobar reintento después de otra transición.
  **Comprobar:** doble toque, reintento tras corte y dos operadores: una transición lógica, sin auditoría duplicada ni retroceso por un reintento antiguo.
- [ ] P008-3: **Ejecuta:** Enfermería/Técnico envía solicitud; luego Farmacia marca listo.
  **Recibe / consulta:** Farmacia recibe aviso de solicitud; Enfermería del área recibe aviso de recojo.
  **Partida:** Ficha y destinatarios identificados, permisos de notificación concedidos. El push PRUEBA ya recibido no acredita eventos operativos: ejecutar estos casos cuando estén conectados.
  **Comprobar:** solicitud/listo genera el aviso al destinatario y abre la ficha correcta.

**Definido posteriormente:** aviso interno con la aplicación visible; notificación
Android con tono breve y vibración corta en segundo plano. Queda conectar y probar
los destinatarios por evento y área; refrescar una lista no equivale a notificar.

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

- [ ] P009-1: **Ejecuta:** Farmacia edita cantidades de preparación.
  **Recibe / consulta:** Enfermería puede consultar el pedido; Jefatura verifica resultado.
  **Partida:** Ficha de prueba en EN_PREPARACION, solicitado y stock inicial conocidos. Probar cantidades inválidas sin confirmar entrega; validación SQL mediante petición controlada si hace falta.
  **Comprobar:** cantidades 0, negativa, superior a solicitada y superior a stock; rechazo consistente entre interfaz y SQL.
- [ ] P009-2: **Ejecuta:** Enfermería solicita 5; Farmacia prepara 3 y justifica.
  **Recibe / consulta:** Enfermería revisa lo preparado; Jefatura compara cantidades y motivo.
  **Partida:** Ficha SOLICITADO con cinco unidades válidamente solicitadas. Pasar a preparación, registrar tres y motivo. La recepción/consumo se verifica después con HU-010; preparar no equivale a recibir.
  **Comprobar:** solicitar 5 y entregar 3: exige motivo, conserva solicitado=5, entregado=3 y solo esas 3 unidades se consumen después de recepción final.

**Definir:** si la nota global es suficiente o se exige una justificación separada
en cada línea parcial; no eliminar sin más una opción que el sistema ya admite.

### HU-010 — Confirmar recepción y descontar stock

**Existe:** bloqueo transaccional, FEFO sobre lotes activos/vigentes, desglose por
lote, datos económicos y eventos de consumo. Rechaza una segunda entrega y una
ficha que ya tenga detalle de descuento por lote.

**Confirmado / por corregir:**

- [x] Validación central de receptor activo, rol y área reutilizada al entregar
  mediante la migración del 22/11, ya documentada en HU-003. Falta su aceptación
  manual P010-3, incluida desactivación posterior a la preparación.
  [SQL](../supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql#L1004).
- [ ] Farmacia/Admin pueden confirmar desde EN_PREPARACION, sin paso LISTO ni
  confirmación del área. Alinear con las dos recepciones acordadas. Una recepción
  delegada necesitaría regla y auditoría explícitas, no una sustitución silenciosa.
  [SQL](../supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql#L946).
- [ ] Al finalizar, dejar solo consulta y no modificar/anular desde otras acciones.

**Por probar:**

- [ ] P010-1: **Ejecuta:** Farmacia deja listo; Enfermería/Técnico receptor autorizado confirma recepción.
  **Recibe / consulta:** Jefatura consulta consumo y lotes; Farmacia comprueba existencias.
  **Partida:** Ficha LISTO_PARA_RECOJO, cantidades preparadas y dos lotes activos/vigentes con fechas distintas. Anotar saldos iniciales. El área receptora confirma físicamente, no Farmacia en su lugar.
  **Comprobar:** dos lotes vigentes con vencimientos diferentes: descuento FEFO, cantidades exactas y responsable/área/ficha/lotes identificados.
- [ ] P010-2: **Ejecuta:** Receptores autorizados de Enfermería en sesiones separadas; Farmacia prepara previamente ambas fichas.
  **Recibe / consulta:** Farmacia/Jefatura concilian existencias y movimientos.
  **Partida:** Dos fichas LISTO_PARA_RECOJO con productos que comparten stock y una repetición de confirmación. Solo entorno/datos aislados; conservar identificadores para detectar doble consumo.
  **Comprobar:** doble confirmación y dos fichas compitiendo por el mismo stock: sin stock negativo, doble consumo ni transacción parcialmente persistida.
- [ ] P010-3: **Ejecuta:** Enfermería de otra área intenta confirmar; Administración prepara la desactivación de un receptor de prueba.
  **Recibe / consulta:** Receptor válido del área confirma después; Farmacia/Jefatura verifican ausencia de descuentos por intentos rechazados.
  **Partida:** Ficha LISTO_PARA_RECOJO y receptor inicialmente válido, desactivado después de preparar. No desactivar cuentas reales. Una confirmación hecha solo por Farmacia no acredita el criterio acordado.
  **Comprobar:** usuario de área ajena o receptor desactivado después de preparar: rechazo sin descontar; confirmación válida cierra definitivamente.
- [ ] P010-4: **Ejecuta:** Cuenta autorizada de Almacén/Administración cambia un precio de catálogo de prueba; Jefatura compara.
  **Recibe / consulta:** Farmacia/área consultan la ficha histórica.
  **Partida:** Consumo de prueba ya confirmado y precio/costo anterior anotados. Cambiar precio actual por el flujo autorizado; no editar el movimiento histórico ni asumir margen sin valores identificados.
  **Comprobar:** precio de catálogo editado después: consumo previo conserva valores históricos; comparar costo por lote y precio aplicado antes de reportar margen.

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

- [ ] P011-1: **Ejecuta:** Enfermería solicitante cancela; Farmacia rechaza una segunda ficha.
  **Recibe / consulta:** Farmacia y el área consultan el resultado; Jefatura revisa actores y motivos.
  **Partida:** Dos fichas SOLICITADO separadas. Motivo obligatorio en ambas acciones. Si solo existe anulación indiferenciada, registrar defecto; no aceptar una etiqueta cambiada sin evento distinguible.
  **Comprobar:** cancelar antes de preparación y rechazar desde Farmacia: ambos exigen motivo, se distinguen y no mueven stock.
- [ ] P011-2: **Ejecuta:** Farmacia toma el pedido; Enfermería solicitante intenta cancelarlo después.
  **Recibe / consulta:** Farmacia/Jefatura revisan acciones e historial.
  **Partida:** Ficha EN_PREPARACION. La cancelación del solicitante debe bloquearse según el acuerdo; comprobar opciones de Farmacia sin forzar una entrega.
  **Comprobar:** solicitante intenta cancelar después de que Farmacia tomó el pedido: bloqueado según la regla; acciones de Farmacia coherentes con el estado.
- [ ] P011-3: **Ejecuta:** Enfermería/área, Farmacia y Administración comprueban el cierre; petición negativa controlada por terminal.
  **Recibe / consulta:** Jefatura verifica conservación de consumo e historial.
  **Partida:** Ficha de prueba ENTREGADO/recepción final, exclusivamente en entorno aislado para la petición directa. Si se ofrece anular/reintegrar, registrar defecto sin ejecutarlo sobre una entrega real. El reintegro actual es una discrepancia conocida, no un comportamiento aceptado.
  **Comprobar:** ficha recibida: UI sin opciones y petición directa de anulación rechazada; no reingreso ni edición de consumo ni borrado de historial.

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

- [ ] P025-1: **Ejecuta:** Almacén registra y despacha; Farmacia recibe y prepara; Enfermería confirma recepción del pedido clínico.
  **Recibe / consulta:** Jefatura sigue el mismo producto/lote en Kardex.
  **Partida:** Cadena de operaciones de prueba vinculadas por documentos, pedido de abastecimiento y ficha clínica. Registrar saldos de Almacén, tránsito y Farmacia antes de cada paso; consulta no cambia stock.
  **Comprobar:** seguir ingreso → traslado → recepción → consumo con el mismo lote; conciliar saldos por ubicación sin sumar dos veces las etapas.
- [ ] P025-2: **Ejecuta:** Farmacia/Almacén realizan devolución física o corrección autorizada de prueba; Jefatura consulta Kardex.
  **Recibe / consulta:** Jefatura concilia motivos e importes históricos.
  **Partida:** Operación de prueba identificada y motivo real del ajuste/devolución. No usar anulación de consumo confirmado como devolución; comparar precios históricos y actuales sin reescribir los anteriores.
  **Comprobar:** devolución/ajuste real y sus motivos; valores anteriores estables al editar precios actuales; consulta amplia sin perder eventos viejos.
- [ ] P025-3: **Ejecuta:** Farmacia o Almacén registra un movimiento legítimo desde otro dispositivo; Jefatura actualiza Kardex.
  **Recibe / consulta:** Jefatura compara resumen e historial.
  **Partida:** Producto/lote y saldos iniciales anotados. Mantener la pantalla abierta durante el movimiento; documentar si el resumen queda desactualizado, sin modificar existencias para corregir la presentación.
  **Comprobar:** movimiento desde otro dispositivo y actualizar: resumen e historial coherentes. Antes del desarrollo se espera que el resumen siga siendo la foto inicial.

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

- [ ] P026-1: **Ejecuta:** Propuesta pendiente de acordar: Farmacia exporta; Jefatura valida el documento.
  **Recibe / consulta:** Jefatura compara el PDF con la ficha guardada.
  **Partida:** No ejecutable hasta implementar HU-026 y acordar permisos de exportación/formato. Fichas General y Neonatología, suficientes ítems y una entrega parcial de prueba; no cambiar estados para fabricar el documento.
  **Comprobar:** General/Neonatología, varias páginas y entrega parcial: PDF fiel al formato y a la ficha guardada, sin ítems cortados ni cantidades intercambiadas.
- [ ] P026-2: **Ejecuta:** Rol exportador por confirmar al implementar; propuesta: Farmacia.
  **Recibe / consulta:** Usuario autorizado abre/recibe el archivo; Jefatura valida.
  **Partida:** Generador HU-026 implementado y permisos acordados. Archivo de prueba y almacenamiento disponible; abrir/compartir no debe modificar ficha ni existencias.
  **Comprobar:** archivo abre y se comparte correctamente; falla de escritura/cancelación no altera ficha ni stock. Validación visual del archivo, no solo análisis Dart.

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

- [ ] P027-1: **Ejecuta:** Administración prepara integración; identidad Google autorizada concede acceso; rol de envío aún por acordar.
  **Recibe / consulta:** Jefatura o destinatario autorizado comprueba carpeta y archivo.
  **Partida:** No ejecutable hasta implementar HU-026/027, definir dueño de carpeta y OAuth/cuenta de servicio. Ser Administrador en SITRA no concede permisos de Google Drive automáticamente.
  **Comprobar:** autorización, carpeta correcta, acceso denegado y revocación.
- [ ] P027-2: **Ejecuta:** Rol de envío por acordar; propuesta: Farmacia usando PDF generado; servidor ejecuta con credencial autorizada.
  **Recibe / consulta:** Jefatura/destinatario con permiso verifica enlace y versión.
  **Partida:** Integración desarrollada y autorizada, PDF real de prueba, misma clave de reintento y política de versiones acordada. No probar sobre documentos clínicos reales ni revocar cuentas compartidas.
  **Comprobar:** pérdida de red/reintento y doble toque: un resultado coherente sin duplicar documentos; actualizar PDF según la política acordada.

**Dependencia obligatoria:** HU-026; validar acceso externo desde ahora.

### HU-028 — Dashboard de Jefatura

**Actualización 27/11:** el menú de Jefatura ya está uniformizado en azul y ofrece
cinco consultas reales. Se retiraron las cifras fijas `3`, `14`, `5`, `98.4%`, la
alerta de ejemplo y botones sin destino. **Sigue pendiente el dashboard de
indicadores calculados**; retirar el prototipo no acredita HU-028.
[Vista](../../app/lib/features/dashboard_jefatura/presentation/views/jefatura_dashboard_view.dart#L237).

**Por definir / desarrollar:**

- [ ] Acordar umbral de stock crítico, periodo, filtros por área y alcance de
  indicadores. No desarrollar autorizaciones de alto costo solo porque el prototipo
  tiene esa tarjeta: no forma parte automática del alcance acordado.
- [ ] Consultas reales: stock/vencimientos, fichas por estado, consumo y costo/valor
  por área. Distinguir traslado, consumo, corrección y devolución sin duplicación.
- [ ] Desarrollar los indicadores verificables con estados carga/vacío/error y
  navegación al origen. Las cifras fijas ya fueron retiradas del menú el 27/11;
  no restaurarlas como sustituto del dashboard.
- [ ] Mostrar costo, valor de venta/cargo y margen bruto; no dinero cobrado ni
  utilidad neta sin un mecanismo de cobranza que lo acredite.

**Por probar:**

- [ ] P028-1: **Ejecuta:** Jefatura consulta indicadores.
  **Recibe / consulta:** Farmacia/Almacén/Enfermería aportan registros controlados ya conocidos; Jefatura concilia.
  **Partida:** Dashboard de indicadores reales pendiente. Elegir un área y periodo pequeños, fichas y lotes identificados. El menú azul actual no equivale a este dashboard; sin datos debe verse cero/vacío real.
  **Comprobar:** comparar un área/periodo pequeño contra fichas, lotes y movimientos conocidos; cero datos debe mostrar cero/vacío real, nunca cifras de ejemplo.
- [ ] P028-2: **Ejecuta:** Jefatura filtra y actualiza; Farmacia/Almacén/Enfermería operan en otra sesión según su permiso.
  **Recibe / consulta:** Jefatura sigue el origen del indicador, sin editar movimientos.
  **Partida:** Dashboard implementado, área/periodo y dato inicial anotados. Usar cuentas reales del rol de prueba, no Administración abriendo el módulo, para acreditar solo lectura.
  **Comprobar:** cambiar filtro, operar desde otro dispositivo y actualizar; Jefatura puede rastrear el dato pero no modificar consumo/stock.

**Dependencias:** HU-025 y eventos consistentes de HU-010/011; costo y precio
históricos. Facturación/cobranza no se presume incluida.

## 7. Orden de trabajo conjunto

### Paso 0 — Asegurar que abrimos el mismo proyecto

- **Actualización 27/11:** carpeta local vigente:
  `C:\Users\ASUS\Desktop\UPT\X\MOVILES\UNIDAD II\Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas`.
- Rama de trabajo `Sprint-08`; último cambio de aplicación anterior a esta edición:
  `3f4def2` (menú de Jefatura). La copia externa y la referencia a Sprint-07 eran
  el estado inicial del 22/11; no usarlas como carpeta vigente del emulador.
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

Desde Enfermería/Técnico del área autorizada, crear la ficha General de P003-1;
anotar cuenta, número y área. Cambiar a Farmacia, actualizar y buscar ese número;
luego consultar cabecera e historial con Jefatura. Repetir Neonatología con cuenta
habilitada para esa área. No es obligatorio aplicar un kit para probar HU-003:
la copia/confirmación del kit se revisa en HU-005. No confirmar todavía consumo
ni anular una ficha entregada. Así aislamos registro, permisos y actualización.

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

El servidor seguro y la gestión cifrada ya están desplegados: comprobar sus
mensajes y resultados con Almacén, configurando desde Administración solo cuando
haga falta. Reutilizar una foto validada; comprobar fallo de red y rol no autorizado.
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
4. Aviso interno/push y tono ya acordados. Confirmar destinatarios de cada evento
   operativo por área y su navegación, sin reabrir la elección de presentación.
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

| Prueba | Roles de ejecución / consulta | Cuenta / área / ficha | Fecha | Versión app/RPC | Resultado observado | Evidencia | Estado |
|---|---|---|---|---|---|---|---|
| P003-1 | Enfermería/Técnico del área solicitante; Farmacia consulta la ficha recibida; Jefatura comprueba datos e historial | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P003-2 | Enfermería/Técnico registra; Administración prepara perfiles exclusivamente de prueba; Farmacia y Jefatura comprueban que no apareció una ficha incompleta | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P003-3 | Enfermería/Técnico, autor de la ficha; Farmacia inicia preparación en un segundo momento; Farmacia consulta; Jefatura revisa duplicados e historial | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P004-1 | Enfermería/Técnico, desde el registro de una ficha; Farmacia consulta únicamente si el registro válido termina guardándose | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P004-2 | Sesión de Enfermería/Técnico, mediante petición controlada por terminal; Servidor debe rechazar; Jefatura puede comprobar ausencia de registros parciales | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P004-3 | Enfermería/Técnico selecciona; Farmacia opera stock de prueba desde otro dispositivo; Enfermería vuelve a consultar disponibilidad; Jefatura puede verificar movimientos | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P005-1 | Enfermería/Técnico del área aplica el kit y registra la ficha; Farmacia consulta la copia recibida; Jefatura compara historial | Por registrar | — | — | Usuario confirma CRUD de plantillas; falta copia/historia de ficha | Conversación | Parcial |
| P005-2 | Enfermería/Técnico solicita; Farmacia genera un cambio controlado de disponibilidad en otro dispositivo; Farmacia debe ver los faltantes confirmados en la ficha; Jefatura consulta auditoría | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P005-3 | Enfermería/Técnico del área A; una cuenta autorizada prepara un kit inactivo/de otra área de prueba; Farmacia/Jefatura consultan únicamente la ficha histórica que corresponda | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P014-1 | Almacén realiza el reconocimiento; Almacén revisa el resultado; no hay pedido a Farmacia en esta operación | Por registrar | — | — | Usuario confirma reconocimiento y llenado; faltan comprobaciones restantes | Conversación | Parcial |
| P014-2 | Almacén intenta reconocer; Administración prepara configuración de error solo si procede; Almacén recibe el aviso de error | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P015-1 | Almacén revisa, corrige y guarda el reconocimiento; Almacén vuelve a consultar el ingreso; Farmacia/Jefatura pueden consultar existencias | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P015-2 | Almacén guarda el borrador de reconocimiento; Almacén comprueba el registro; Jefatura consulta ingreso e historial | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P015-3 | Administración configura claves; Almacén usa IA desde otro dispositivo; Farmacia/Enfermería/Jefatura prueban denegación; Almacén ve el reconocimiento; los roles no autorizados reciben denegación | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P006-1 | Enfermería/Técnico crea el pedido; Farmacia abre su listado y actualiza; Farmacia lee la solicitud del área; Jefatura puede consultarla | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P006-2 | Enfermería de áreas A/B, Farmacia, Jefatura y Almacén en sesiones separadas; Cada rol consulta su alcance permitido; Almacén no debe obtener lectura clínica global | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P007-1 | Enfermería/Técnico del área, Farmacia y Jefatura abren la misma ficha; Los tres comparan datos; Jefatura solo consulta | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P007-2 | Farmacia consulta el detalle; Jefatura coteja el historial; Enfermería consulta su ficha dentro de su área | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P008-1 | Farmacia prepara, marca listo y guarda nuevamente si la UI lo permite; Enfermería del área ve el estado; Jefatura compara cabecera e historial | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P008-2 | Dos operadores con cuentas Farmacia autorizadas, en dispositivos/sesiones separados; Enfermería/Jefatura consultan resultado e historial | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P008-3 | Enfermería/Técnico envía solicitud; luego Farmacia marca listo; Farmacia recibe aviso de solicitud; Enfermería del área recibe aviso de recojo | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P009-1 | Farmacia edita cantidades de preparación; Enfermería puede consultar el pedido; Jefatura verifica resultado | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P009-2 | Enfermería solicita 5; Farmacia prepara 3 y justifica; Enfermería revisa lo preparado; Jefatura compara cantidades y motivo | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P010-1 | Farmacia deja listo; Enfermería/Técnico receptor autorizado confirma recepción; Jefatura consulta consumo y lotes; Farmacia comprueba existencias | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P010-2 | Receptores autorizados de Enfermería en sesiones separadas; Farmacia prepara previamente ambas fichas; Farmacia/Jefatura concilian existencias y movimientos | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P010-3 | Enfermería de otra área intenta confirmar; Administración prepara la desactivación de un receptor de prueba; Receptor válido del área confirma después; Farmacia/Jefatura verifican ausencia de descuentos por intentos rechazados | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P010-4 | Cuenta autorizada de Almacén/Administración cambia un precio de catálogo de prueba; Jefatura compara; Farmacia/área consultan la ficha histórica | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P011-1 | Enfermería solicitante cancela; Farmacia rechaza una segunda ficha; Farmacia y el área consultan el resultado; Jefatura revisa actores y motivos | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P011-2 | Farmacia toma el pedido; Enfermería solicitante intenta cancelarlo después; Farmacia/Jefatura revisan acciones e historial | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P011-3 | Enfermería/área, Farmacia y Administración comprueban el cierre; petición negativa controlada por terminal; Jefatura verifica conservación de consumo e historial | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P025-1 | Almacén registra y despacha; Farmacia recibe y prepara; Enfermería confirma recepción del pedido clínico; Jefatura sigue el mismo producto/lote en Kardex | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P025-2 | Farmacia/Almacén realizan devolución física o corrección autorizada de prueba; Jefatura consulta Kardex; Jefatura concilia motivos e importes históricos | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P025-3 | Farmacia o Almacén registra un movimiento legítimo desde otro dispositivo; Jefatura actualiza Kardex; Jefatura compara resumen e historial | Por registrar | — | — | Pendiente | — | Sin ejecutar |
| P026-1 | Propuesta pendiente de acordar: Farmacia exporta; Jefatura valida el documento; Jefatura compara el PDF con la ficha guardada | Por registrar | — | — | Pendiente de desarrollo/condiciones de su sección | — | Sin ejecutar |
| P026-2 | Rol exportador por confirmar al implementar; propuesta: Farmacia; Usuario autorizado abre/recibe el archivo; Jefatura valida | Por registrar | — | — | Pendiente de desarrollo/condiciones de su sección | — | Sin ejecutar |
| P027-1 | Administración prepara integración; identidad Google autorizada concede acceso; rol de envío aún por acordar; Jefatura o destinatario autorizado comprueba carpeta y archivo | Por registrar | — | — | Pendiente de desarrollo/condiciones de su sección | — | Sin ejecutar |
| P027-2 | Rol de envío por acordar; propuesta: Farmacia usando PDF generado; servidor ejecuta con credencial autorizada; Jefatura/destinatario con permiso verifica enlace y versión | Por registrar | — | — | Pendiente de desarrollo/condiciones de su sección | — | Sin ejecutar |
| P028-1 | Jefatura consulta indicadores; Farmacia/Almacén/Enfermería aportan registros controlados ya conocidos; Jefatura concilia | Por registrar | — | — | Pendiente de desarrollo/condiciones de su sección | — | Sin ejecutar |
| P028-2 | Jefatura filtra y actualiza; Farmacia/Almacén/Enfermería operan en otra sesión según su permiso; Jefatura sigue el origen del indicador, sin editar movimientos | Por registrar | — | — | Pendiente de desarrollo/condiciones de su sección | — | Sin ejecutar |
| HU-003 / regresiones de los tres defectos | Verificación técnica histórica; no aceptación manual de un rol operativo | Ver guía HU-003 | 22/11/2026 | Migración receptor/médico 22/11 + código actualizado | 14 pruebas Dart, SQL local y verificación remota sin cambios de datos | Guía HU-003 del 22/11 | Aprobado en código/contrato; manual pendiente |

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
