# Acuerdos de kits por área — 26/10/2026

## Actualización local posterior — implementación de plantillas

Se implementaron permisos por área y el checkbox «Puede gestionar kits» solo para cargo Técnica/Enfermera con rol Enfermería / Técnico; selección del área de trabajo, lectura para Jefatura/Farmacia, duplicación con nombre nuevo y disponibilidad real/laboratorio. Se retiraron fallbacks, se corrigió el selector histórico y se sustituyeron las RPC de kits con control de sesión/rol/pertenencia y códigos canónicos. Esta actualización sustituye los hallazgos previos correspondientes que siguen más abajo como antecedente.

La migración actual es `docs/supabase/migracion_kits_por_area_2026_10_26.sql`; está incluida al final del setup. **No se ejecutó en Supabase en esta entrega.** No volver a aplicar la migración de kits del 22/10 después de ella. Guía y revisión manual: `docs/supabase/GUIA_KITS_POR_AREA_2026_10_26.md`.

El código de HU-017/HU-018/HU-019 queda preparado para migración y aceptación manual. No se ejecutaron suites, emulador ni capturas. El permiso se consulta de nuevo desde el servidor, y las áreas se vinculan por UUID de `profile_areas`. El área de trabajo se elige al entrar en Kits; el permiso no representa otro cargo.

HU-003 a HU-011 siguen pendientes: pedir el kit, seguro/médico en la ficha, notificaciones, confirmación de incompleto, reserva/preparación y consumo final no pertenecen a este CRUD de plantillas. No se declara cerrado el Sprint 5 por el análisis de Dart ni por esta documentación.

---

Fuente: decisiones del usuario en la conversación. Documento de requisitos;
no certifica implementación, despliegue ni aceptación funcional de kits.
Actualizado con las respuestas y datos del pedido confirmados el 26/10/2026.

## LEER PRIMERO — continuidad del Sprint 5

Este es el punto de entrada para el siguiente agente. Contiene los acuerdos más
recientes de kits y el estado técnico del Sprint 5 al cierre de esta conversación.
Las indicaciones directas del usuario prevalecen sobre las descripciones antiguas
de roles/áreas y sobre guías que afirman que los kits ya están completos.

Repositorio local:

```text
C:\Users\ASUS\Desktop\UPT\X\MOVILES\UNIDAD II\Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas
```

- Rama: `Sprint-05`.
- Remoto: `https://github.com/David-Anampa/Soluciones_Moviles_II_SITRA-Luz_Anampa_Salas.git`.
- Aplicación Flutter: `app/`.
- Supabase: proyecto `nedeqnvpkalrchswrapr`. No guardar contraseñas/tokens en
  documentación, código, commits o salidas de herramientas.
- Documentos anteriores de `docs/contexto/Para actualizarse/` sirven como
  antecedente, pero sus estados de HU-023/HU-024/HU-029/HU-030 están desactualizados
  frente a los cambios del 25–26/10 descritos aquí.

### Estado por historia del Sprint 5

La numeración HU de esta tabla corresponde al plan de continuidad de contexto.
El CSV antiguo de Product Backlog usa numeración US diferente; no equipararlas
automáticamente ni renumerar historias sin revisar el plan.

