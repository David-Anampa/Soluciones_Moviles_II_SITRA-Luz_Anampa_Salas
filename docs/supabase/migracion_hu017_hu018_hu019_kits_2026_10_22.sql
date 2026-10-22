-- ============================================================================
-- SITRA-Luz: Migración HU-017, HU-018 y HU-019 (Kits de Áreas / Quirófano)
-- Sprint 5 · Semana 2 · Responsable: David Anampa
--
-- HU-017: Listar y habilitar/inhabilitar kits quirúrgicos y plantillas clínicas.
-- HU-018: Crear kit con área destino, insumos y cantidades predefinidas.
-- HU-019: Editar kit reutilizando el formulario y conservando sus usos históricos
--         (las dispensaciones anteriores conservan los ítems ya copiados).
-- ============================================================================

BEGIN;

-- 1. Asegurar columna updated_at en public.kits
ALTER TABLE public.kits 
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now());

-- 2. Restricción de unicidad para evitar duplicar el mismo medicamento dentro de un mismo kit
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uq_kit_medicamento' AND conrelid = 'public.kit_items'::regclass
    ) THEN
        ALTER TABLE public.kit_items 
            ADD CONSTRAINT uq_kit_medicamento UNIQUE (kit_id, medicamento_id);
    END IF;
END $$;

-- 3. Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_kits_area_destino ON public.kits(area_destino);
CREATE INDEX IF NOT EXISTS idx_kits_activo ON public.kits(activo);
CREATE INDEX IF NOT EXISTS idx_kit_items_kit_id ON public.kit_items(kit_id);
CREATE INDEX IF NOT EXISTS idx_kit_items_medicamento_id ON public.kit_items(medicamento_id);

