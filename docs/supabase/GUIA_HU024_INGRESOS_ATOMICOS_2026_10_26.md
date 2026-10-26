# HU-024: ingresos atómicos y correcciones justificadas

Implementación y migración aplicadas el 26/10/2026 en `nedeqnvpkalrchswrapr`,
rama `Sprint-05`. La validación funcional de la interfaz corresponde al usuario.

## Registro del ingreso

El formulario existente llama a `registrar_ingreso_lote_hu024`: lote, stock
inicial en Almacén, registro original y auditoría se guardan juntos. Si falla
cualquiera, se revierte todo. El alta de medicamento con primer lote utiliza la
misma RPC, incluyendo el medicamento en esa transacción para no dejarlo huérfano.
El catálogo puede seguir gestionando medicamentos sin ingreso mediante su flujo
independiente.

Solo Almacén y Administrador activos registran/corrigen ingresos. Todo ingreso
nuevo queda exclusivamente en Almacén. No cambia los despachos ni acredita stock
a Farmacia. Se conserva el mecanismo de tránsito y recepción ya implementado.

El número de lote se normaliza con espacios exteriores eliminados y mayúsculas.
Se bloquea otro ingreso del mismo producto y lote, incluyendo variantes de
mayúsculas/espacios. No se fusionan ni se eliminan lotes históricos. Una clave
por envío conserva el resultado después de un fallo de red, sin duplicarlo.

El servidor valida producto/área, cantidad positiva, vencimiento futuro,
fabricación coherente, precios no negativos y tipo Compra/Donación. La interfaz
también rechaza fechas inexistentes y precios inválidos en lugar de convertirlos
silenciosamente en nulos.

## Correcciones

Almacén abre **Ingresos y correcciones**, busca por producto, lote o documento y
elige **Corregir cantidad**. Se distingue el total del ingreso de las existencias
que quedan actualmente. Se ingresa el total correcto, una justificación y,
para disminuciones, la ubicación físicamente verificada.

- Aumento: la diferencia queda en Almacén, sin traslado automático a Farmacia.
- Disminución: solo descuenta la ubicación elegida (Almacén o Farmacia) si existe
  stock suficiente allí. No se toman unidades de otras áreas, del tránsito ni
  del consumo. No se alteran las cantidades de pedidos o recepciones pasadas.
- Si el descuento no puede cubrirse, se bloquea y se pide verificar/conciliar la
  discrepancia. No se simula una pérdida ni se generan existencias negativas.
- Se preserva la cantidad original; cambia la cantidad vigente del ingreso y se
  registra un ajuste separado. Documento, costo y datos originales del lote no
  se editan desde esta corrección de cantidad.

La preconfirmación usa una tabla Nombre/Antes/Después con el ingreso vigente y
los saldos de ambas ubicaciones. Debe confirmarse la verificación física de la
ubicación. Una huella de lote/ingreso/stock evita aplicar una vista previa
obsoleta. La corrección serializa sus cambios de stock con los otros movimientos;
no modifica el código de despacho, recepción ni diferencias.

Para lotes históricos sin `ingresos_lote`, se admite corregir solo si existe
exactamente un evento `INGRESO_ALMACEN` con cantidad positiva. Se conserva esa
cantidad y el lote existente como apertura histórica. Si falta esa evidencia o
es ambigua, se muestra pendiente de conciliación. Nunca se reconstruye la
cantidad original sumando el stock que quedó tras distribuciones o consumos.

## Auditoría e historial

- `ingresos_lote`: cantidad original, cantidad vigente y datos originales.
- `operaciones_ingreso_lote`: identidad, clave, contenido y resultado por operación.
- `INGRESO_ALMACEN`: lote, cantidad, costo, documento y usuario del ingreso.
- `AJUSTE_INGRESO_LOTE`: antes/después, delta, ubicación, usuario y justificación.

Ingreso, ajuste y auditoría son atómicos. Jefatura consulta el historial desde
su pantalla, sin controles ni permisos de corrección. No se permite escritura
directa de clientes en lotes/stock ni en las tablas de control nuevas. Las
consultas conservan sus permisos y las RPC de abastecimiento siguen ejecutando
sus cambios con sus permisos de servidor.

## Despliegue y comprobaciones

Se aplicó solamente `migracion_hu024_ingresos_atomicos_2026_10_26.sql`, no todo el
setup. El setup incorpora esa misma migración al final para bases nuevas.

Se compararon huellas de medicamentos, lotes, stock, auditoría, pedidos, ítems,
despachos y reportes antes/después: todos los registros existentes se conservaron.
Se compararon las definiciones de las demás funciones públicas: ninguna cambió.
Se verificaron las cuatro funciones nuevas y los privilegios correspondientes.
No se introdujeron movimientos de prueba en Supabase.

SHA-256 aplicado:

```text
64f4564cb7ad0d924af95696a3ec608fff04b61f1399231465dc44a8def30526
```

Conforme a la indicación del usuario, no se ejecutó una suite extensa ni pruebas
funcionales en la app. Se hizo una comprobación mínima de migración, registro,
reintento y corrección en PostgreSQL local, fuera del proyecto, revertida por
completo. `flutter analyze` terminó sin observaciones. No se reconstruyó ni se
probó manualmente el emulador.

La edición general de documentos/costos históricos y la gestión de discrepancias
sin cantidad original inequívoca no se sustituyen por una edición libre. Los
kits y el resto del Sprint 5 mantienen sus pendientes independientes.