| Historia | Estado real | Pendiente para cierre |
|---|---|---|
| HU-017: listar, buscar y activar/desactivar kits | Hay código previo, pero requiere correcciones y adaptación a kits propios de cada área. No cerrada. | Gestión/lectura por área, disponibilidad real, permisos correctos, historial, diseño y despliegue revisado. |
| HU-018: crear kit | Hay formulario y RPC previos; no cubren todos los acuerdos recientes. No cerrada. | Composición con laboratorio/cantidad/stock, kit personalizado, duplicación con nombre, guardado atómico seguro y permisos por área. |
| HU-019: editar kit | Hay formulario reutilizado y edición previa. No cerrada. | Corregir fallbacks, áreas deshabilitadas y permisos; preservar solicitudes históricas, separar variantes de edición original. |
| HU-023: stock de Farmacia y Almacén | Implementada y migrada: disponibilidad por ubicación y En tránsito. | Validación funcional por el usuario y aceptación; no rehacerla por referencias antiguas que la marcan parcial. |
| HU-024: entrada de stock | Corregida e instalada: ingreso atómico, duplicados bloqueados, correcciones de cantidad justificadas e historial. | Validación funcional por el usuario. Lotes históricos sin cantidad original inequívoca requieren conciliación; no inventar esa cantidad. |
| HU-029: solicitud Farmacia → Almacén, ajuste arrastrado del sprint | Implementada y migrada: creación atómica, reintentos y auditoría. | Validación funcional/aceptación del usuario; conservar las reglas existentes. |
| HU-030: atención y recepción de esas solicitudes, validación integrada | Implementada y migrada: despacho, tránsito, recepción, devolución física, reportes de diferencias y solución. | Validación funcional/aceptación del usuario; no confundirla con los pedidos de kits del área. |

No declarar cerrado el sprint por tener código o `flutter analyze` limpio: las
tres historias de kits siguen incompletas y la aceptación funcional corresponde
al usuario.

### Trabajo ya instalado que debe conservarse

1. **Abastecimiento atómico:** cabecera, ítems y auditoría juntos; reintentos sin
   duplicación. Almacén puede enviar por solicitud o por iniciativa propia con
   motivo, en cantidades parciales o totales elegidas explícitamente.
2. **Ubicaciones:** despachar descuenta Almacén y deja En tránsito. Farmacia solo
   dispone del stock después de su recepción física. No acreditar stock remoto
   como si ya estuviera en Farmacia.
3. **Diferencias de recepción:** Farmacia reporta sin mover stock, cancela con
   motivo o confirma propuestas. Almacén rechaza/soluciona con justificación y
   preconfirmación; cambiar el conteo de Farmacia requiere confirmación de quien
   reportó. Se conservan historial y auditoría. Una pérdida no vuelve a Almacén.
4. **HU-024:** ingreso de lote, stock y auditoría en una transacción; también
   medicamento nuevo + primer lote. Correcciones conservan el original, aplican
   solo el delta y bloquean descuentos sin existencias suficientes en la ubicación
   verificada. No alteran despachos, recepciones ni consumo pasados.
5. **Consulta de Jefatura:** tiene accesos de lectura a diferencias e ingresos.
   Esto no equivale al dashboard completo de HU-028 ni al Kardex de HU-025.

Guías vigentes para leer después de este archivo:

- `docs/supabase/GUIA_HU024_INGRESOS_ATOMICOS_2026_10_26.md`.
- `docs/supabase/GUIA_DIFERENCIAS_ABASTECIMIENTO_2026_10_26.md`.
- `docs/supabase/GUIA_STOCK_TRANSITO_Y_ENVIOS_ALMACEN_2026_10_25.md`.
- `docs/supabase/GUIA_HU029_HU030_ABASTECIMIENTO_ATOMICO_2026_10_25.md`
  como antecedente, con la actualización posterior de tránsito/diferencias.

Migraciones aplicadas en remoto y copiadas al setup, en su orden relativo:

```text
migracion_hu029_hu030_abastecimiento_atomico_2026_10_25.sql
migracion_stock_transito_y_envios_almacen_2026_10_25.sql
migracion_diferencias_abastecimiento_2026_10_26.sql
migracion_hu024_ingresos_atomicos_2026_10_26.sql
```

Las últimas instalaciones compararon huellas de los registros antes/después y
preservaron los datos existentes. HU-024 también comprobó que no cambió ninguna
otra función pública. No se crearon movimientos de prueba en Supabase remoto.
No ejecutar `setup_sitra_luz.sql` completo sobre la base existente ni volver a
instalar una migración vieja que reemplace funciones actuales por versiones previas.

### Hallazgos de kits aún presentes en el código

Revisión estática confirmada el 26/10; no afirmar que ya se corrigieron:

