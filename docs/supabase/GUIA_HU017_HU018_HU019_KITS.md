# Guía de Validación y Contrato: HU-017, HU-018 y HU-019 (Kits Prearmados)

**Sprint 5 · Semana 2**  
**Responsable:** David Anampa  
**Entregables:**
- **HU-017:** Listar y habilitar/inhabilitar kits quirúrgicos y plantillas clínicas.
- **HU-018:** Crear kit reutilizando el formulario base.
- **HU-019:** Editar kit preservando sus usos históricos.

---

## 1. Principios de Arquitectura y Buen Código Aplicados

1. **Responsabilidad Única (SRP):**
   - Dominio independiente para Kits (`app/lib/features/kits`).
   - Validadores puros aislados en `kit_validadores.dart` (probados unitariamente con 100% de cobertura en tests).
   - Datos e interactividad separados en ViewModel/Repository y vistas.
2. **No Hardcoding (Cero código duro):**
   - Catálogo de áreas cargado dinámicamente desde `public.areas`.
   - Catálogo de medicamentos cargado dinámicamente desde `public.medicamentos`.
   - Reglas y permisos gobernados por PostgreSQL y Supabase Auth.
3. **Transaccionalidad Atómica y Cero Operaciones Parciales:**
   - La función PostgreSQL `administrar_kit_hu018` ejecuta en una única transacción la cabecera del kit, sus ítems en `kit_items` y el registro de auditoría en `auditoria_trazabilidad`. Si algo falla, se ejecuta rollback total.
4. **Preservación Estricta de Historial Clínico (Regla Clave HU-019):**
   - La edición de una plantilla de kit (`kits` + `kit_items`) **no altera las dispensaciones pasadas**. Las dispensaciones existentes en `dispensaciones` conservan los ítems que fueron copiados al momento de solicitarse (`dispensacion_items`).
   - Se bloquea la eliminación física (`p_accion = 'ELIMINAR'`) si el kit tiene fichas asociadas en `public.dispensaciones`, orientando al usuario a deshabilitarlo.

---

## 2. Contrato de la Base de Datos

### Tablas Involucradas

- `public.kits`:
  - `id` (UUID PK)
  - `nombre` (TEXT NOT NULL, 3-120 caracteres, único por área)
  - `descripcion` (TEXT, propósito clínico)
  - `area_destino` (TEXT NOT NULL, FK a `areas.codigo`)
  - `activo` (BOOLEAN NOT NULL DEFAULT true)
  - `created_at` (TIMESTAMPTZ)
  - `updated_at` (TIMESTAMPTZ)
- `public.kit_items`:
  - `id` (UUID PK)
  - `kit_id` (UUID FK a `kits.id` ON DELETE CASCADE)
  - `medicamento_id` (UUID FK a `medicamentos.id`)
  - `cantidad` (INT CHECK (cantidad > 0))
  - `CONSTRAINT uq_kit_medicamento UNIQUE (kit_id, medicamento_id)`

### Funciones Stored Procedure (RPC)

1. `public.listar_kits_hu017(p_area TEXT, p_solo_activos BOOLEAN)`:
   - Devuelve la lista de kits con el total de ítems y la lista JSON completa de sus medicamentos, respetando las restricciones de RLS (Enfermería solo ve los kits de sus áreas asignadas).
2. `public.administrar_kit_hu018(p_accion TEXT, p_id UUID, p_datos JSONB)`:
   - Acciones soportadas: `GUARDAR` (alta y edición), `ESTADO` (habilitar/inhabilitar), `ELIMINAR` (solo si no tiene usos históricos).
   - Genera auditoría hospitalaria en `public.auditoria_trazabilidad`.

---

## 3. Guía de Ejecución y Pruebas

### Paso 1: Ejecutar la Migración en Supabase

Ejecutar el archivo `docs/supabase/migracion_hu017_hu018_hu019_kits_2026_10_22.sql` en el SQL Editor de la consola de Supabase.

### Paso 2: Validación Manual de Casos de Uso

1. **HU-017 (Listado y filtros):**
   - Ingresar a la app como Administrador o Jefatura.
   - Navegar al menú de Administración -> "Plantillas de kits".
   - Verificar que se muestran los kits prearmados (ej: Kit Cirugía General, Kit RCP, etc.).
   - Filtrar por estado ("Activos", "Inactivos") y por área ("SOP", "COCHE_PAROS", "EMERGENCIA").
   - Buscar por texto y comprobar que la lista responde en tiempo real.
   - Tocar en un kit para expandir la lista de insumos y cantidades requeridas.
2. **HU-017 (Inhabilitación controlada):**
   - En un kit activo, presionar el switch o botón de inhabilitar.
   - Confirmar en el diálogo modal.
   - Verificar que el kit pasa a estado "Inactivo" con badge gris y no se ofrece en nuevos pedidos.
3. **HU-018 (Creación de Kit):**
   - Presionar el botón flotante (+) para crear kit.
   - Probar validaciones: intentar guardar sin nombre o sin insumos (debe mostrar errores descriptivos).
   - Seleccionar un área destino del combo dinámico.
   - Presionar "Agregar Insumo", buscar un medicamento del catálogo y fijar cantidad.
   - Guardar y confirmar que aparece en la lista con sus datos reales.
4. **HU-019 (Edición de Kit):**
   - Tocar el botón de editar en una tarjeta de kit.
   - Modificar descripción, agregar un nuevo producto y cambiar la cantidad de otro.
   - Guardar los cambios.
   - Comprobar que los cambios se reflejan inmediatamente en la plantilla sin afectar fichas previas.
