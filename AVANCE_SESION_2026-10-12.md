# 📋 SITRA-Luz — Registro de Avances (Sesión 12 Oct 2026)

> **Propósito:** Documento de traspaso entre agentes. Contiene contexto completo, decisiones de diseño, archivos modificados, estados del sistema e interfaces pendientes.

---

## 🗂️ Índice

1. [Contexto del Proyecto](#1-contexto-del-proyecto)
2. [Requerimientos Trabajados (RF-029 y RF-030)](#2-requerimientos-trabajados-rf-029-y-rf-030)
3. [Decisiones de Diseño Tomadas](#3-decisiones-de-diseño-tomadas)
4. [Máquina de Estados — Pedidos de Abastecimiento](#4-máquina-de-estados--pedidos-de-abastecimiento)
5. [Arquitectura de la Solución](#5-arquitectura-de-la-solución)
6. [Archivos Modificados](#6-archivos-modificados)
7. [Interfaces Implementadas](#7-interfaces-implementadas)
8. [Interfaces Pendientes](#8-interfaces-pendientes)
9. [Script de Migración SQL](#9-script-de-migración-sql)
10. [Flujos de Negocio Definidos](#10-flujos-de-negocio-definidos)
11. [Próximos Pasos para el Siguiente Agente](#11-próximos-pasos-para-el-siguiente-agente)

---

## 1. Contexto del Proyecto

**SITRA-Luz** es un sistema de gestión hospitalaria (clínica pequeña/mediana) construido en **Flutter + Supabase (PostgreSQL)**, con arquitectura **Clean Architecture** (Domain → Data → Presentation).

### Módulos existentes antes de esta sesión:
- ✅ Autenticación (login por rol)
- ✅ Dashboard Farmacia
- ✅ Dashboard Almacén
- ✅ Dashboard Enfermería/Áreas
- ✅ Gestión de catálogo de medicamentos (con IA para lectura de etiquetas)
- ✅ Registro de medicamentos con lotes
- ✅ Inventario de stock por área

### Roles del sistema:
| Rol | Descripción |
|-----|-------------|
| `FARMACIA` | Turno de guardia, gestiona stock de farmacia y solicita reabastecimiento |
| `ALMACEN` | Atiende solicitudes de farmacia y de áreas clínicas |
| `ENFERMERIA` / Áreas | Solicitan insumos/medicamentos a farmacia |
| `JEFATURA` | Supervisión y reportes |
| `ADMIN` | Gestión de usuarios (pendiente de implementar) |

---

## 2. Requerimientos Trabajados (RF-029 y RF-030)

### RF-029 — Registrar solicitud de abastecimiento por faltantes de guardia
**Actor:** Personal de Farmacia
**Flujo:**
1. Farmacia revisa su stock físico durante su turno.
2. Crea una solicitud seleccionando ítems del catálogo de medicamentos.
3. Indica la cantidad necesaria y la justificación (`STOCK_CERO` o `RELLENAR_STOCK`).
4. Al enviar, la solicitud queda en estado **PENDIENTE** y es visible para Almacén.

**Importancia:** Evita rupturas de stock mediante solicitudes anticipadas. Reemplaza el proceso informal verbal/papel.

---

### RF-030 — Visualizar y atender solicitudes de abastecimiento (Almacén)
**Actor:** Personal de Almacén
**Flujo:**
1. Almacén ve el listado de solicitudes pendientes.
2. Toma la solicitud → estado **EN_PREPARACION**.
3. Prepara los ítems y define la modalidad de entrega (`ENTREGA` = Almacén lleva / `RECOJO` = Farmacia recoge).
4. Marca como **LISTO** cuando está preparado.
5. Farmacia confirma recepción → estado **COMPLETADO**.
   - Si hay discrepancias en cantidad, puede ajustar y se genera contra-asiento de stock automático.

---

## 3. Decisiones de Diseño Tomadas

### 3.1 CANCELADO vs RECHAZADO — Conceptos distintos

> **Regla de oro del usuario:** "Rechazado" y "Cancelado" son procesos operativos distintos.

| Estado | Quién lo genera | Cuándo | Significado |
|--------|----------------|--------|-------------|
| `CANCELADO` | **Farmacia** | Mientras el pedido está en `PENDIENTE` | Farmacia se equivocó o ya no necesita el pedido. Acto voluntario. |
| `RECHAZADO` | **Almacén** | En cualquier momento que Almacén lo tome | Almacén no puede atender la solicitud (sin stock, error en pedido, etc.). Acto de rechazo externo. |

**Consecuencia de código:** Existen dos campos separados:
- `motivo_cancelacion` + `fecha_cancelacion` → para flujo de Farmacia
- `motivo_rechazo` → para flujo de Almacén

### 3.2 Edición y eliminación de pedidos

| Acción | Cuándo está permitida |
|--------|----------------------|
| **Editar pedido** | No permitido. Farmacia cancela con motivo y crea una nueva solicitud. |
| **Cancelar pedido** | Solo en estado `PENDIENTE` (por Farmacia) |
| **Rechazar pedido** | Almacén puede rechazar en `PENDIENTE` o `EN_PREPARACION`, nunca después del despacho. |
| **Modificar en COMPLETADO** | No permitido. Se usa ajuste en recepción. |

### 3.3 Modalidad de entrega (decidida por Almacén)
- **`ENTREGA`**: Almacén entrega físicamente en Farmacia.
- **`RECOJO`**: Farmacia pasa a recoger a Almacén.
- Esta decisión la toma Almacén al confirmar el despacho y pasar a `LISTO`.

### 3.4 Confirmación de recepción (solo Farmacia)
- Solo Farmacia tiene el botón "Confirmar Recepción" cuando el estado es `LISTO`.
- Farmacia puede indicar cantidades reales recibidas si difieren de lo despachado.
- Si hay diferencia → contra-asiento automático devuelve el exceso a stock de Almacén.
- Almacén no necesita confirmar nada adicional; su confirmación ya fue implícita al marcar `LISTO`.

### 3.5 Integridad de stock — Transferencias atómicas
- Al despachar: se resta del stock de Almacén y se suma al stock de Farmacia.
- Al recibir con ajuste: si Farmacia recibió menos, el exceso se devuelve al stock de Almacén.
- Todo movimiento queda registrado en `auditoria_trazabilidad`.

---

## 4. Máquina de Estados — Pedidos de Abastecimiento

```
FARMACIA crea
     |
     v
[PENDIENTE] ---- Farmacia cancela ---> [CANCELADO]
     |
     | Almacén toma el pedido
     v
[EN_PREPARACION] ---- Almacén rechaza ---> [RECHAZADO]
     |
     | Almacén termina de preparar
     v
[LISTO] (ya despachado: toda corrección requiere contra-asiento en recepción)
     |
     | Farmacia confirma recepción (con o sin ajuste)
     v
[COMPLETADO]
```

### Colores en UI:
| Estado | Color |
|--------|-------|
| `PENDIENTE` | Ámbar |
| `EN_PREPARACION` | Azul |
| `LISTO` | Verde |
| `COMPLETADO` | Teal / Verde oscuro |
| `CANCELADO` | Gris |
| `RECHAZADO` | Rojo |

---

## 5. Arquitectura de la Solución

```
lib/features/almacen/
├── domain/
│   ├── entities/
│   │   └── pedido_abastecimiento_entity.dart   <- Entidad pura (Pedido + Items)
│   └── repositories/
│       └── almacen_repository.dart             <- Interfaz del repositorio
├── data/
│   ├── models/
│   │   └── pedido_abastecimiento_model.dart    <- Mapeo JSON <-> Entity
│   ├── datasources/
│   │   └── almacen_remote_datasource.dart      <- Lógica de negocio + Supabase
│   └── repositories/
│       └── almacen_repository_impl.dart        <- Implementación del repositorio
└── presentation/
    ├── viewmodels/
    │   └── almacen_viewmodel.dart              <- Estado UI (ChangeNotifier)
    └── views/
        ├── crear_solicitud_abastecimiento_view.dart  <- Farmacia crea pedido
        └── solicitudes_abastecimiento_view.dart      <- Vista dual (Farmacia + Almacén)
```

---

## 6. Archivos Modificados

### 6.1 Base de Datos
**`docs/supabase/setup_sitra_luz.sql`**
- Nueva columna `motivo_cancelacion TEXT`
- Nueva columna `fecha_cancelacion TIMESTAMPTZ`
- Nueva columna `motivo_rechazo TEXT`
- Nueva columna `modalidad_entrega TEXT CHECK IN ('ENTREGA', 'RECOJO')`
- Nueva columna `confirmado_almacen BOOL`
- Nueva columna `confirmado_farmacia BOOL`
- CHECK de estado actualizado: `('PENDIENTE','EN_PREPARACION','LISTO','COMPLETADO','CANCELADO','RECHAZADO')`
- Campo `cantidad_despachada INT` en tabla `pedido_abastecimiento_items`

### 6.2 Dominio
**`app/lib/features/almacen/domain/entities/pedido_abastecimiento_entity.dart`**
- Campos nuevos: `motivoCancelacion`, `motivoRechazo`, `modalidadEntrega`, `confirmadoAlmacen`, `confirmadoFarmacia`
- Getters: `esPendiente`, `esEnPreparacion`, `esListo`, `esCompletado`, `esCancelado`, `esRechazado`

### 6.3 Datos
**`app/lib/features/almacen/data/models/pedido_abastecimiento_model.dart`**
- Mapeo actualizado con todos los campos nuevos

**`app/lib/features/almacen/data/datasources/almacen_remote_datasource.dart`**
- `crearPedidoAbastecimiento()` — Farmacia crea pedido
- `getPedidosAbastecimiento()` — Lista filtrada por estado y área
- `tomarPedidoAbastecimiento()` — Almacén toma → EN_PREPARACION + define modalidad
- `despacharPedidoAbastecimiento()` — Almacén despacha → LISTO + transfiere stock
- `cancelarPedidoAbastecimiento()` — Farmacia cancela → CANCELADO + motivo
- `rechazarPedidoAbastecimiento()` — Almacén rechaza → RECHAZADO + motivo
- `confirmarRecepcionConAjuste()` — Farmacia confirma → COMPLETADO + contra-asiento si hay diferencia

**`app/lib/features/almacen/data/repositories/almacen_repository_impl.dart`**
- Implementación de todos los métodos nuevos

### 6.4 Presentación
**`app/lib/features/almacen/presentation/viewmodels/almacen_viewmodel.dart`**
- Estados de carga para cada acción
- Métodos expuestos a la UI

**`app/lib/features/almacen/presentation/views/solicitudes_abastecimiento_view.dart`**
- Vista dual (detecta rol: FARMACIA o ALMACEN)
- Tarjetas de pedido con chips de estado coloreados
- Botón cancelar (solo PENDIENTE, solo FARMACIA) con selector de motivo
- Botón tomar / preparar / despachar (ALMACEN)
- Modal de recepción física con ajuste de cantidades (FARMACIA, estado LISTO)
- Filtro de archivados (CANCELADO/RECHAZADO)

**`app/lib/features/dashboard_farmacia/presentation/views/farmacia_dashboard_view.dart`**
- Contador de solicitudes activas (excluye CANCELADO/RECHAZADO/COMPLETADO)
- Acceso directo a Solicitudes de Abastecimiento

---

## 7. Interfaces Implementadas

### `crear_solicitud_abastecimiento_view.dart`
**Rol:** Farmacia
**Función:** Formulario para crear un nuevo pedido de abastecimiento
- Selector de medicamentos del catálogo
- Campo de cantidad
- Selector de turno (DIA / TARDE / NOCHE)
- Selector de justificación (STOCK_CERO / RELLENAR_STOCK)
- Notas opcionales
- Botón enviar → crea pedido en PENDIENTE

---

### `solicitudes_abastecimiento_view.dart`
**Rol:** Farmacia + Almacén (vista adaptativa según rol)

**Vista Farmacia:**
- Lista de sus propias solicitudes
- Chip de estado coloreado
- Botón Cancelar (solo si PENDIENTE) → abre bottom sheet con motivos predefinidos
- Botón Confirmar Recepción (si LISTO) → abre modal con tabla de ítems y cantidades recibidas

**Vista Almacén:**
- Lista de todas las solicitudes pendientes de atención
- Botón Tomar (si PENDIENTE) → abre diálogo para elegir modalidad de entrega
- Botón Marcar Listo (si EN_PREPARACION) → confirma cantidades a despachar
- Botón Rechazar (si PENDIENTE o EN_PREPARACION) → abre bottom sheet con motivo
- Toggle para ver archivados

---

### `farmacia_dashboard_view.dart`
- Card con contador de solicitudes activas
- Acceso rápido a crear solicitud
- Acceso rápido a ver solicitudes

---

## 8. Interfaces Pendientes

> ATENCION: Estas vistas aún NO han sido implementadas. El siguiente agente debe crearlas.

### 8.1 Vista de Detalle de Pedido
**Archivo sugerido:** `solicitud_detalle_view.dart`
**Rol:** Farmacia + Almacén
**Contenido:**
- Cabecera: código, fecha, turno, justificación, solicitante
- Estado actual con timeline visual de pasos
- Lista de ítems con cantidad solicitada / despachada / recibida
- Historial de cambios de estado (auditoría)
- Botones de acción según estado y rol

---

### 8.2 Vista de Historial/Reportes de Solicitudes
**Archivo sugerido:** `historial_solicitudes_view.dart`
**Rol:** Farmacia + Almacén + Jefatura
**Contenido:**
- Filtros por fecha, estado, turno, solicitante
- Tabla/lista de solicitudes archivadas
- Exportar resumen (PDF o Excel — futuro)

---

### 8.3 Dashboard Almacén — Vista principal
**Archivo sugerido:** `almacen_dashboard_view.dart`
**Rol:** Almacén
**Contenido:**
- Contador de solicitudes pendientes de Farmacia
- Contador de solicitudes pendientes de Áreas
- Acceso a catálogo de medicamentos
- Acceso a inventario de stock

---

### 8.4 Flujo de Dispensación a Áreas Clínicas (RF pendiente)
**Descripción:** Áreas (enfermería, etc.) solicitan insumos/medicamentos a Farmacia.
**Estados:** Los mismos que Farmacia-Almacén pero el actor cambia:
- Área crea pedido → PENDIENTE
- Farmacia prepara → EN_PREPARACION
- Farmacia alista → LISTO
- Área confirma recepción → COMPLETADO
- Área puede cancelar si PENDIENTE
- Farmacia puede rechazar

**Archivos a crear:**
- `dispensacion_entity.dart`
- `dispensacion_model.dart`
- `dispensacion_remote_datasource.dart`
- `dispensacion_repository.dart`
- `dispensacion_repository_impl.dart`
- `dispensacion_viewmodel.dart`
- `crear_dispensacion_view.dart`
- `solicitudes_dispensacion_view.dart`

---

### 8.5 Módulo de Administración de Usuarios (más adelante)
**Nota del usuario:** "El módulo de administrador y gestión de usuarios lo haremos luego, no ahora."

---

## 9. Script de Migración SQL

> El script debe aplicarse en Supabase SQL Editor o via psql.
> IMPORTANTE: Aplicar ANTES de ejecutar la app con los nuevos cambios.

```sql
-- Nuevas columnas en pedidos_abastecimiento
ALTER TABLE pedidos_abastecimiento
  ADD COLUMN IF NOT EXISTS motivo_cancelacion TEXT,
  ADD COLUMN IF NOT EXISTS fecha_cancelacion TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS motivo_rechazo TEXT,
  ADD COLUMN IF NOT EXISTS modalidad_entrega TEXT CHECK (modalidad_entrega IN ('ENTREGA', 'RECOJO')),
  ADD COLUMN IF NOT EXISTS confirmado_almacen BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS confirmado_farmacia BOOLEAN DEFAULT FALSE;

-- Actualizar CHECK de estado para incluir CANCELADO
ALTER TABLE pedidos_abastecimiento
  DROP CONSTRAINT IF EXISTS pedidos_abastecimiento_estado_check;

ALTER TABLE pedidos_abastecimiento
  ADD CONSTRAINT pedidos_abastecimiento_estado_check
  CHECK (estado IN ('PENDIENTE','EN_PREPARACION','LISTO','COMPLETADO','CANCELADO','RECHAZADO'));

-- Campo de cantidad_despachada en items
ALTER TABLE public.pedidos_abastecimiento_items
  ADD COLUMN IF NOT EXISTS cantidad_despachada INTEGER DEFAULT 0;
```

---

## 10. Flujos de Negocio Definidos

### Flujo Farmacia → Almacén (RF-029 / RF-030)

```
1. [FARMACIA] Crea pedido con ítems y cantidades
        |
        v
2. [SISTEMA] Pedido en estado PENDIENTE
        |
        |--[FARMACIA] Si se equivocó -> CANCELA -> Estado: CANCELADO (fin)
        |
        v
3. [ALMACEN] Ve el pedido pendiente -> LO TOMA
             Define modalidad: ENTREGA o RECOJO
        |
        v
4. [SISTEMA] Estado: EN_PREPARACION
        |
        |--[ALMACEN] No puede atender -> RECHAZA -> Estado: RECHAZADO (fin)
        |
        v
5. [ALMACEN] Prepara los ítems físicamente
             Confirma cantidades a despachar
        |
        v
6. [SISTEMA] Estado: LISTO
             Stock de Almacén: se descuenta
             Stock de Farmacia: se incrementa (transferencia atómica)
        |
        v
7. [FARMACIA] Recibe físicamente los ítems
             Confirma recepción (con o sin ajuste de cantidades)
        |
        |--[Si hay diferencia] -> Contra-asiento: exceso vuelve a Almacén
        |
        v
8. [SISTEMA] Estado: COMPLETADO
             Registro en auditoria_trazabilidad
```

---

## 11. Próximos Pasos para el Siguiente Agente

### Prioridad Alta (hacer primero)

1. **Verificar migración SQL en Supabase:** Confirmar que los nuevos campos ya existen en la BD. Si no, aplicar el script de la Sección 9.

2. **Probar flujo completo de Farmacia-Almacén:** Ejecutar la app con `flutter run` y verificar:
   - Crear solicitud desde Farmacia
   - Tomar/preparar/despachar desde Almacén
   - Confirmar recepción desde Farmacia
   - Cancelar pedido desde Farmacia (solo si PENDIENTE)
   - Rechazar pedido desde Almacén

3. **Implementar vista de Detalle de Pedido** (`solicitud_detalle_view.dart`) — ver Sección 8.1.

### Prioridad Media

4. **Implementar flujo de Dispensación a Áreas** — ver Sección 8.4. Debe replicar la misma lógica de estados pero con Farmacia en el rol de "proveedor" y Áreas como "solicitante".

5. **Dashboard Almacén** (`almacen_dashboard_view.dart`) con contadores en tiempo real.

### Prioridad Baja (más adelante)

6. **Historial y reportes** (`historial_solicitudes_view.dart`)
7. **Módulo de administración de usuarios** (el usuario indicó que esto se hace después)

---

## Notas Adicionales del Usuario

- **No borrar datos**: Preferencia explícita por usar estados (cancelado/rechazado) en lugar de eliminar registros.
- **Trazabilidad total**: Todo cambio de estado debe quedar en `auditoria_trazabilidad`.
- **Diseño visual**: Las interfaces deben seguir el mismo estilo que las otras vistas ya implementadas (cards, colores de estado, glassmorphism sutil, etc.).
- **No hay múltiples usuarios aún**: En la fase actual solo existe un usuario de prueba. Los módulos de roles y permisos se refinan luego.
- **Supabase como backend**: No hay backend propio, toda la lógica de negocio está en el datasource de Dart llamando directamente a Supabase.

---

*Generado el 12 de octubre de 2026 — SITRA-Luz v0.1-dev*


## Actualización de implementación — flujo acordado con el usuario

Esta sección prevalece sobre cualquier indicación anterior de edición o rechazo tardío.

- Farmacia nunca edita un pedido emitido: cancela con motivo mientras está `PENDIENTE` y crea uno nuevo.
- En `EN_PREPARACION`, Farmacia se comunica físicamente con Almacén. Almacén dispone de **Rechazar solicitud**, incluido el motivo **Cancelación coordinada con Farmacia**.
- Almacén primero toma el pedido y luego despacha. Elige `ENTREGA` o `RECOJO` en el despacho.
- Solo Farmacia confirma recepción física en `LISTO`: **Aceptar conforme** o **Devolver exceso** con motivo obligatorio.
- El estado final sigue siendo `COMPLETADO`; si hay devolución, la interfaz muestra **COMPLETADO CON OBSERVACIÓN**. No se añade un estado incompatible.
- `cantidad_despachada` se conserva. `cantidad_recibida` guarda lo aceptado; el detalle por lote registra lo devuelto.
- Se usa `public.procesar_pedido_abastecimiento` vía RPC para bloquear el pedido, validar rol/estado, actualizar inventario y guardar auditoría en una operación atómica. La lógica de stock ya no consiste en llamadas Dart separadas.
- La auditoría de devolución utiliza `DEVOLUCION_EN_RECEPCION` y referencia el pedido, usuario, medicamento, lote y cantidades.
- Las solicitudes ya no se sustituyen por datos demo cuando la consulta está vacía o falla: una lista vacía permanece vacía y un fallo se muestra con opción de reintentar.
- Antes de usar la app, ejecutar **docs/supabase/migracion_recepcion_pedidos_2026_10_12.sql**. Para una base existente, no ejecutar nuevamente el setup completo.
- La migración no modifica despachos históricos ni reconstruye datos que ya hayan sido sobrescritos. Una devolución histórica sin lote identificable se detiene para revisión.
- El alcance de esta sesión es Farmacia ↔ Almacén. Dispensación a Áreas y administración de usuarios siguen pendientes.

Validación local: pruebas de interfaz/modelo en pantalla de 360 px; verificaciones PostgreSQL (PGlite) de migración repetida, roles, transiciones, FEFO multilot y rollback por stock insuficiente. La migración no se ejecutó en Supabase remoto.


### Preferencias confirmadas y diseño de pedidos

- El setup completo `docs/supabase/setup_sitra_luz.sql` debe actualizarse junto con cada migración. Ahora incluye la función de pedidos y el detalle por lotes y no necesita un segundo script para reconstruir una base nueva.
- Las migraciones son para actualizar una base existente sin reconstruirla; el setup completo es para reconstrucción.
- Diseño de las vistas de pedidos: rojo `#C62828`, rojo claro, gris claro y blanco; tipografía de títulos 18 px, campos y textos 13–14 px, controles con bordes de 12 px y espacios amplios.
- Por instrucción explícita del usuario: no ejecutar pruebas, análisis, validaciones ni capturas salvo que lo solicite. Dar instrucciones de revisión manual para que él las realice.
- No se han ejecutado pruebas ni tomado capturas de esta última corrección visual y del setup autosuficiente.