- `kits_repository.dart` conserva `_guardarKitFallback`, que escribe cabecera e
  ítems por separado. Estado/eliminación también tienen alternativas de escritura
  directa cuando falta la RPC. Retirarlas: exigir una migración disponible y
  devolver un error claro, sin guardados parciales ni auditoría omitida.
- La RPC `administrar_kit_hu018` hace `IF v_rol NOT IN (...)` sin rechazar NULL.
  Debe comprobar identidad/perfil activo y denegar explícitamente rol nulo.
- Esa escritura permite Jefatura/Farmacia mientras la pantalla está en
  `/admin/kits`. Hay que alinear servidor, RLS, rutas y controles con el modelo
  de gestión por área confirmado por el usuario, sin conceder permisos globales
  por inferencia. Jefatura mantiene consulta.
- `listar_kits_hu017` y políticas anteriores filtran Enfermería mediante
  `profiles.areas_asignadas`. Esa suposición no describe el nuevo acuerdo.
  Definir primero la procedencia/pertenencia del usuario; no borrar asignaciones
  históricas de otros módulos como atajo.
- La escritura convierte `area_destino` a mayúsculas. Los alias creados por
  HU-012 pueden contener UUID en minúsculas: resolver el área y conservar su
  código canónico; usar su UUID estable donde corresponda.
- Al editar, el formulario precarga el área anterior pero carga solo áreas
  activas. Debe poder representar una asignación histórica sin aserciones y
  distinguir conservarla de asignar un área deshabilitada a un kit nuevo.
- Revisar las diferencias entre políticas/helper del setup y la migración de
  kits; el fallback de lectura presupone una relación FK que no debe darse por
  existente sin verificar el esquema real.
- La selección actual requiere extenderse para nombre completo, laboratorio
  secundario y disponibilidad real de ambas ubicaciones, además de variantes.
- Unificar colores y tipografía con el tema; permanecen estilos aislados como
  `Colors.teal`. No dar por válida la guía anterior que afirma cobertura del 100%.
- **Despliegue de kits no verificado en esta continuación.** La existencia del
  archivo de migración o de una guía no prueba que esté instalado en Supabase.

### Archivos que debe revisar el siguiente agente

```text
app/lib/features/kits/data/repositories/kits_repository.dart
app/lib/features/kits/domain/kit_borrador.dart
app/lib/features/kits/domain/kit_validadores.dart
app/lib/features/kits/domain/entities/kit_entity.dart
app/lib/features/kits/domain/entities/kit_item_entity.dart
app/lib/features/kits/presentation/views/kits_admin_view.dart
app/lib/features/kits/presentation/views/kit_formulario_view.dart
app/lib/features/kits/presentation/widgets/kit_card.dart
app/lib/features/kits/presentation/widgets/selector_medicamento_dialog.dart
app/lib/core/routes/app_router.dart
app/lib/core/services/notification_service.dart
docs/supabase/migracion_hu017_hu018_hu019_kits_2026_10_22.sql
docs/supabase/GUIA_HU017_HU018_HU019_KITS.md
docs/supabase/setup_sitra_luz.sql
```

Para reutilizar consulta real y estilo:

```text
app/lib/features/almacen/data/repositories/stock_ubicaciones_repository.dart
app/lib/features/almacen/domain/entities/stock_ubicacion_entity.dart
app/lib/features/almacen/presentation/widgets/stock_presentacion.dart
```

### Diferenciar plantillas de pedidos: dependencias fuera del núcleo del sprint

Los siguientes requisitos están confirmados por el usuario, pero no están
implementados por haberlos escrito aquí. Deben planificarse junto a las historias
de fichas/pedidos Área → Farmacia; no ocultar este alcance dentro del CRUD de kits:

