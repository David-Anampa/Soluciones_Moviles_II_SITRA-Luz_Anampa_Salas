# Guía Operativa — Sprint 7 (Semana 4): Atención y Entrega de Fichas (HU-006 a HU-011 + Contrato HU-025)

## 1. Objetivo del Sprint 7
Operar fichas clínicas de pedido (Generales y de Neonatología) de principio a fin con cantidades reales, control de permisos por rol/área, bloqueo contra doble pulsación y trazabilidad completa por lote aplicando **FEFO** (*First Expired, First Out*):

- **David Anampa (HU-006, HU-007 y refinamiento de contrato HU-025):**
  - **HU-006:** Listado de fichas de pedido con filtros dinámicos (estado, área clínica, tipo de ficha `GENERAL`/`NEONATOLOGIA`, prioridad `NORMAL`/`URGENTE`, turno `DIA`/`TARDE`/`NOCHE` y búsqueda libre por código, paciente, madre/RN, médico o receptor).
  - **HU-007:** Vista de detalle completo de la ficha (encabezado clínico, financiamiento y valorización Kairos, desglose separado de Medicamentos y Dispositivos Médicos, lotes FEFO despachados e historial cronológico de auditoría).
  - **Contrato HU-025 (para Sprint 8):** RPC `public.consultar_kardex_medicamento_hu025` que unifica entradas de Almacén, transferencias a Farmacia, consumos por ficha (`CONSUMO_FICHA_AREA`) y contra-asientos de anulación (`REINGRESO_ANULACION_FICHA`).
- **Walter Salas (HU-008, HU-009, HU-010 y HU-011):**
  - **HU-008:** Máquina de estados de atención (`SOLICITADO` → `EN_PREPARACION` → `LISTO_PARA_RECOJO` → `ENTREGADO`, además de `CANCELADO`) con bloqueo transaccional (`pg_advisory_xact_lock`) e idempotencia (`operacion_atencion_id`).
  - **HU-009:** Registro de cantidades despachadas reales (`0 <= cantidad_entregada <= cantidad_solicitada`) y observación justificativa obligatoria cuando existe despacho parcial (`cantidad_entregada < cantidad_solicitada`).
  - **HU-010:** Confirmación de entrega/recojo con **descuento único y atómico por lote FEFO** desde `FARMACIA`, guardando el detalle en `public.dispensacion_item_lotes` y generando eventos `CONSUMO_FICHA_AREA` en `public.auditoria_trazabilidad`.
  - **HU-011:** Anulación de ficha con motivo obligatorio (5 a 500 caracteres), permisos según estado y **contra-asiento automático por lote** (`REINGRESO_ANULACION_FICHA`) cuando se anula por excepción una ficha ya entregada, sin borrar ningún movimiento histórico.

---

## 2. Script SQL a ejecutar en Supabase
Si ya tienes una base de datos creada con los sprints previos, ejecuta en el **SQL Editor** de Supabase:

- `docs/supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql`

> Si estás levantando el proyecto desde cero, `docs/supabase/setup_sitra_luz.sql` ya incluye todos los objetos de este sprint.

---

## 3. Reglas de Permisos y Estados

| Acción | Estado origen permitido | Estado destino | Roles autorizados | Efecto en stock de `FARMACIA` |
|---|---|---|---|---|
| `INICIAR_PREPARACION` (HU-008) | `SOLICITADO` | `EN_PREPARACION` | `FARMACIA`, `ADMINISTRADOR` | Sin descuento aún; pre-carga cantidad sugerida según stock vigente. |
| `GUARDAR_PREPARACION` (HU-009) | `SOLICITADO`, `EN_PREPARACION`, `LISTO_PARA_RECOJO` | `EN_PREPARACION` / `LISTO_PARA_RECOJO` | `FARMACIA`, `ADMINISTRADOR` | Valida stock vigente y exige observación en ítems con despacho parcial. |
| `MARCAR_LISTO_RECOJO` (HU-008/009) | `SOLICITADO`, `EN_PREPARACION`, `LISTO_PARA_RECOJO` | `LISTO_PARA_RECOJO` | `FARMACIA`, `ADMINISTRADOR` | Valida que `SUM(cantidad_entregada) > 0` y stock vigente suficiente. |
| `CONFIRMAR_ENTREGA` (HU-010) | `LISTO_PARA_RECOJO` (o `EN_PREPARACION` por Farmacia/Admin) | `ENTREGADO` | `FARMACIA`, `ADMINISTRADOR`, `ENFERMERIA` (del área solicitante) | **Descuento único y atómico por lote FEFO** en `inventario_stock` + registro en `dispensacion_item_lotes`. |
| `ANULAR_FICHA` (HU-011) | `SOLICITADO` | `CANCELADO` | `ENFERMERIA` (del área), `FARMACIA`, `ADMINISTRADOR` | Sin movimiento de stock (aún no se descontó). |
| `ANULAR_FICHA` (HU-011) | `EN_PREPARACION`, `LISTO_PARA_RECOJO` | `CANCELADO` | `FARMACIA`, `ADMINISTRADOR` | Sin movimiento de stock (aún no se entregó). |
| `ANULAR_FICHA` (HU-011) | `ENTREGADO` | `CANCELADO` | `FARMACIA`, `ADMINISTRADOR` | **Contra-asiento automático por lote** (`REINGRESO_ANULACION_FICHA`) devolviendo las unidades a `FARMACIA` sin borrar el historial. |

