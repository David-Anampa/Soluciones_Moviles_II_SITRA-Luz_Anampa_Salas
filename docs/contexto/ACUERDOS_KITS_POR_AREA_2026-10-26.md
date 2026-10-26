# Acuerdos de kits por área — 26/10/2026

Fuente: decisiones del usuario en la conversación. Documento de requisitos;
no certifica implementación, despliegue ni aceptación funcional de kits.

## Reglas confirmadas

1. Un kit es un paquete configurable de varios medicamentos y sus cantidades.
   No se añaden campos clínicos o administrativos a la composición sin necesidad.
2. Cada área tiene sus propios kits, que arma según sus necesidades. No se
   presupone una plantilla compartida automáticamente entre todas las áreas.
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
7. El área selecciona su kit y envía una solicitud. Farmacia recibe una
   notificación y puede consultar el detalle de medicamentos/cantidades pedidos.
8. Farmacia prepara físicamente el paquete. Primero marca **Pedido recibido**
   (recepción de la solicitud por Farmacia), luego **Pedido listo para recojo**.
9. Cuando el área recibe físicamente el paquete, marca **Pedido recibido**
   (confirmación del área). El registro queda cerrado, sin más acciones de
   cambio. Se conserva para consulta e historial.
10. Se deben distinguir las dos confirmaciones en los datos y en el historial:
    recibir una solicitud en Farmacia no equivale a recibir el paquete en el área.

## Reglas transversales que se conservan

- Los ingresos externos pertenecen a Almacén. Farmacia se abastece mediante
  el traslado/recepción implementado; un kit no puede tomar stock de Almacén
  directamente para simular existencias disponibles en Farmacia.
- Mantener identidad del solicitante desde la sesión, responsables, fechas,
  cantidades y justificaciones para auditoría de Jefatura.
- La solicitud debe conservar una copia de su composición al enviarse. Editar
  una plantilla posteriormente no reescribe solicitudes ni entregas anteriores.
- No duplicar stock al representar el paquete y sus componentes. El momento
  de reservar/descontar y su destino contable deben concretarse antes de migrar.
- Interfaz roja `#C62828`, blanco/gris/pastel, iconos Material y espacio entre
  campos. Mantener tipografía/tamaños del tema; laboratorio en estilo secundario.
- Commits breves en `Sprint-05`. Para desarrollo, comprobaciones mínimas y
  `flutter analyze`; la validación funcional la realizará el usuario.

## Decisiones pendientes de respuesta

1. **Permisos de gestión por área:** confirmar si Enfermería podrá crear/editar/
   activar/desactivar los kits de sus áreas asignadas, con Administración como
   supervisión global. Esto cambia la regla anterior de gestión solo por Admin;
   no aplicar ese permiso nuevo hasta confirmarlo.
2. **Faltantes:** definir si se permite enviar la solicitud y dejarla esperando
   reposición, o si se permite entregar un kit parcial. El resaltado está
   confirmado; no equivale por sí solo a autorizar entrega incompleta.
3. **Destino del stock:** definir si el paquete recibido pasa a existencias del
   área o se registra como consumo operativo. No confundir entrega con uso en
   paciente. Concretar también cuándo se reserva/descuenta en Farmacia.
4. **Cancelación y rechazo:** confirmar si el área puede cancelar antes de que
   Farmacia tome la solicitud y si Farmacia puede rechazar con justificación.
5. **Edición al solicitar:** el CRUD de plantilla está confirmado. Precisar si
   también se puede ajustar la composición para un pedido específico sin
   modificar la plantilla original.

## Alcance respecto al plan

HU-017/HU-018/HU-019 cubren administración de las plantillas. La solicitud,
notificación, preparación y recepción Área → Farmacia se integran con las HU
de fichas/pedidos correspondientes; no quedan implementadas por documentarlas.
No confundir este recorrido con HU-029/HU-030 (Farmacia → Almacén).