| Historias del plan de contexto | Integración requerida |
|---|---|
| HU-003/HU-004/HU-005 | Registrar pedido/ficha, aplicar kit o variante, composición, procedencia, solicitante, cobertura y médico. Verificar el alcance de General/Neonatología existente antes de agregar campos clínicos. |
| HU-006/HU-007 | Bandeja, detalle con reloj/fecha/hora, áreas, responsables e historial, incluidas confirmaciones de kit completo/incompleto. |
| HU-008/HU-009/HU-010 | Recepción de solicitud por Farmacia, preparación, cantidades reales, listo para recojo y confirmación final del área con consumo sin doble descuento. |
| HU-011 | Cancelación/rechazo justificados y permisos según el estado, conservando auditoría. |

Hay tablas base `dispensaciones`/`dispensacion_items`; su existencia no acredita
todo este flujo. En `notification_service.dart`, `enablePushNotifications=false`:
las notificaciones push están desactivadas. La bandeja/aviso persistente a Farmacia
y el envío push deben distinguirse y comprobarse; no anunciar notificaciones
operativas solo por tener el servicio FCM en el proyecto.

HU-025 (Kardex), HU-028 (dashboard integral de Jefatura), HU-026 (PDF) y HU-027
(Drive) son alcance posterior según el plan. Mantener la auditoría de lo que se
implemente, sin declarar completadas esas pantallas/documentos.

### Orden recomendado para continuar

1. Leer todas las reglas confirmadas de este documento y resolver únicamente las
   dos precisiones finales: identificación/permisos del área y reserva de stock.
2. Revisar el estado real de las RPC/políticas de kits en Supabase sin escribir
   datos. No migrar con los permisos/áreas antiguos por defecto.
3. Corregir HU-017/HU-018/HU-019 en servidor y cliente: escritura atómica sin
   fallback, seguridad, códigos de área, historial, personalización/duplicación,
   consulta de stock y diseño. Crear migración separada y sincronizar el setup.
4. Registrar por separado la integración de pedidos/estados/notificaciones con
   HU-003 a HU-011 y acordar su ejecución; no afirmar que el CRUD la entrega.
5. Ejecutar comprobaciones mínimas y `flutter analyze`; la validación funcional
   queda a cargo del usuario. Hacer commits breves y push de lo solicitado.

### Condiciones de trabajo y Git

- No ejecutar muchas pruebas ni suites funcionales: indicación más reciente del
  usuario. No añadir pruebas dentro del proyecto. Si se necesita un script de
  comprobación mínimo, usar el workspace externo de Codex, sin datos remotos de
  demostración. No repetir los números de pruebas históricas como validación de
  cambios futuros.
- No iniciar ni monitorizar el emulador Pixel 8 por iniciativa propia; el usuario
  pidió dejar el proceso previo en segundo plano. No afirmar validación visual
  manual en Android por capturas hechas con datos sintéticos.
- Estado local ajeno a este trabajo: `app/android/gradle.properties` modificado
  y carpeta `docs/contexto/Para actualizarse/` sin seguimiento. No incluirlos,
  revertirlos ni eliminarlos como parte de un commit de kits/documentación.
- Commits relevantes ya subidos antes de este cierre: `f9dc9f6` (tránsito),
  `c03a0dc` (diferencias), `7063e30` (interfaz), `bd501b1` (tabla/tipografía),
  `ac620a6` (despliegue), `075a7f9` (HU-024), `503ec66` (guía HU-024),
  `e6953e2` (primeros acuerdos) y `338ab38` (respuestas de kits).
- Este archivo no autoriza a marcar historias como aceptadas ni a ampliar
  permisos basándose en una interpretación. Consultar las precisiones pendientes
  antes de decisiones que dependan de ellas.

## Reglas confirmadas

1. Un kit es un paquete configurable de varios medicamentos y sus cantidades.
   No se añaden campos clínicos o administrativos a la composición sin necesidad.
2. Cada área tiene sus propios kits, que arma según sus necesidades. No se
   presupone una plantilla compartida automáticamente entre todas las áreas.
   **No se modela Enfermería como propietaria de áreas asignadas.** Existen
   distintas áreas, cada una con su propia gestión de kits. El rol de acceso y
   el área de procedencia son conceptos separados. Esta instrucción sustituye
   la suposición anterior de «kits de las áreas asignadas a Enfermería».
