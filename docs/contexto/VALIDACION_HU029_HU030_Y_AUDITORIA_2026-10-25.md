# HU-029/HU-030: pruebas por terminal y auditoría

Fecha: 25 de octubre de 2026. Rama: Sprint-05.

**Actualización posterior del mismo día:** los pendientes técnicos de creación
atómica, stock y reintentos se resolvieron y desplegaron. Se aprobaron 30 pruebas
SQL reales y 30 pruebas Flutter fuera del repositorio. El estado final y sus
límites están en `docs/supabase/GUIA_HU029_HU030_ABASTECIMIENTO_ATOMICO_2026_10_25.md`.
El resto de este documento conserva el diagnóstico de la revisión previa.

## Resultado y alcance

Por solicitud del usuario se ejecutaron pruebas automatizadas por terminal.
La primera ejecución de `pedidos_flow_test.dart` pasó 9 casos y falló uno:
el localizador `widgetWithText(FilledButton, ...)` no encontraba la subclase
que utiliza `FilledButton.icon`. No se observó un fallo del flujo en ese caso.
Se corrigió el localizador para distinguir el botón de confirmación del
ChoiceChip con la misma etiqueta y desplazarlo a la vista antes de pulsarlo.

Se añadieron pruebas del datasource con un servidor HTTP local, sesión ficticia
en memoria y respuestas simuladas. No utilizan credenciales ni Supabase remoto.

Ejecución final:

```text
flutter test test/pedidos_flow_test.dart test/pedidos_datasource_test.dart --reporter expanded
24 pruebas aprobadas: 10 de modelo/interfaz y 14 de contrato del datasource.

flutter analyze
No issues found!
```

## Casos cubiertos

- Cancelación pendiente con motivo; rechazo del servidor mostrado sin cerrar el diálogo.
- Diferencia entre cancelar y rechazar; restricción de cancelación en preparación.
- Despacho desde preparación, modalidad elegida y rechazo de despacho vacío.
- Recepción conforme; devolución de 40 de 50; cantidades y motivo requeridos.
- Conservación de la cantidad despachada original en el modelo de recepción.
- Separación de acciones visibles para Almacén y Farmacia.
- HU-029 exige sesión y toma el solicitante de esa sesión.
- HU-029 envía cabecera, ítems y evento CREACION_PEDIDO; comunica fallos en cada paso.
- HU-030 envía TOMAR, CANCELAR, RECHAZAR, DESPACHAR y RECIBIR mediante una sola RPC.
- Devolución con cantidades aceptadas y motivo en la misma llamada de recepción.
- Errores de permisos o RPC ausente no provocan escrituras directas alternativas.
- Los métodos antiguos no permiten marcar listo sin un despacho real.

## Lo que estas pruebas no demuestran

Los tests de interfaz sustituyen el ViewModel. Los de datasource simulan el
servidor HTTP; no ejecutan PostgreSQL ni sus políticas. Por tanto, no prueban
descuento real de stock, elección FEFO en servidor, rollback SQL, concurrencia,
recepción duplicada ni reintentos sobre una base de integración.

Docker está instalado pero su motor Linux no estaba disponible. No se iniciaron
servicios adicionales ni se crearon datos de prueba en Supabase remoto.
No se ejecutaron transiciones sobre pedidos reales, migraciones ni escrituras
de stock o auditoría remotos durante esta validación.

## Verificación remota de solo lectura

Se consultaron la definición instalada de `procesar_pedido_abastecimiento`,
las políticas de auditoría, sus columnas y los privilegios efectivos declarados.

- Existe la RPC con SECURITY DEFINER, controles de identidad/perfil activo,
  control de Administrador y bloqueos FOR UPDATE en su definición.
- Contiene los eventos TOMA_PEDIDO, CANCELACION_PEDIDO, RECHAZO_PEDIDO,
  TRANSFERENCIA_FARMACIA, DESPACHO_PEDIDO, DEVOLUCION_EN_RECEPCION y RECEPCION_PEDIDO.
- La política SELECT permite a JEFATURA_FARMACIA consultar todos los eventos
  cuando su perfil está activo; no impone filtro por área para ese rol.
- Auditoría tiene RLS habilitado. authenticated dispone de SELECT e INSERT,
  pero no UPDATE ni DELETE. La política INSERT restringe actor y roles operativos;
  Jefatura queda fuera de esa política de creación.
- Existen campos de actor, fecha, medicamento, lote, origen/destino, cantidad,
  entidad, estado anterior/nuevo y detalles adicionales.

Estas comprobaciones de definición y privilegios no equivalen a haber ejecutado
el flujo con cuentas reales ni certifican que todos los módulos generen eventos.

## Hallazgos y estado de las HU

**HU-029: implementación con ajuste pendiente.** La creación continúa con tres
peticiones: cabecera, ítems y auditoría. Un fallo en las últimas puede dejar
datos anteriores persistidos. Mostrar el error no deshace esas peticiones.
Sigue pendiente una RPC que guarde todo o nada y prevenga duplicados/reintentos.
No existe una función de creación de pedidos entre las RPC de pedidos localizadas
en la consulta de metadatos remotos.

**HU-030: flujo implementado, pruebas de cliente aprobadas.** La RPC contiene
las reglas de transición, stock y auditoría, pero sigue pendiente la validación
SQL de integridad, concurrencia y reintentos en un entorno aislado.
No declarar la HU completamente aceptada solo por estos 24 tests.

## Requisito confirmado: auditoría integral para Jefatura

El usuario confirmó que desea auditoría de todas las operaciones para la jefa
de Farmacia. Debe poder consultar quién hizo qué, cuándo, sobre qué registro,
desde/hacia qué área, cantidades y lotes, motivo y cambios anteriores/nuevos.
La consulta será de solo lectura; no permitirá editar ni borrar auditorías.

La cobertura deberá revisar solicitudes y transiciones, ingresos, traslados,
devoluciones, catálogo, kits, administración de usuarios/áreas/financiamientos y,
cuando existan esos flujos, fichas, entregas y documentos. No implica que todo
esté implementado hoy. Los módulos futuros deben incorporar sus propios eventos.

Se confirmó que el dashboard actual de Jefatura sigue siendo un prototipo:
la opción de auditoría muestra un aviso, no una consulta real de los eventos.
Tener permiso de lectura en SQL no entrega todavía esa pantalla.

Para acordar antes del desarrollo adicional: cierre atómico de HU-029, validación
SQL aislada de HU-030 y alcance/navegación de la consulta integral de auditoría
en HU-028. Mantener sus tarjetas originales, sin duplicar HU.
