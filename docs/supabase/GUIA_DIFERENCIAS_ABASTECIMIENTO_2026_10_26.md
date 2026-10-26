# Diferencias de recepción: revisión, solución e historial

Implementado y desplegado en Supabase `nedeqnvpkalrchswrapr` el 26/10/2026.
Rama de trabajo: `Sprint-05`.

## Uso

Farmacia abre un pedido en tránsito, pulsa «Confirmar recepción física» y elige
«Reportar diferencia». Ingresa el conteo de cada producto y una justificación.
La preconfirmación resume lo despachado, contado y faltante. Enviar el reporte
no mueve stock; el pedido conserva sus unidades en tránsito y no puede recibirse
por la ruta conforme mientras tenga una diferencia abierta.

«Mis reportes e historial» muestra los reportes propios de Farmacia. Puede
cancelar uno pendiente o una propuesta aún no aplicada, con justificación y
preconfirmación. No modifica stock. Cancelar o rechazar libera el pedido para
una recepción posterior o para crear un nuevo reporte corregido. El reporte
anterior queda en el historial.

Almacén accede a «Diferencias por resolver e historial» y pulsa «Solucionar»:

| Lo comprobado | Tratamiento |
|---|---|
| Las unidades quedaron físicamente en Almacén | Acredita el conteo aceptado en Farmacia y reintegra el faltante a Almacén. |
| Se entregaron las unidades pendientes | Propone el conteo completo; Farmacia debe confirmar esa recepción antes de acreditarla. |
| Se comprobó una pérdida | Acredita únicamente lo recibido y registra las unidades perdidas por lote. No las suma a Almacén. |

La solución permite ajustar el conteo propuesto. Si difiere del reporte original,
queda en estado `PROPUESTA`, sin movimientos, hasta que quien reportó en Farmacia
la confirme. Farmacia puede pedir otra revisión con motivo o cancelar el reporte.
Almacén también puede rechazar un reporte con justificación; nunca altera el
conteo original de Farmacia.

Antes de aplicar una solución, una tabla por producto muestra
**Ubicación / Antes / Después**, con Farmacia, Almacén y En tránsito. La
justificación se muestra en la misma preconfirmación. Se preservan los colores
rojo/blanco, iconos Material, espaciado y tipografía del tema de la aplicación:
texto y cantidades usan `bodyMedium` (Inter, 14), con el resultado destacado por
color y peso, sin aumentar su tamaño. El servidor verifica de nuevo el estado,
la versión del reporte y la huella del stock. Si cambió después de la consulta,
se debe volver a abrir la revisión para obtener una preconfirmación actualizada.

Los reportes resueltos no se cancelan ni se editan. Este flujo no habilita
correcciones libres de cantidades históricas ni existencias negativas.

## Datos y auditoría

- `diferencias_abastecimiento`: pedido, autor, conteo original, motivo, propuesta,
  destino comprobado, justificación de solución, estado, versión y fechas.
- `diferencias_abastecimiento_historial`: cada acción, responsable, motivo,
  contenido enviado y resultado. La clave de operación evita duplicados ante
  un reintento idéntico; una clave con distinto contenido se rechaza.
- `pedido_abastecimiento_despachos.cantidad_perdida`: pérdida por lote separada
  de lo recibido y reintegrado. La suma nunca supera lo despachado.
- `auditoria_trazabilidad`: eventos `DIFERENCIA_*` y `CONCILIACION_LOTE`, con
  datos anteriores/nuevos, pedido, lote, actor, cantidades y justificaciones.

Pedido, recepción, saldos, reporte, historial y auditoría se actualizan en la
misma transacción. Un fallo en auditoría revierte todo. Se conservan responsables
distintos para el reporte original y la solución; cuando se acepta ese conteo
original, el responsable de recepción es quien lo reportó en Farmacia.

Las tablas nuevas no admiten escritura directa para los clientes. Las funciones
validan usuarios activos y roles; Farmacia consulta sus reportes, Almacén revisa,
y Jefatura consulta toda la bandeja y el historial desde su acceso de auditoría.
La función anterior de recepción queda privada para evitar eludir el bloqueo de
un reporte abierto. Jefatura no tiene acciones de escritura.

La devolución física de exceso conserva su opción específica. No se usa para
unidades que nunca llegaron. Los despachos históricos anteriores al esquema
de tránsito mantienen su tratamiento original; no se convierten automáticamente
en reportes nuevos.

## Migraciones y verificación

Aplicadas juntas en una transacción, en este orden:

1. `migracion_stock_transito_y_envios_almacen_2026_10_25.sql`.
2. `migracion_diferencias_abastecimiento_2026_10_26.sql`.

Ambas están incorporadas al final de `setup_sitra_luz.sql` para bases nuevas.
Sobre la base existente se aplicaron solo las migraciones, sin ejecutar el setup.
Se verificaron nueve cuerpos de función y los privilegios. Se bloquearon las
tablas existentes y se compararon huellas antes/después: pedidos, ítems,
despachos, stock y auditoría quedaron intactos. No había pedidos históricos
`LISTO`; no se crearon usuarios, reportes ni movimientos de prueba en remoto.

SHA-256 de las migraciones aplicadas:

```text
stock/transito: 34eb72ad3d9759eb2fce61a9dfce336fff8d7e834ae1ee4a67e926ee137aea84
diferencias:   854e499e46110b5f444d8e054289dff2afba1ce7381445153bed17e21ad59fea
```

Las pruebas están fuera del proyecto, bajo
`C:\Users\ASUS\Documents\Codex\2026-10-25\empe\work`:

- 12 pruebas SQL nuevas de diferencias en PostgreSQL local real: solución,
  pérdida, propuesta, rechazo, cancelación, permisos, huellas/versiones,
  concurrencia, reintentos y rollback de auditoría.
- 26 pruebas SQL de regresión del abastecimiento y tránsito aprobadas después
  de instalar el nuevo flujo.
- 44 pruebas Flutter externas aprobadas. Después de los ajustes visuales se
  repitieron las pruebas de interfaz afectadas y se añadió un caso de tabla en
  ancho 320 con tipografía uniforme: 14 pruebas de interfaz aprobadas en esa
  última ejecución (13 existentes y 1 nueva). Las capturas usan datos sintéticos.
- `flutter analyze` sin observaciones. No se ejecutó una nueva prueba manual
  en el emulador Pixel 8.

## Alcance

Este avance cubre diferencias en recepción Almacén → Farmacia. La corrección de
cantidades de ingreso se completó posteriormente en
[HU-024](GUIA_HU024_INGRESOS_ATOMICOS_2026_10_26.md). Los acuerdos pendientes de
kits y la pantalla integral de toda la auditoría mantienen su alcance separado.
No se declara cerrado todo el Sprint 5.
