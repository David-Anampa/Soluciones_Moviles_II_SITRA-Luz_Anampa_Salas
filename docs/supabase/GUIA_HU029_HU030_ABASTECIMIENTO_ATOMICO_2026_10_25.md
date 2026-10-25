# HU-029/HU-030: cierre técnico de abastecimiento

Fecha: 25 de octubre de 2026. Rama: Sprint-05.

Avance posterior: [stock en tránsito y envíos iniciados por Almacén](GUIA_STOCK_TRANSITO_Y_ENVIOS_ALMACEN_2026_10_25.md).
Ese cambio modifica el momento en que Farmacia recibe stock y agrega la consulta
por ubicación. Está validado localmente y todavía no desplegado; esta guía
describe la migración anterior que sí está instalada en Supabase.

## Comportamiento final

HU-029 guarda la cabecera (número, solicitante, turno, justificación y estado),
los productos y CREACION_PEDIDO en una sola RPC PostgreSQL. Si falla cualquiera
de ellos, no queda una solicitud parcial. La solicitud no mueve stock.

El cliente conserva una clave UUID mientras reintenta un envío con los mismos
datos. El servidor serializa las llamadas con esa clave por solicitante y devuelve
el pedido existente, sin repetir ítems ni eventos. Reutilizar la clave con datos
distintos se rechaza. Después de un éxito, una nueva solicitud tiene otra clave.
La clave pendiente del cliente vive en la sesión de la aplicación; no es una
garantía de recuperar formularios tras reinstalar o cerrar completamente la app.

HU-030 conserva el ciclo PENDIENTE → EN_PREPARACION → LISTO → COMPLETADO.
Farmacia puede cancelar su propia solicitud pendiente; Administración conserva
la excepción autorizada. Almacén puede rechazar antes del despacho. Los motivos
de cancelación, rechazo y devolución permanecen en el registro y en la auditoría.

El despacho selecciona lotes FEFO activos y no vencidos, mueve stock de Almacén
a Farmacia y registra cada lote. No permite superar lo solicitado ni un despacho
total de cero. La recepción conforme no vuelve a sumar ni descontar unidades.
Una devolución revierte únicamente el exceso por sus lotes originales, devuelve
primero los de vencimiento posterior y conserva la cantidad originalmente despachada.
Se registra también `fecha_recepcion` al completar.

Un reintento idéntico del mismo actor en una transición ya confirmada devuelve
éxito sin duplicar movimientos ni auditoría. Cambiar cantidades, motivo o modalidad
en un despacho/recepción ya cerrado no reescribe la operación histórica.

## Rutas y permisos

- Nueva RPC: `crear_pedido_abastecimiento(UUID,TEXT,TEXT,TEXT,TEXT,JSONB)`.
- RPC de atención: conserva la firma de seis parámetros de `procesar_pedido_abastecimiento`.
- Solicitante, rol y estado se determinan en el servidor; no se aceptan del cliente.
- Se retira INSERT/UPDATE/DELETE directo de pedidos e ítems para authenticated.
- Se retira UPDATE directo de stock para authenticated. El ingreso actual de
  un lote nuevo sigue utilizando INSERT; HU-024 no se desarrolla en esta entrega.
- El antiguo traslado directo queda bloqueado y el botón de Almacén abre
  Solicitudes de abastecimiento. Así se conserva la confirmación de Farmacia.
- Las políticas de lectura permiten a Jefatura consultar los eventos. No se añade
  una pantalla de auditoría en esta entrega: pertenece al alcance de supervisión HU-028.

## Auditoría del flujo

CREACION_PEDIDO registra actor, fecha, turno, justificación, clave del envío,
cabecera e ítems originales. La atención conserva TOMA_PEDIDO, CANCELACION_PEDIDO,
RECHAZO_PEDIDO, TRANSFERENCIA_FARMACIA por lote, DESPACHO_PEDIDO,
DEVOLUCION_EN_RECEPCION por lote y RECEPCION_PEDIDO.

Cada cambio confirmado y su auditoría se guardan en la misma transacción.
Un fallo al insertar la auditoría revierte también el pedido o movimiento de stock.
Jefatura tiene lectura de los eventos, sin capacidad de editar o borrar auditoría.
Esta cobertura se refiere al abastecimiento; no certifica módulos futuros.

## Migración y despliegue

`migracion_hu029_hu030_abastecimiento_atomico_2026_10_25.sql` requiere recepción,
HU-002 y HU-012. Está incorporada al final del setup para bases nuevas.
No ejecutar el setup completo sobre la base actual.

Se aplicó al proyecto `nedeqnvpkalrchswrapr` después de completar las pruebas locales.
Se verificaron ambos cuerpos de función y los privilegios declarados. Durante
la instalación se bloquearon las tablas afectadas y se compararon sus huellas
antes/después: no cambiaron pedidos, ítems, stock ni auditoría existentes.
No se introdujeron pedidos, usuarios ni stock de prueba en Supabase remoto.

SHA-256 del archivo aplicado:

```text
e20cff8b971bf310ecf501dea5d4174d6e5a014efde5fa3dc46e5a1a73b6042d
```

## Pruebas fuera del repositorio

Por indicación del usuario, el entorno y las pruebas nuevas se guardan en:

```text
C:\Users\ASUS\Documents\Codex\2026-10-25\empe\work\hu029_hu030
```

La prueba de datasource creada en la revisión anterior se trasladó a esa carpeta;
los tests de interfaz que ya pertenecían al proyecto se conservan en el repositorio.
Se utiliza PostgreSQL 17.6 portable en localhost, con datos sintéticos y los
esquemas/políticas pertinentes de recepción, HU-002, HU-012 y la nueva migración.
El archivo `bootstrap.py` no admite una conexión remota.

Resultados finales:

| Comprobación | Resultado |
|---|---|
| SQL real en base aislada | 30 casos aprobados |
| Flutter en paquete externo | 30 casos aprobados |
| flutter analyze | No issues found! |

Las pruebas SQL cubren creación completa, datos inválidos, roles, rollback si
falla auditoría, creación simultánea con la misma clave, FEFO, stock insuficiente,
fallo en el segundo producto, devolución parcial/total y falta de stock para devolver.
También cubren dos pedidos compitiendo por el mismo stock, dos tomas con distintos
responsables y despacho/recepción simultáneos repetidos. Verifican que Jefatura
ve los eventos y no puede alterarlos, así como continuidad de pedidos históricos
cuando se deshabilita un área.

Las pruebas Flutter cubren el contrato RPC, errores sin fallbacks de escritura,
doble pulsación, clave conservada tras error, claves nuevas después de éxito o
cambio de contenido, limpieza al cerrar sesión y los diez casos de modelo/interfaz.

## Estado de cierre

HU-029 y HU-030 quedan implementadas, desplegadas y con validación técnica por
terminal para los casos descritos. No se ejecutó una nueva prueba manual en Pixel 8,
no se actualizó GitHub y no se simula la revisión/aceptación del compañero o usuario.
El paso académico a Listo conserva esa aceptación como parte de la Definition of Done.
HU-023/HU-024 y la pantalla integral de auditoría siguen en sus alcances originales.
