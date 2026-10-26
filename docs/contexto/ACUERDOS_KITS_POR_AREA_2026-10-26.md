# Acuerdos de kits por área — 26/10/2026

Fuente: decisiones del usuario en la conversación. Documento de requisitos;
no certifica implementación, despliegue ni aceptación funcional de kits.
Actualizado con las respuestas y datos del pedido confirmados el 26/10/2026.

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