3. Al crear/configurar el kit se consulta stock real de Farmacia y Almacén para
   conocer disponibilidad. La existencia en Almacén se distingue de la de
   Farmacia; no implica traslado ni disponibilidad inmediata en Farmacia.
4. Cada componente muestra el nombre completo del medicamento, su laboratorio
   en texto secundario más pequeño y la cantidad configurada. Los nombres
   completos deben poder leerse en móvil sin cortes que oculten información.
5. Se pueden crear, listar, buscar por nombre del kit y modificar sus componentes.
   Se puede activar/desactivar cada kit. El usuario lo describe como CRUD; no se
   ha autorizado borrar registros con historial o solicitudes asociadas.
6. Si falta un componente, se resalta con sombreado/negrita y un mensaje u
   observación que indique exactamente qué medicamento no está disponible.
   No se reemplazan existencias reales por datos de demostración.
   **Se permite solicitar y entregar un kit incompleto**, avisando expresamente
   a Farmacia cuáles son los medicamentos faltantes y qué debe pedir/reponer.
7. El área selecciona su kit y envía una solicitud. Farmacia recibe una
   notificación y puede consultar el detalle de medicamentos/cantidades pedidos.
8. Farmacia prepara físicamente el paquete. Primero marca **Pedido recibido**
   (recepción de la solicitud por Farmacia), luego **Pedido listo para recojo**.
9. Cuando el área recibe físicamente el paquete, marca **Pedido recibido**
   (confirmación del área). El registro queda cerrado, sin más acciones de
   cambio. Se conserva para consulta e historial.
10. Se deben distinguir las dos confirmaciones en los datos y en el historial:
    recibir una solicitud en Farmacia no equivale a recibir el paquete en el área.

## Datos al solicitar y consultar el pedido

- **Fecha y hora de creación:** registradas por el sistema y visibles en el
  detalle con icono de reloj. No sustituirlas por la hora de consulta del pedido.
- **Área de procedencia:** visible con icono representativo y nombre del área.
- **Solicitante:** nombre del técnico/usuario del área que hizo el pedido,
  obtenido de su sesión. Conservar su identidad en el registro y auditoría.
- **Seguro o financiamiento:** al hacer el pedido se indica si tiene cobertura
  y se selecciona el tipo de seguro/financiamiento correspondiente. Sin cobertura
  debe quedar identificado expresamente; no inventar una aseguradora.
  Usar los catálogos existentes y conservar la selección histórica del pedido.
- **Médico a cargo:** selección entre los médicos ya registrados, sin exigirle
  una cuenta de usuario del sistema. Mostrarlo también en el detalle.
- **Composición solicitada y disponibilidad:** medicamentos con nombre completo,
  laboratorio secundario, cantidades y los avisos de faltantes correspondientes.

Los campos de seguro y médico pertenecen al pedido; no se añaden a cada
componente de la plantilla del kit. Mostrar la información con iconos y espacio,
conservando la tipografía/tamaños de la aplicación.

## Confirmación de kit completo o incompleto

Antes de enviar el pedido debe abrirse un modal de confirmación que indique
claramente si el kit está **completo o incompleto**, de acuerdo con el stock real
disponible en Farmacia. Mostrar lo solicitado, disponible y faltante por producto.
Si hay unidades en Almacén, distinguirlas y avisar que Farmacia necesita gestionar
su abastecimiento; no contarlas como si ya estuvieran en Farmacia.

El usuario puede volver a corregir o confirmar el envío, incluso incompleto.
Guardar en el historial y en auditoría la confirmación, su condición de
completo/incompleto, medicamentos/cantidades faltantes, fecha/hora y responsable.
El aviso de lo que falta debe llegar a Farmacia junto con la solicitud, no quedar
únicamente como una alerta temporal en el teléfono del solicitante.