-- ============================================================================
-- 4. RPC: listar_kits_hu017
-- Consulta enriquecida de kits con sus ítems, nombre del área y detalle de insumos.
-- Respeta RLS: Enfermería solo consulta kits de sus áreas asignadas.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.listar_kits_hu017(
    p_area TEXT DEFAULT NULL,
    p_solo_activos BOOLEAN DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    nombre TEXT,
    descripcion TEXT,
    area_destino TEXT,
    area_nombre TEXT,
    area_codigo_interno TEXT,
    activo BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    total_items BIGINT,
    items JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_rol TEXT;
    v_areas_usuario TEXT[];
BEGIN
    v_rol := public.sitra_rol_actual();
    IF v_rol IS NULL THEN
        RAISE EXCEPTION 'Usuario no autenticado o sin rol asignado.' USING ERRCODE = '42501';
    END IF;

    -- Obtener áreas de enfermería si aplica restricción
    IF v_rol = 'ENFERMERIA' THEN
        SELECT COALESCE(p.areas_asignadas, '{}') INTO v_areas_usuario
        FROM public.profiles p WHERE p.id = auth.uid();
    END IF;

    RETURN QUERY
    SELECT 
        k.id,
        k.nombre,
        k.descripcion,
        k.area_destino,
        COALESCE(a.nombre, k.area_destino) AS area_nombre,
        COALESCE(a.codigo_interno, k.area_destino) AS area_codigo_interno,
        k.activo,
        k.created_at,
        k.updated_at,
        COUNT(ki.id)::BIGINT AS total_items,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', ki.id,
                    'medicamento_id', ki.medicamento_id,
                    'nombre_comercial', m.nombre_comercial,
                    'principio_activo', m.principio_activo,
                    'presentacion', m.presentacion,
                    'laboratorio', m.laboratorio,
                    'cantidad', ki.cantidad
                ) ORDER BY m.nombre_comercial ASC
            ) FILTER (WHERE ki.id IS NOT NULL),
            '[]'::JSONB
        ) AS items
    FROM public.kits k
    LEFT JOIN public.areas a ON (a.codigo = k.area_destino)
    LEFT JOIN public.kit_items ki ON (ki.kit_id = k.id)
    LEFT JOIN public.medicamentos m ON (m.id = ki.medicamento_id)
    WHERE 
        (p_area IS NULL OR k.area_destino = p_area OR a.codigo_interno = p_area)
        AND (p_solo_activos IS NULL OR k.activo = p_solo_activos)
        AND (
            v_rol IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
            OR (v_rol = 'ENFERMERIA' AND k.area_destino = ANY(v_areas_usuario))
        )
    GROUP BY k.id, k.nombre, k.descripcion, k.area_destino, a.nombre, a.codigo_interno, k.activo, k.created_at, k.updated_at
    ORDER BY k.activo DESC, k.nombre ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.listar_kits_hu017(TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.listar_kits_hu017(TEXT, BOOLEAN) TO authenticated;

-- ============================================================================
-- 5. RPC: administrar_kit_hu018
-- Operación atómica de creación, edición, cambio de estado y eliminación de kits.
-- Regla HU-019: La edición preserva usos históricos (no muta fichas previas).
-- Bloquea eliminación si existen dispensaciones que utilizaron el kit.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.administrar_kit_hu018(
    p_accion TEXT,
    p_id UUID DEFAULT NULL,
    p_datos JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_rol TEXT;
    v_uid UUID;
    v_id UUID := p_id;
    v_nombre TEXT;
    v_descripcion TEXT;
    v_area TEXT;
    v_activo BOOLEAN;
    v_items JSONB;
    v_item JSONB;
    v_med_id UUID;
    v_cantidad INT;
    v_med_ids UUID[] := '{}';
    v_antes JSONB := NULL;
    v_despues JSONB := NULL;
    v_kit_actual public.kits%ROWTYPE;
BEGIN
    v_rol := public.sitra_rol_actual();
    v_uid := auth.uid();

    -- Solo Administrador y Jefatura de Farmacia pueden administrar plantillas de kits
    IF v_rol NOT IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA') THEN
        RAISE EXCEPTION 'No tienes permisos para administrar plantillas de kits (Rol: %).', COALESCE(v_rol, 'Sin Rol')
            USING ERRCODE = '42501';
    END IF;

    IF p_accion IS NULL OR p_accion NOT IN ('GUARDAR', 'ESTADO', 'ELIMINAR') THEN
        RAISE EXCEPTION 'Acción no válida: %. Use GUARDAR, ESTADO o ELIMINAR.', p_accion;
    END IF;

    -- ------------------------------------------------------------------------
    -- CASO 1: CAMBIO DE ESTADO (Habilitar / Inhabilitar) - HU-017
    -- ------------------------------------------------------------------------
    IF p_accion = 'ESTADO' THEN
        IF p_id IS NULL THEN
            RAISE EXCEPTION 'Se requiere el ID del kit para cambiar su estado.';
        END IF;

        IF jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN
            RAISE EXCEPTION 'El estado activo debe ser un valor booleano.';
        END IF;

        v_activo := (p_datos->>'activo')::BOOLEAN;

        SELECT * INTO v_kit_actual FROM public.kits WHERE id = p_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'El kit indicado no existe.';
        END IF;

        v_antes := to_jsonb(v_kit_actual);

        UPDATE public.kits
        SET activo = v_activo,
            updated_at = timezone('utc'::text, now())
        WHERE id = p_id
        RETURNING to_jsonb(kits.*) INTO v_despues;

        -- Registrar en auditoría de trazabilidad
        INSERT INTO public.auditoria_trazabilidad(
            tipo_evento, entidad_referencia_id, tabla_referencia, usuario_id,
            estado_anterior, estado_nuevo, descripcion
        ) VALUES (
            'KIT_ESTADO', p_id, 'kits', v_uid,
            v_antes, v_despues,
            CASE WHEN v_activo THEN 'Kit habilitado para dispensación: ' || v_kit_actual.nombre
                 ELSE 'Kit deshabilitado para dispensación (conserva historial): ' || v_kit_actual.nombre
            END
        );

        RETURN p_id;
    END IF;

    -- ------------------------------------------------------------------------
    -- CASO 2: ELIMINACIÓN CONTROLADA (Solo si no tiene fichas asociadas)
    -- ------------------------------------------------------------------------
    IF p_accion = 'ELIMINAR' THEN
        IF p_id IS NULL THEN
            RAISE EXCEPTION 'Se requiere el ID del kit para eliminar.';
        END IF;

        SELECT * INTO v_kit_actual FROM public.kits WHERE id = p_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'El kit indicado no existe.';
        END IF;

        -- Regla estricta de historial: no se puede borrar si fue usado en dispensaciones
        IF EXISTS (SELECT 1 FROM public.dispensaciones WHERE kit_id = p_id) THEN
            RAISE EXCEPTION 'El kit tiene fichas y dispensaciones históricas asociadas. No se puede eliminar físicamente; desactívalo para conservarlo en el historial clínico.';
        END IF;

        v_antes := to_jsonb(v_kit_actual);

        -- Al tener ON DELETE CASCADE en kit_items se eliminan sus ítems
        DELETE FROM public.kits WHERE id = p_id;

        INSERT INTO public.auditoria_trazabilidad(
            tipo_evento, entidad_referencia_id, tabla_referencia, usuario_id,
            estado_anterior, estado_nuevo, descripcion
        ) VALUES (
            'KIT_ELIMINADO', p_id, 'kits', v_uid,
            v_antes, NULL,
            'Kit borrador eliminado sin usos históricos: ' || v_kit_actual.nombre
        );

        RETURN p_id;
    END IF;

    -- ------------------------------------------------------------------------
    -- CASO 3: GUARDAR (Crear HU-018 / Editar HU-019)
    -- ------------------------------------------------------------------------
    IF p_accion = 'GUARDAR' THEN
        v_nombre := regexp_replace(btrim(COALESCE(p_datos->>'nombre', '')), '\s+', ' ', 'g');
        IF length(v_nombre) < 3 OR length(v_nombre) > 120 THEN
            RAISE EXCEPTION 'El nombre del kit debe tener entre 3 y 120 caracteres.';
        END IF;

        v_descripcion := NULLIF(btrim(COALESCE(p_datos->>'descripcion', '')), '');
        IF v_descripcion IS NOT NULL AND length(v_descripcion) > 300 THEN
            RAISE EXCEPTION 'La descripción no puede exceder los 300 caracteres.';
        END IF;

        v_area := upper(btrim(COALESCE(p_datos->>'area_destino', '')));
        IF v_area = '' THEN
            RAISE EXCEPTION 'Debe seleccionar el área de destino para el kit.';
        END IF;

        -- Validar que el área exista y esté activa (usando código o codigo_interno de areas)
        IF NOT EXISTS (
            SELECT 1 FROM public.areas 
            WHERE (codigo = v_area OR codigo_interno = v_area) AND activo = true
        ) THEN
            RAISE EXCEPTION 'El área destino % no existe o se encuentra inactiva.', v_area;
        END IF;

        -- Asegurar el código operativo canónico de áreas
        SELECT codigo INTO v_area FROM public.areas 
        WHERE (codigo = v_area OR codigo_interno = v_area) LIMIT 1;

        -- Validar unicidad de nombre en la misma área de destino
        IF EXISTS (
            SELECT 1 FROM public.kits 
            WHERE lower(btrim(nombre)) = lower(v_nombre)
              AND area_destino = v_area
              AND id IS DISTINCT FROM p_id
        ) THEN
            RAISE EXCEPTION 'Ya existe un kit con el nombre "%" registrado para el área %.', v_nombre, v_area;
        END IF;

        -- Validar ítems del kit
        v_items := p_datos->'items';
        IF v_items IS NULL OR jsonb_typeof(v_items) IS DISTINCT FROM 'array' OR jsonb_array_length(v_items) = 0 THEN
            RAISE EXCEPTION 'El kit debe contener al menos un medicamento o insumo con su cantidad.';
        END IF;

        -- Validar que cada ítem tenga medicamento válido y cantidad positiva, sin duplicados
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
            v_med_id := (v_item->>'medicamento_id')::UUID;
            v_cantidad := COALESCE((v_item->>'cantidad')::INT, 0);

            IF v_med_id IS NULL THEN
                RAISE EXCEPTION 'Cada ítem del kit debe especificar un medicamento válido.';
            END IF;

            IF v_cantidad <= 0 THEN
                RAISE EXCEPTION 'La cantidad para cada insumo del kit debe ser mayor a 0.';
            END IF;

            IF NOT EXISTS (SELECT 1 FROM public.medicamentos WHERE id = v_med_id AND activo = true) THEN
                RAISE EXCEPTION 'Uno de los medicamentos seleccionados no existe o está inactivo en el catálogo maestro.';
            END IF;

            IF v_med_id = ANY(v_med_ids) THEN
                RAISE EXCEPTION 'No se puede repetir el mismo medicamento más de una vez en el kit. Ajuste la cantidad en una sola fila.';
            END IF;

            v_med_ids := v_med_ids || v_med_id;
        END LOOP;

        -- --------------------------------------------------------------------
        -- INSERCIÓN O ACTUALIZACIÓN ATÓMICA
        -- --------------------------------------------------------------------
        IF p_id IS NULL THEN
            -- HU-018: Creación de nuevo kit
            v_id := gen_random_uuid();
            INSERT INTO public.kits (id, nombre, descripcion, area_destino, activo, created_at, updated_at)
            VALUES (v_id, v_nombre, v_descripcion, v_area, true, timezone('utc'::text, now()), timezone('utc'::text, now()))
            RETURNING to_jsonb(kits.*) INTO v_despues;

            -- Insertar ítems
            FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
                INSERT INTO public.kit_items (kit_id, medicamento_id, cantidad)
                VALUES (v_id, (v_item->>'medicamento_id')::UUID, (v_item->>'cantidad')::INT);
            END LOOP;

            -- Auditoría
            INSERT INTO public.auditoria_trazabilidad(
                tipo_evento, entidad_referencia_id, tabla_referencia, usuario_id,
                estado_anterior, estado_nuevo, descripcion
            ) VALUES (
                'KIT_CREADO', v_id, 'kits', v_uid,
                NULL, v_despues || jsonb_build_object('items', v_items),
                'Creación de kit prearmado: ' || v_nombre || ' para ' || v_area
            );

        ELSE
            -- HU-019: Edición de kit existente
            SELECT * INTO v_kit_actual FROM public.kits WHERE id = p_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'El kit que intenta editar no existe.';
            END IF;

            -- Capturar estado previo con sus ítems para auditoría
            SELECT to_jsonb(v_kit_actual) || jsonb_build_object(
                'items', (SELECT COALESCE(jsonb_agg(to_jsonb(ki.*)), '[]'::JSONB) FROM public.kit_items ki WHERE ki.kit_id = p_id)
            ) INTO v_antes;

            -- Actualizar cabecera del kit
            UPDATE public.kits
            SET nombre = v_nombre,
                descripcion = v_descripcion,
                area_destino = v_area,
                updated_at = timezone('utc'::text, now())
            WHERE id = p_id
            RETURNING to_jsonb(kits.*) INTO v_despues;

            -- Reemplazar ítems atómicamente en la plantilla del kit
            -- NOTA: Esto no modifica dispensaciones pasadas (dispensacion_items conserva sus copias)
            DELETE FROM public.kit_items WHERE kit_id = p_id;

            FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
                INSERT INTO public.kit_items (kit_id, medicamento_id, cantidad)
                VALUES (p_id, (v_item->>'medicamento_id')::UUID, (v_item->>'cantidad')::INT);
            END LOOP;

            -- Auditoría
            INSERT INTO public.auditoria_trazabilidad(
                tipo_evento, entidad_referencia_id, tabla_referencia, usuario_id,
                estado_anterior, estado_nuevo, descripcion
            ) VALUES (
                'KIT_ACTUALIZADO', p_id, 'kits', v_uid,
                v_antes, v_despues || jsonb_build_object('items', v_items),
                'Actualización de plantilla de kit: ' || v_nombre || ' (preserva historial de fichas)'
            );
        END IF;

        RETURN v_id;
    END IF;

    RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.administrar_kit_hu018(TEXT, UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.administrar_kit_hu018(TEXT, UUID, JSONB) TO authenticated;

-- ============================================================================
-- 6. Actualización de políticas RLS para kits y kit_items
-- ============================================================================
-- Asegurar que Jefatura de Farmacia y Farmacia puedan consultar kits y kit_items
DROP POLICY IF EXISTS hu002_kits_lectura ON public.kits;
CREATE POLICY hu002_kits_lectura ON public.kits FOR SELECT TO authenticated USING (
    public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
    OR (
        public.sitra_rol_actual() = 'ENFERMERIA' AND EXISTS (
            SELECT 1 FROM public.profiles p 
            WHERE p.id = auth.uid() AND area_destino = ANY(p.areas_asignadas)
        )
    )
);

DROP POLICY IF EXISTS hu002_kit_items_lectura ON public.kit_items;
CREATE POLICY hu002_kit_items_lectura ON public.kit_items FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.kits k WHERE k.id = kit_id)
);

COMMIT;
