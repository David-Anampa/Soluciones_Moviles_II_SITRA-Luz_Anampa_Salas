# Stock por ubicación y envíos iniciados por Almacén

## Estado de este avance

**Actualización del 26/10/2026:** las dos migraciones ya se aplicaron en Supabase,
incluida la gestión de faltantes con revisión y preconfirmación.
Consultar [la guía de diferencias](GUIA_DIFERENCIAS_ABASTECIMIENTO_2026_10_26.md)
para el comportamiento final, validaciones y evidencia del despliegue.

Implementado, validado en entorno local aislado y desplegado. La migración
`migracion_stock_transito_y_envios_almacen_2026_10_25.sql` requiere la migración
de abastecimiento atómico del 25/10 y se complementa con diferencias del 26/10.
No ejecutar el setup completo sobre una base existente.

Si el conteo físico es menor que el despacho y las unidades faltantes no se
devuelven físicamente, Farmacia reporta la diferencia y el pedido queda pendiente
de revisión sin mover stock. Almacén revisa y propone o aplica la solución con
justificación y preconfirmación; los cambios al conteo requieren confirmación de
Farmacia. La opción de devolución conservada corresponde a una devolución real.

## Reglas acordadas

- Los ingresos nuevos pertenecen a Almacén. No implican disponibilidad en Farmacia.
- Farmacia consulta el stock disponible de ambas ubicaciones y las unidades
  en tránsito antes de solicitar una reposición.
- Almacén puede atender una solicitud o iniciar un envío con motivo obligatorio.
- Se eligen cantidades por producto; lo no enviado permanece en Almacén.
  Enviar todo requiere una acción explícita para cada producto seleccionado.
- El despacho descuenta Almacén y registra tránsito. Farmacia puede disponer
  únicamente de lo contado y recibido, después de confirmar la recepción.
- Se conserva el lote despachado, su vencimiento y el orden FEFO.
- Los lotes vencidos o inactivos no se muestran como disponibles para despacho.
- El servidor verifica permisos, cantidades y existencias. Los reintentos
  idénticos no duplican pedidos ni movimientos.

## Auditoría

La iniciativa distingue `SOLICITUD_FARMACIA` de `TRASLADO_ALMACEN`. Se conservan
el actor, fecha, pedido, productos, lotes, cantidades, ubicaciones y los motivos
que corresponden a cada operación. El motivo del envío iniciado por Almacén
queda tanto en el pedido como en sus eventos de creación y despacho.

La salida se registra como `SALIDA_A_TRANSITO`; cada recepción por lote como
`RECEPCION_LOTE_FARMACIA`. Una devolución física conserva su evento y motivo,
sin borrar el despacho original. Cancelar o rechazar también exige motivo.
El movimiento y su auditoría se confirman en una sola transacción: si falla
la auditoría se revierte la operación completa. Jefatura conserva la lectura
protegida de estos eventos; la pantalla integral de auditoría no forma parte
de este avance.

Los pedidos históricos ya despachados mantienen su tratamiento anterior.
La consulta reserva sus cantidades pendientes para no presentarlas como stock
disponible de Farmacia y señala los casos que requieren conciliación.
Esta migración no redistribuye ni corrige inventario histórico.

## Interfaz

Nuevos accesos a «Stock por ubicación» y «Enviar a Farmacia». Farmacia puede
solicitar desde la consulta; Almacén puede iniciar un envío. Se muestran tres
contadores independientes y avisos cuando existe stock en Almacén pero no en
Farmacia. Se mantiene el rojo `#C62828`, tarjetas blancas, fondos grises y
pastel, iconos Material, campos espaciados y acciones inferiores protegidas
por SafeArea. Los errores de conexión no se sustituyen por datos ficticios.

## Validación fuera del proyecto

Entorno de pruebas en
`C:\Users\ASUS\Documents\Codex\2026-10-25\empe\work`.

| Comprobación | Resultado |
|---|---|
| SQL real en PostgreSQL local aislado | 26 casos aprobados |
| Flutter en paquete externo | 36 casos aprobados |
| flutter analyze | Sin observaciones |
| Interfaz de stock con anchos de 320 y 390 | Sin desbordes detectados |

Se comprobaron stock parcial y total, recepción y devolución, permisos,
concurrencia, reintentos, FEFO, conservación de cantidades, compatibilidad
histórica y reversión ante fallos de auditoría. Las capturas de revisión usan
datos sintéticos; no representan inventario real ni una prueba manual en Pixel 8.
No se crearon datos de prueba en Supabase remoto.

## Alcances pendientes

La corrección justificada de ingresos/lotes y sus discrepancias sigue pendiente
de implementación. No debe resolverse editando cantidades históricas ni
creando stock negativo. La pantalla integral de auditoría, las decisiones de
kits y el resto de HU-023/HU-024 mantienen su alcance pendiente; este avance
no declara cerrado todo el Sprint 5.