La disponibilidad se vuelve a comprobar en el servidor al enviar/preparar.
Un cambio posterior de stock no debe borrar ni reescribir la confirmación
histórica. La entrega debe distinguir cantidades solicitadas de las realmente
entregadas; no marcar como entregadas unidades faltantes.

## Consumo, cancelación y rechazo

- El kit entregado y recibido por el área se registra como **consumo operativo**;
  no queda como un inventario independiente del área ni vuelve normalmente a
  Farmacia. Esto no acredita por sí solo uso en un paciente o pago/cobro.
- El consumo considera solo las cantidades efectivamente entregadas, nunca las
  faltantes. No duplicar el descuento entre preparación, entrega y confirmación.
- El área puede cancelar antes de que Farmacia tome el pedido, con comentario
  o justificación obligatoria y registro de responsable/fecha.
- Farmacia puede rechazar la solicitud con comentario/justificación obligatoria.
  Un rechazo y una cancelación son eventos distintos en historial y auditoría.
- Después de la recepción física confirmada por el área, el pedido queda cerrado,
  consultable y sin más acciones de modificación.

## Variantes, duplicación y kits personalizados

- Desde un kit existente se puede **duplicar para crear una variante**.
- La duplicación solicita un **nombre para el nuevo kit**; permite modificar
  medicamentos/cantidades y se guarda como otro kit en la lista del área.
- No modificar la plantilla original al cambiar la copia. Mantener la identidad
  propia y el área del nuevo kit; copiar la composición no significa copiar stock.
- También se puede crear un **kit personalizado**, asignarle nombre y composición
  y guardarlo en la lista de kits del área. No queda como una selección temporal
  que desaparece al terminar el pedido.
- Las variantes y personalizados conservan búsqueda por nombre, edición y
  activación/desactivación. Las solicitudes enviadas mantienen su propia copia
  histórica aunque después se edite la plantilla, variante o personalizado.

## Reglas transversales que se conservan

- Los ingresos externos pertenecen a Almacén. Farmacia se abastece mediante
  el traslado/recepción implementado; un kit no puede tomar stock de Almacén
  directamente para simular existencias disponibles en Farmacia.
- Mantener identidad del solicitante desde la sesión, responsables, fechas,
  cantidades y justificaciones para auditoría de Jefatura.
- La solicitud debe conservar una copia de su composición al enviarse. Editar
  una plantilla posteriormente no reescribe solicitudes ni entregas anteriores.
- No duplicar stock al representar el paquete y sus componentes. El destino
  confirmado es consumo operativo; aún debe concretarse el mecanismo de reserva
  durante la preparación para evitar que dos pedidos usen las mismas unidades.
- Interfaz roja `#C62828`, blanco/gris/pastel, iconos Material y espacio entre
  campos. Mantener tipografía/tamaños del tema; laboratorio en estilo secundario.
- Commits breves en `Sprint-05`. Para desarrollo, comprobaciones mínimas y
  `flutter analyze`; la validación funcional la realizará el usuario.

## Precisiones para la implementación

Las cinco respuestas del usuario ya están incorporadas como reglas confirmadas.
Antes de cambiar permisos o movimientos de stock, concretar:

1. Cómo se identifica el área de procedencia del técnico/usuario y quién puede
   gestionar los kits de esa área. No reutilizar automáticamente la regla antigua
   de áreas asignadas a Enfermería ni conceder edición de kits de otras áreas.
2. En qué transición se reservan los componentes durante la preparación y cómo
   se libera una reserva si se rechaza/cancela una operación permitida. El consumo
   final no debe duplicarse ni incluir unidades no entregadas.

Estas precisiones no vuelven pendientes las decisiones ya confirmadas sobre
entregas incompletas, consumo, comentarios ni variantes/personalizados.

## Alcance respecto al plan

HU-017/HU-018/HU-019 cubren administración de las plantillas. La solicitud,
notificación, preparación y recepción Área → Farmacia se integran con las HU
de fichas/pedidos correspondientes; no quedan implementadas por documentarlas.
No confundir este recorrido con HU-029/HU-030 (Farmacia → Almacén).
