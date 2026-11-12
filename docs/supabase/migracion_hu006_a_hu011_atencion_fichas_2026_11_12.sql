-- =============================================================================
-- SITRA-Luz · Migración incremental Sprint 7 (Semana 4)
-- HU-006: Listado de fichas de pedido con filtros dinámicos y permisos por rol/área
-- HU-007: Detalle completo de ficha, desglose por lotes FEFO e historial de auditoría
-- HU-008: Máquina de estados de preparación y despacho (SOLICITADO -> EN_PREPARACION -> LISTO_PARA_RECOJO -> ENTREGADO)
-- HU-009: Registro de cantidades despachadas reales y observaciones por ítem (despacho parcial justificado)
-- HU-010: Confirmación de entrega con descuento único y atómico por lote FEFO en FARMACIA
-- HU-011: Anulación de ficha con motivo obligatorio, permisos según estado y contra-asiento por lote sin borrar movimientos
-- Refinamiento HU-025: Contrato SQL de Kardex por medicamento y lote alimentado por el recorrido de fichas
-- Fecha: 2026-11-12
-- Responsables: Walter Salas (HU-008..HU-011) y David Anampa (HU-006, HU-007, contrato HU-025)
-- Idempotente: puede ejecutarse varias veces sobre una base existente.
-- =============================================================================

BEGIN;

-- =============================================================================
-- 0. FUNCIÓN AUXILIAR DE PERTENENCIA Y PERMISO POR ÁREA (sitra_usuario_tiene_area)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.sitra_usuario_tiene_area(p_area TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.activo = true
      AND (
        p.rol IN ('ADMINISTRADOR', 'FARMACIA', 'JEFATURA_FARMACIA', 'ALMACEN')
        OR upper(btrim(COALESCE(p_area, ''))) = ANY(COALESCE(p.areas_asignadas, '{}'))
        OR EXISTS (
          SELECT 1
          FROM public.profile_areas pa
          JOIN public.areas a ON a.id = pa.area_id
          WHERE pa.profile_id = p.id
            AND upper(btrim(a.codigo)) = upper(btrim(COALESCE(p_area, '')))
            AND a.activo = true
        )
      )
  );
$$;

REVOKE ALL ON FUNCTION public.sitra_usuario_tiene_area(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sitra_usuario_tiene_area(TEXT) TO authenticated;

-- =============================================================================
-- 1. EXTENSIÓN DE COLUMNAS EN public.dispensaciones Y public.dispensacion_items
-- =============================================================================

ALTER TABLE public.dispensaciones
  ADD COLUMN IF NOT EXISTS tipo_ficha TEXT NOT NULL DEFAULT 'GENERAL',
  ADD COLUMN IF NOT EXISTS turno TEXT NOT NULL DEFAULT 'DIA',
  ADD COLUMN IF NOT EXISTS procedencia TEXT,
  ADD COLUMN IF NOT EXISTS procedencia_detalle TEXT,
  ADD COLUMN IF NOT EXISTS madre_nombre TEXT,
  ADD COLUMN IF NOT EXISTS habitacion TEXT,
  ADD COLUMN IF NOT EXISTS recien_nacido_apellidos TEXT,
  ADD COLUMN IF NOT EXISTS tipo_parto TEXT,
  ADD COLUMN IF NOT EXISTS doctor_nombre TEXT,
  ADD COLUMN IF NOT EXISTS receptor_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS tipo_atencion TEXT NOT NULL DEFAULT 'PARTICULAR',
  ADD COLUMN IF NOT EXISTS financiamiento_id UUID REFERENCES public.financiamientos(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS financiamiento_nombre_aplicado TEXT,
  ADD COLUMN IF NOT EXISTS preparado_por UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS fecha_preparacion TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_listo_recojo TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notas_farmacia TEXT,
  ADD COLUMN IF NOT EXISTS observacion_entrega TEXT,
  ADD COLUMN IF NOT EXISTS anulado_por UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS motivo_anulacion TEXT,
  ADD COLUMN IF NOT EXISTS fecha_anulacion TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS operacion_atencion_id UUID,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE public.dispensacion_items
  ADD COLUMN IF NOT EXISTS categoria_item TEXT NOT NULL DEFAULT 'MEDICAMENTO',
  ADD COLUMN IF NOT EXISTS origen_kit BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS precio_kairos_aplicado NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS porcentaje_descuento_aplicado NUMERIC(5, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS precio_unitario_aplicado NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS observacion_item TEXT,
  ADD COLUMN IF NOT EXISTS costo_unitario_aplicado NUMERIC(12, 2);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chk_dispensacion_items_costo_no_negativo'
      AND conrelid = 'public.dispensacion_items'::regclass
  ) THEN
    ALTER TABLE public.dispensacion_items
      ADD CONSTRAINT chk_dispensacion_items_costo_no_negativo
      CHECK (costo_unitario_aplicado IS NULL OR costo_unitario_aplicado >= 0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_dispensaciones_estado_fecha
  ON public.dispensaciones(estado, fecha_creacion DESC);

CREATE INDEX IF NOT EXISTS idx_dispensaciones_prioridad_estado
  ON public.dispensaciones(prioridad, estado, fecha_creacion DESC);

CREATE INDEX IF NOT EXISTS idx_dispensaciones_operacion_atencion
  ON public.dispensaciones(operacion_atencion_id)
  WHERE operacion_atencion_id IS NOT NULL;

-- =============================================================================
-- 2. TABLA DE DESGLOSE POR LOTE DESPACHADO (HU-010, HU-011 y KARDEX HU-025)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.dispensacion_item_lotes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dispensacion_id UUID NOT NULL REFERENCES public.dispensaciones(id) ON DELETE CASCADE,
  dispensacion_item_id UUID NOT NULL REFERENCES public.dispensacion_items(id) ON DELETE CASCADE,
  medicamento_id UUID NOT NULL REFERENCES public.medicamentos(id) ON DELETE RESTRICT,
  lote_id UUID NOT NULL REFERENCES public.lotes(id) ON DELETE RESTRICT,
  cantidad INTEGER NOT NULL CHECK (cantidad > 0),
  cantidad_reingresada INTEGER NOT NULL DEFAULT 0 CHECK (cantidad_reingresada >= 0 AND cantidad_reingresada <= cantidad),
  costo_compra_lote NUMERIC(12, 2) CHECK (costo_compra_lote IS NULL OR costo_compra_lote >= 0),
  precio_venta_lote NUMERIC(12, 2) CHECK (precio_venta_lote IS NULL OR precio_venta_lote >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  reingresado_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_disp_item_lotes_dispensacion
  ON public.dispensacion_item_lotes(dispensacion_id);

CREATE INDEX IF NOT EXISTS idx_disp_item_lotes_item
  ON public.dispensacion_item_lotes(dispensacion_item_id);

CREATE INDEX IF NOT EXISTS idx_disp_item_lotes_medicamento_created
  ON public.dispensacion_item_lotes(medicamento_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_disp_item_lotes_lote
  ON public.dispensacion_item_lotes(lote_id);

ALTER TABLE public.dispensacion_item_lotes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS disp_item_lotes_select_authenticated ON public.dispensacion_item_lotes;
CREATE POLICY disp_item_lotes_select_authenticated
  ON public.dispensacion_item_lotes
  FOR SELECT TO authenticated
  USING (
    public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
    OR (
      public.sitra_rol_actual() = 'ENFERMERIA'
      AND EXISTS (
        SELECT 1
        FROM public.dispensaciones d
        WHERE d.id = dispensacion_item_lotes.dispensacion_id
          AND (
            public.sitra_usuario_tiene_area(d.area_origen)
            OR d.solicitado_por = auth.uid()
          )
      )
    )
  );

REVOKE INSERT, UPDATE, DELETE ON public.dispensacion_item_lotes FROM authenticated, anon;

-- =============================================================================
-- 3. ACTUALIZAR RLS DE LECTURA EN public.dispensaciones Y public.dispensacion_items
--    PARA PERMITIR SUPERVISIÓN Y CONSULTA SEGÚN ROL/ÁREA (HU-006 / HU-007)
-- =============================================================================

DROP POLICY IF EXISTS dispensaciones_select_authenticated ON public.dispensaciones;
CREATE POLICY dispensaciones_select_authenticated
  ON public.dispensaciones
  FOR SELECT TO authenticated
  USING (
    public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
    OR (
      public.sitra_rol_actual() = 'ENFERMERIA'
      AND (
        public.sitra_usuario_tiene_area(area_origen)
        OR solicitado_por = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS dispensacion_items_select_authenticated ON public.dispensacion_items;
CREATE POLICY dispensacion_items_select_authenticated
  ON public.dispensacion_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.dispensaciones d
      WHERE d.id = dispensacion_items.dispensacion_id
        AND (
          public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
          OR (
            public.sitra_rol_actual() = 'ENFERMERIA'
            AND (
              public.sitra_usuario_tiene_area(d.area_origen)
              OR d.solicitado_por = auth.uid()
            )
          )
        )
    )
  );

-- =============================================================================
-- 4. RPC: LISTADO DE FICHAS CON FILTROS DINÁMICOS (HU-006 — David Anampa)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.listar_fichas_hu006(
  p_area TEXT DEFAULT NULL,
  p_estado TEXT DEFAULT NULL,
  p_tipo_ficha TEXT DEFAULT NULL,
  p_prioridad TEXT DEFAULT NULL,
  p_turno TEXT DEFAULT NULL,
  p_busqueda TEXT DEFAULT NULL,
  p_limite INTEGER DEFAULT 80
) RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_rol TEXT := public.sitra_rol_actual();
  v_uid UUID := auth.uid();
  v_area TEXT := NULLIF(upper(btrim(COALESCE(p_area, ''))), '');
  v_estado TEXT := NULLIF(upper(btrim(COALESCE(p_estado, ''))), '');
  v_tipo_ficha TEXT := NULLIF(upper(btrim(COALESCE(p_tipo_ficha, ''))), '');
  v_prioridad TEXT := NULLIF(upper(btrim(COALESCE(p_prioridad, ''))), '');
  v_turno TEXT := NULLIF(upper(btrim(COALESCE(p_turno, ''))), '');
  v_busqueda TEXT := NULLIF(btrim(COALESCE(p_busqueda, '')), '');
  v_limite INTEGER := LEAST(GREATEST(COALESCE(p_limite, 80), 1), 300);
  v_resultado JSONB;
BEGIN
  IF v_uid IS NULL OR v_rol IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión para consultar las fichas de pedido.' USING ERRCODE = '42501';
  END IF;

  IF v_rol = 'ENFERMERIA' AND v_area IS NOT NULL AND v_area <> 'TODAS' THEN
    IF NOT public.sitra_usuario_tiene_area(v_area) THEN
      RAISE EXCEPTION 'No tienes permiso para consultar fichas del área %.', v_area USING ERRCODE = '42501';
    END IF;
  END IF;

  WITH stock_farmacia AS (
    SELECT
      l.medicamento_id,
      COALESCE(SUM(s.cantidad), 0)::INTEGER AS farmacia_disponible
    FROM public.inventario_stock s
    JOIN public.lotes l ON l.id = s.lote_id
    WHERE s.area_codigo = 'FARMACIA'
      AND s.cantidad > 0
      AND l.activo = true
      AND l.fecha_vencimiento >= CURRENT_DATE
    GROUP BY l.medicamento_id
  ),
  fichas_filtradas AS (
    SELECT
      d.*,
      COALESCE(a.nombre, d.area_origen) AS area_nombre,
      COALESCE(a.tema_color, 'AZUL') AS area_tema_color,
      k.nombre AS kit_nombre,
      ps.nombre AS solicitado_por_nombre,
      pp.nombre AS preparado_por_nombre,
      pe.nombre AS entregado_por_nombre,
      pa.nombre AS anulado_por_nombre
    FROM public.dispensaciones d
    LEFT JOIN public.areas a ON a.codigo = d.area_origen
    LEFT JOIN public.kits k ON k.id = d.kit_id
    LEFT JOIN public.profiles ps ON ps.id = d.solicitado_por
    LEFT JOIN public.profiles pp ON pp.id = d.preparado_por
    LEFT JOIN public.profiles pe ON pe.id = d.entregado_por
    LEFT JOIN public.profiles pa ON pa.id = d.anulado_por
    WHERE (
        v_rol IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
        OR (
          v_rol = 'ENFERMERIA'
          AND (
            public.sitra_usuario_tiene_area(d.area_origen)
            OR d.solicitado_por = v_uid
          )
        )
      )
      AND (v_area IS NULL OR v_area = 'TODAS' OR d.area_origen = v_area)
      AND (v_estado IS NULL OR v_estado = 'TODOS' OR d.estado = v_estado)
      AND (v_tipo_ficha IS NULL OR v_tipo_ficha = 'TODOS' OR d.tipo_ficha = v_tipo_ficha)
      AND (v_prioridad IS NULL OR v_prioridad = 'TODAS' OR d.prioridad = v_prioridad)
      AND (v_turno IS NULL OR v_turno = 'TODOS' OR d.turno = v_turno)
      AND (
        v_busqueda IS NULL
        OR COALESCE(d.numero_ficha, '') ILIKE '%' || v_busqueda || '%'
        OR COALESCE(d.paciente_nombre, '') ILIKE '%' || v_busqueda || '%'
        OR COALESCE(d.madre_nombre, '') ILIKE '%' || v_busqueda || '%'
        OR COALESCE(d.recien_nacido_apellidos, '') ILIKE '%' || v_busqueda || '%'
        OR COALESCE(d.doctor_nombre, '') ILIKE '%' || v_busqueda || '%'
        OR COALESCE(d.recibido_por, '') ILIKE '%' || v_busqueda || '%'
        OR COALESCE(d.diagnostico_motivo, '') ILIKE '%' || v_busqueda || '%'
        OR COALESCE(k.nombre, '') ILIKE '%' || v_busqueda || '%'
      )
    ORDER BY d.fecha_creacion DESC, d.id DESC
    LIMIT v_limite
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', f.id,
        'numero_ficha', f.numero_ficha,
        'tipo', f.tipo,
        'tipo_ficha', f.tipo_ficha,
        'kit_id', f.kit_id,
        'kit_nombre', f.kit_nombre,
        'area_origen', f.area_origen,
        'area_nombre', f.area_nombre,
        'area_tema_color', f.area_tema_color,
        'turno', f.turno,
        'prioridad', f.prioridad,
        'estado', f.estado,
        'tipo_atencion', f.tipo_atencion,
        'financiamiento_id', f.financiamiento_id,
        'financiamiento_nombre_aplicado', f.financiamiento_nombre_aplicado,
        'doctor_id', f.doctor_id,
        'doctor_nombre', f.doctor_nombre,
        'receptor_id', f.receptor_id,
        'recibido_por', f.recibido_por,
        'paciente_nombre', f.paciente_nombre,
        'procedencia', f.procedencia,
        'procedencia_detalle', f.procedencia_detalle,
        'diagnostico_motivo', f.diagnostico_motivo,
        'madre_nombre', f.madre_nombre,
        'habitacion', f.habitacion,
        'recien_nacido_apellidos', f.recien_nacido_apellidos,
        'tipo_parto', f.tipo_parto,
        'observaciones', f.observaciones,
        'notas_farmacia', f.notas_farmacia,
        'observacion_entrega', f.observacion_entrega,
        'solicitado_por', f.solicitado_por,
        'solicitado_por_nombre', f.solicitado_por_nombre,
        'preparado_por', f.preparado_por,
        'preparado_por_nombre', f.preparado_por_nombre,
        'entregado_por', f.entregado_por,
        'entregado_por_nombre', f.entregado_por_nombre,
        'anulado_por', f.anulado_por,
        'anulado_por_nombre', f.anulado_por_nombre,
        'motivo_anulacion', f.motivo_anulacion,
        'fecha_creacion', f.fecha_creacion,
        'fecha_preparacion', f.fecha_preparacion,
        'fecha_listo_recojo', f.fecha_listo_recojo,
        'fecha_entrega', f.fecha_entrega,
        'fecha_anulacion', f.fecha_anulacion,
        'updated_at', f.updated_at,
        'items', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', di.id,
              'medicamento_id', di.medicamento_id,
              'nombre_comercial', m.nombre_comercial,
              'principio_activo', m.principio_activo,
              'presentacion', m.presentacion,
              'laboratorio', m.laboratorio,
              'unidad', m.unidad_presentacion,
              'categoria_item', di.categoria_item,
              'cantidad_solicitada', di.cantidad_solicitada,
              'cantidad_entregada', di.cantidad_entregada,
              'observacion_item', di.observacion_item,
              'origen_kit', di.origen_kit,
              'precio_kairos_aplicado', di.precio_kairos_aplicado,
              'porcentaje_descuento_aplicado', di.porcentaje_descuento_aplicado,
              'precio_unitario_aplicado', di.precio_unitario_aplicado,
              'costo_unitario_aplicado', di.costo_unitario_aplicado,
              'farmacia_disponible', COALESCE(sf.farmacia_disponible, 0)
            )
            ORDER BY di.categoria_item ASC, m.nombre_comercial ASC
          )
          FROM public.dispensacion_items di
          JOIN public.medicamentos m ON m.id = di.medicamento_id
          LEFT JOIN stock_farmacia sf ON sf.medicamento_id = di.medicamento_id
          WHERE di.dispensacion_id = f.id
        ), '[]'::JSONB)
      )
      ORDER BY f.fecha_creacion DESC, f.id DESC
    ),
    '[]'::JSONB
  ) INTO v_resultado
  FROM fichas_filtradas f;

  RETURN v_resultado;
END;
$$;

REVOKE ALL ON FUNCTION public.listar_fichas_hu006(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.listar_fichas_hu006(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER) TO authenticated;

-- =============================================================================
-- 5. RPC: DETALLE COMPLETO E HISTORIAL DE AUDITORÍA DE FICHA (HU-007 — David Anampa)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.obtener_detalle_ficha_hu007(
  p_ficha_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_rol TEXT := public.sitra_rol_actual();
  v_uid UUID := auth.uid();
  v_ficha RECORD;
  v_items JSONB;
  v_historial JSONB;
BEGIN
  IF v_uid IS NULL OR v_rol IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión para consultar el detalle de la ficha.' USING ERRCODE = '42501';
  END IF;

  IF p_ficha_id IS NULL THEN
    RAISE EXCEPTION 'Identificador de ficha inválido.';
  END IF;

  SELECT
    d.*,
    COALESCE(a.nombre, d.area_origen) AS area_nombre,
    COALESCE(a.tema_color, 'AZUL') AS area_tema_color,
    k.nombre AS kit_nombre,
    ps.nombre AS solicitado_por_nombre,
    pp.nombre AS preparado_por_nombre,
    pe.nombre AS entregado_por_nombre,
    pa.nombre AS anulado_por_nombre
  INTO v_ficha
  FROM public.dispensaciones d
  LEFT JOIN public.areas a ON a.codigo = d.area_origen
  LEFT JOIN public.kits k ON k.id = d.kit_id
  LEFT JOIN public.profiles ps ON ps.id = d.solicitado_por
  LEFT JOIN public.profiles pp ON pp.id = d.preparado_por
  LEFT JOIN public.profiles pe ON pe.id = d.entregado_por
  LEFT JOIN public.profiles pa ON pa.id = d.anulado_por
  WHERE d.id = p_ficha_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La ficha solicitada no existe.';
  END IF;

  IF v_rol = 'ENFERMERIA'
     AND NOT public.sitra_usuario_tiene_area(v_ficha.area_origen)
     AND v_ficha.solicitado_por IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'No tienes permiso para ver esta ficha del área %.', v_ficha.area_origen USING ERRCODE = '42501';
  END IF;

  WITH stock_farmacia AS (
    SELECT
      l.medicamento_id,
      COALESCE(SUM(s.cantidad), 0)::INTEGER AS farmacia_disponible
    FROM public.inventario_stock s
    JOIN public.lotes l ON l.id = s.lote_id
    WHERE s.area_codigo = 'FARMACIA'
      AND s.cantidad > 0
      AND l.activo = true
      AND l.fecha_vencimiento >= CURRENT_DATE
    GROUP BY l.medicamento_id
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', di.id,
        'medicamento_id', di.medicamento_id,
        'nombre_comercial', m.nombre_comercial,
        'principio_activo', m.principio_activo,
        'presentacion', m.presentacion,
        'laboratorio', m.laboratorio,
        'unidad', m.unidad_presentacion,
        'categoria_item', di.categoria_item,
        'cantidad_solicitada', di.cantidad_solicitada,
        'cantidad_entregada', di.cantidad_entregada,
        'observacion_item', di.observacion_item,
        'origen_kit', di.origen_kit,
        'precio_kairos_aplicado', di.precio_kairos_aplicado,
        'porcentaje_descuento_aplicado', di.porcentaje_descuento_aplicado,
        'precio_unitario_aplicado', di.precio_unitario_aplicado,
        'costo_unitario_aplicado', di.costo_unitario_aplicado,
        'farmacia_disponible', COALESCE(sf.farmacia_disponible, 0),
        'lotes_despachados', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', dil.id,
              'lote_id', dil.lote_id,
              'numero_lote', l.numero_lote,
              'fecha_vencimiento', l.fecha_vencimiento,
              'cantidad', dil.cantidad,
              'cantidad_reingresada', dil.cantidad_reingresada,
              'costo_compra_lote', dil.costo_compra_lote,
              'precio_venta_lote', dil.precio_venta_lote,
              'created_at', dil.created_at,
              'reingresado_at', dil.reingresado_at
            )
            ORDER BY l.fecha_vencimiento ASC, dil.created_at ASC
          )
          FROM public.dispensacion_item_lotes dil
          JOIN public.lotes l ON l.id = dil.lote_id
          WHERE dil.dispensacion_item_id = di.id
        ), '[]'::JSONB)
      )
      ORDER BY di.categoria_item ASC, m.nombre_comercial ASC
    ),
    '[]'::JSONB
  ) INTO v_items
  FROM public.dispensacion_items di
  JOIN public.medicamentos m ON m.id = di.medicamento_id
  LEFT JOIN stock_farmacia sf ON sf.medicamento_id = di.medicamento_id
  WHERE di.dispensacion_id = p_ficha_id;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', a.id,
        'tipo_evento', a.tipo_evento,
        'fecha_evento', a.fecha,
        'usuario_id', a.usuario_id,
        'usuario_nombre', COALESCE(u.nombre, 'Sistema'),
        'usuario_rol', u.rol,
        'area_origen', a.area_origen,
        'area_destino', a.area_destino,
        'medicamento_id', a.medicamento_id,
        'medicamento_nombre', m.nombre_comercial,
        'lote_id', a.lote_id,
        'numero_lote', l.numero_lote,
        'cantidad', a.cantidad,
        'descripcion', a.descripcion,
        'detalles_extra', a.detalles_extra
      )
      ORDER BY a.fecha ASC, a.id ASC
    ),
    '[]'::JSONB
  ) INTO v_historial
  FROM public.auditoria_trazabilidad a
  LEFT JOIN public.profiles u ON u.id = a.usuario_id
  LEFT JOIN public.medicamentos m ON m.id = a.medicamento_id
  LEFT JOIN public.lotes l ON l.id = a.lote_id
  WHERE (a.tabla_referencia = 'dispensaciones' AND a.entidad_referencia_id = p_ficha_id)
     OR (a.detalles_extra->>'ficha_id' = p_ficha_id::text);

  RETURN jsonb_build_object(
    'id', v_ficha.id,
    'numero_ficha', v_ficha.numero_ficha,
    'tipo', v_ficha.tipo,
    'tipo_ficha', v_ficha.tipo_ficha,
    'kit_id', v_ficha.kit_id,
    'kit_nombre', v_ficha.kit_nombre,
    'area_origen', v_ficha.area_origen,
    'area_nombre', v_ficha.area_nombre,
    'area_tema_color', v_ficha.area_tema_color,
    'turno', v_ficha.turno,
    'prioridad', v_ficha.prioridad,
    'estado', v_ficha.estado,
    'tipo_atencion', v_ficha.tipo_atencion,
    'financiamiento_id', v_ficha.financiamiento_id,
    'financiamiento_nombre_aplicado', v_ficha.financiamiento_nombre_aplicado,
    'doctor_id', v_ficha.doctor_id,
    'doctor_nombre', v_ficha.doctor_nombre,
    'receptor_id', v_ficha.receptor_id,
    'recibido_por', v_ficha.recibido_por,
    'paciente_nombre', v_ficha.paciente_nombre,
    'procedencia', v_ficha.procedencia,
    'procedencia_detalle', v_ficha.procedencia_detalle,
    'diagnostico_motivo', v_ficha.diagnostico_motivo,
    'madre_nombre', v_ficha.madre_nombre,
    'habitacion', v_ficha.habitacion,
    'recien_nacido_apellidos', v_ficha.recien_nacido_apellidos,
    'tipo_parto', v_ficha.tipo_parto,
    'observaciones', v_ficha.observaciones,
    'notas_farmacia', v_ficha.notas_farmacia,
    'observacion_entrega', v_ficha.observacion_entrega,
    'solicitado_por', v_ficha.solicitado_por,
    'solicitado_por_nombre', v_ficha.solicitado_por_nombre,
    'preparado_por', v_ficha.preparado_por,
    'preparado_por_nombre', v_ficha.preparado_por_nombre,
    'entregado_por', v_ficha.entregado_por,
    'entregado_por_nombre', v_ficha.entregado_por_nombre,
    'anulado_por', v_ficha.anulado_por,
    'anulado_por_nombre', v_ficha.anulado_por_nombre,
    'motivo_anulacion', v_ficha.motivo_anulacion,
    'fecha_creacion', v_ficha.fecha_creacion,
    'fecha_preparacion', v_ficha.fecha_preparacion,
    'fecha_listo_recojo', v_ficha.fecha_listo_recojo,
    'fecha_entrega', v_ficha.fecha_entrega,
    'fecha_anulacion', v_ficha.fecha_anulacion,
    'updated_at', v_ficha.updated_at,
    'items', v_items,
    'historial', v_historial
  );
END;
$$;

REVOKE ALL ON FUNCTION public.obtener_detalle_ficha_hu007(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.obtener_detalle_ficha_hu007(UUID) TO authenticated;

-- =============================================================================
-- 6. RPC TRANSACCIONAL DE ATENCIÓN, DESPACHO PARCIAL, ENTREGA FEFO Y ANULACIÓN
--    (HU-008, HU-009, HU-010, HU-011 — Walter Salas)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.procesar_ficha_dispensacion_hu008_hu011(
  p_operacion_id UUID,
  p_ficha_id UUID,
  p_accion TEXT,
  p_items JSONB DEFAULT '[]'::JSONB,
  p_notas TEXT DEFAULT NULL,
  p_motivo TEXT DEFAULT NULL,
  p_receptor_id UUID DEFAULT NULL,
  p_recibido_por TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_usuario UUID := auth.uid();
  v_rol TEXT := public.sitra_rol_actual();
  v_accion TEXT := upper(btrim(COALESCE(p_accion, '')));
  v_notas TEXT := NULLIF(btrim(COALESCE(p_notas, '')), '');
  v_motivo TEXT := NULLIF(btrim(COALESCE(p_motivo, '')), '');
  v_ficha public.dispensaciones%ROWTYPE;
  v_estado_anterior TEXT;
  v_item_json JSONB;
  v_item_id UUID;
  v_med_id UUID;
  v_cant_entregada INTEGER;
  v_obs_item TEXT;
  v_item_row RECORD;
  v_stock_disp INTEGER;
  v_total_entregado INTEGER := 0;
  v_total_solicitado INTEGER := 0;
  v_receptor_id UUID;
  v_recibido_por TEXT;
  v_receptor public.profiles%ROWTYPE;
  v_restante INTEGER;
  v_tomar INTEGER;
  v_costo_acumulado NUMERIC(14, 4);
  v_stock_lote RECORD;
  v_lote_desp RECORD;
  v_devolver INTEGER;
  v_unidades_reingresadas INTEGER := 0;
  v_lotes_afectados INTEGER := 0;
BEGIN
  IF v_usuario IS NULL OR v_rol IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión con un perfil activo para operar fichas.' USING ERRCODE = '42501';
  END IF;

  IF p_operacion_id IS NULL THEN
    RAISE EXCEPTION 'Falta el identificador de operación (idempotencia contra doble pulsación).';
  END IF;

  IF p_ficha_id IS NULL THEN
    RAISE EXCEPTION 'Identificador de ficha inválido.';
  END IF;

  IF v_accion NOT IN (
    'INICIAR_PREPARACION',
    'GUARDAR_PREPARACION',
    'MARCAR_LISTO_RECOJO',
    'CONFIRMAR_ENTREGA',
    'ANULAR_FICHA'
  ) THEN
    RAISE EXCEPTION 'Acción de atención de ficha no reconocida (%).', v_accion;
  END IF;

  -- Bloqueo transaccional por ficha para evitar condiciones de carrera y doble pulsación
  PERFORM pg_advisory_xact_lock(700811, hashtext(p_ficha_id::text));

  SELECT * INTO v_ficha
  FROM public.dispensaciones
  WHERE id = p_ficha_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La ficha seleccionada ya no existe.';
  END IF;

  -- Idempotencia: si esta misma operación ya se aplicó, devolvemos el detalle actual sin repetir efectos
  IF v_ficha.operacion_atencion_id = p_operacion_id THEN
    RETURN public.obtener_detalle_ficha_hu007(p_ficha_id);
  END IF;

  v_estado_anterior := v_ficha.estado;

  -- ===========================================================================
  -- ACCIÓN 1: INICIAR_PREPARACION (HU-008)
  -- ===========================================================================
  IF v_accion = 'INICIAR_PREPARACION' THEN
    IF v_rol NOT IN ('FARMACIA', 'ADMINISTRADOR') THEN
      RAISE EXCEPTION 'Solo Farmacia o Administración pueden iniciar la preparación de una ficha.' USING ERRCODE = '42501';
    END IF;

    IF v_ficha.estado = 'EN_PREPARACION' THEN
      RETURN public.obtener_detalle_ficha_hu007(p_ficha_id);
    END IF;

    IF v_ficha.estado <> 'SOLICITADO' THEN
      RAISE EXCEPTION 'Solo se puede iniciar la preparación de fichas en estado SOLICITADO (estado actual: %).', v_ficha.estado;
    END IF;

    -- Pre-cargar cantidad_entregada sugerida según el stock vigente en Farmacia si aún está en 0
    FOR v_item_row IN
      SELECT di.id, di.medicamento_id, di.cantidad_solicitada, di.cantidad_entregada
      FROM public.dispensacion_items di
      WHERE di.dispensacion_id = p_ficha_id
      FOR UPDATE
    LOOP
      IF v_item_row.cantidad_entregada = 0 THEN
        SELECT COALESCE(SUM(s.cantidad), 0)::INTEGER
          INTO v_stock_disp
        FROM public.inventario_stock s
        JOIN public.lotes l ON l.id = s.lote_id
        WHERE l.medicamento_id = v_item_row.medicamento_id
          AND s.area_codigo = 'FARMACIA'
          AND s.cantidad > 0
          AND l.activo = true
          AND l.fecha_vencimiento >= CURRENT_DATE;

        UPDATE public.dispensacion_items
           SET cantidad_entregada = LEAST(v_item_row.cantidad_solicitada, v_stock_disp),
               observacion_item = CASE
                 WHEN v_stock_disp < v_item_row.cantidad_solicitada AND observacion_item IS NULL
                   THEN 'Stock disponible parcial en Farmacia (' || v_stock_disp || ' de ' || v_item_row.cantidad_solicitada || ')'
                 ELSE observacion_item
               END
         WHERE id = v_item_row.id;
      END IF;
    END LOOP;

    UPDATE public.dispensaciones
       SET estado = 'EN_PREPARACION',
           preparado_por = v_usuario,
           fecha_preparacion = COALESCE(fecha_preparacion, now()),
           notas_farmacia = COALESCE(v_notas, notas_farmacia),
           operacion_atencion_id = p_operacion_id,
           updated_at = now()
     WHERE id = p_ficha_id;

    INSERT INTO public.auditoria_trazabilidad(
      tipo_evento,
      entidad_referencia_id,
      tabla_referencia,
      usuario_id,
      area_origen,
      area_destino,
      estado_anterior,
      estado_nuevo,
      descripcion,
      detalles_extra
    ) VALUES (
      'FICHA_EN_PREPARACION',
      p_ficha_id,
      'dispensaciones',
      v_usuario,
      'FARMACIA',
      v_ficha.area_origen,
      jsonb_build_object('estado', v_estado_anterior),
      jsonb_build_object('estado', 'EN_PREPARACION', 'notas_farmacia', v_notas),
      'Inicio de preparación en Farmacia de la ficha ' || v_ficha.numero_ficha,
      jsonb_build_object(
        'ficha_id', p_ficha_id,
        'numero_ficha', v_ficha.numero_ficha,
        'operacion_id', p_operacion_id
      )
    );

    RETURN public.obtener_detalle_ficha_hu007(p_ficha_id);
  END IF;

  -- ===========================================================================
  -- ACCIÓN 2: GUARDAR_PREPARACION / MARCAR_LISTO_RECOJO (HU-008 y HU-009)
  -- ===========================================================================
  IF v_accion IN ('GUARDAR_PREPARACION', 'MARCAR_LISTO_RECOJO') THEN
    IF v_rol NOT IN ('FARMACIA', 'ADMINISTRADOR') THEN
      RAISE EXCEPTION 'Solo Farmacia o Administración pueden registrar cantidades despachadas y preparar fichas.' USING ERRCODE = '42501';
    END IF;

    IF v_ficha.estado NOT IN ('SOLICITADO', 'EN_PREPARACION', 'LISTO_PARA_RECOJO') THEN
      RAISE EXCEPTION 'No se puede modificar la preparación de una ficha en estado %.', v_ficha.estado;
    END IF;

    IF p_items IS NOT NULL AND jsonb_typeof(p_items) = 'array' AND jsonb_array_length(p_items) > 0 THEN
      FOR v_item_json IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_item_id := NULLIF(btrim(COALESCE(v_item_json->>'item_id', v_item_json->>'id', '')), '')::UUID;
        v_med_id := NULLIF(btrim(COALESCE(v_item_json->>'medicamento_id', '')), '')::UUID;
        v_cant_entregada := COALESCE((v_item_json->>'cantidad_entregada')::INTEGER, -1);
        v_obs_item := NULLIF(btrim(COALESCE(v_item_json->>'observacion_item', '')), '');

        SELECT di.*, m.nombre_comercial
          INTO v_item_row
        FROM public.dispensacion_items di
        JOIN public.medicamentos m ON m.id = di.medicamento_id
        WHERE di.dispensacion_id = p_ficha_id
          AND (
            (v_item_id IS NOT NULL AND di.id = v_item_id)
            OR (v_item_id IS NULL AND v_med_id IS NOT NULL AND di.medicamento_id = v_med_id)
          )
        FOR UPDATE OF di;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'Uno de los ítems enviados no pertenece a esta ficha.';
        END IF;

        IF v_cant_entregada < 0 OR v_cant_entregada > v_item_row.cantidad_solicitada THEN
          RAISE EXCEPTION 'La cantidad a despachar de "%" (%) debe estar entre 0 y % (cantidad solicitada).',
            v_item_row.nombre_comercial, v_cant_entregada, v_item_row.cantidad_solicitada;
        END IF;

        SELECT COALESCE(SUM(s.cantidad), 0)::INTEGER
          INTO v_stock_disp
        FROM public.inventario_stock s
        JOIN public.lotes l ON l.id = s.lote_id
        WHERE l.medicamento_id = v_item_row.medicamento_id
          AND s.area_codigo = 'FARMACIA'
          AND s.cantidad > 0
          AND l.activo = true
          AND l.fecha_vencimiento >= CURRENT_DATE;

        IF v_cant_entregada > v_stock_disp THEN
          RAISE EXCEPTION 'Stock insuficiente en Farmacia para "%" (a despachar: %, disponible vigente: %). Ajusta la cantidad despachada.',
            v_item_row.nombre_comercial, v_cant_entregada, v_stock_disp;
        END IF;

        IF v_cant_entregada < v_item_row.cantidad_solicitada
           AND v_obs_item IS NULL
           AND v_notas IS NULL THEN
          RAISE EXCEPTION 'El ítem "%" tiene despacho parcial (% de % solicitados). Registra una observación en el ítem indicando el motivo.',
            v_item_row.nombre_comercial, v_cant_entregada, v_item_row.cantidad_solicitada;
        END IF;

        UPDATE public.dispensacion_items
           SET cantidad_entregada = v_cant_entregada,
               observacion_item = v_obs_item
         WHERE id = v_item_row.id;
      END LOOP;
    END IF;

    -- Verificar reglas globales de los ítems antes de marcar listo para recojo
    FOR v_item_row IN
      SELECT di.*, m.nombre_comercial
      FROM public.dispensacion_items di
      JOIN public.medicamentos m ON m.id = di.medicamento_id
      WHERE di.dispensacion_id = p_ficha_id
    LOOP
      v_total_solicitado := v_total_solicitado + v_item_row.cantidad_solicitada;
      v_total_entregado := v_total_entregado + v_item_row.cantidad_entregada;

      IF v_accion = 'MARCAR_LISTO_RECOJO' THEN
        SELECT COALESCE(SUM(s.cantidad), 0)::INTEGER
          INTO v_stock_disp
        FROM public.inventario_stock s
        JOIN public.lotes l ON l.id = s.lote_id
        WHERE l.medicamento_id = v_item_row.medicamento_id
          AND s.area_codigo = 'FARMACIA'
          AND s.cantidad > 0
          AND l.activo = true
          AND l.fecha_vencimiento >= CURRENT_DATE;

        IF v_item_row.cantidad_entregada > v_stock_disp THEN
          RAISE EXCEPTION 'Stock insuficiente en Farmacia para "%" (a despachar: %, disponible vigente: %).',
            v_item_row.nombre_comercial, v_item_row.cantidad_entregada, v_stock_disp;
        END IF;

        IF v_item_row.cantidad_entregada < v_item_row.cantidad_solicitada
           AND NULLIF(btrim(COALESCE(v_item_row.observacion_item, '')), '') IS NULL
           AND v_notas IS NULL
           AND NULLIF(btrim(COALESCE(v_ficha.notas_farmacia, '')), '') IS NULL THEN
          RAISE EXCEPTION 'El ítem "%" tiene despacho parcial (% de % solicitados). Ingresa una observación justificativa.',
            v_item_row.nombre_comercial, v_item_row.cantidad_entregada, v_item_row.cantidad_solicitada;
        END IF;
      END IF;
    END LOOP;

    IF v_accion = 'MARCAR_LISTO_RECOJO' AND v_total_entregado <= 0 THEN
      RAISE EXCEPTION 'Debes despachar al menos 1 unidad en la ficha para marcarla como LISTA PARA RECOJO (si no se atenderá ningún ítem, anula la ficha con motivo).';
    END IF;

    UPDATE public.dispensaciones
       SET estado = CASE
             WHEN v_accion = 'MARCAR_LISTO_RECOJO' THEN 'LISTO_PARA_RECOJO'
             WHEN estado = 'SOLICITADO' THEN 'EN_PREPARACION'
             ELSE estado
           END,
           preparado_por = COALESCE(preparado_por, v_usuario),
           fecha_preparacion = COALESCE(fecha_preparacion, now()),
           fecha_listo_recojo = CASE
             WHEN v_accion = 'MARCAR_LISTO_RECOJO' THEN now()
             ELSE fecha_listo_recojo
           END,
           notas_farmacia = COALESCE(v_notas, notas_farmacia),
           operacion_atencion_id = p_operacion_id,
           updated_at = now()
     WHERE id = p_ficha_id;

    INSERT INTO public.auditoria_trazabilidad(
      tipo_evento,
      entidad_referencia_id,
      tabla_referencia,
      usuario_id,
      area_origen,
      area_destino,
      cantidad,
      estado_anterior,
      estado_nuevo,
      descripcion,
      detalles_extra
    ) VALUES (
      CASE WHEN v_accion = 'MARCAR_LISTO_RECOJO' THEN 'FICHA_LISTA_PARA_RECOJO' ELSE 'FICHA_DESPACHO_ACTUALIZADO' END,
      p_ficha_id,
      'dispensaciones',
      v_usuario,
      'FARMACIA',
      v_ficha.area_origen,
      v_total_entregado,
      jsonb_build_object('estado', v_estado_anterior),
      jsonb_build_object(
        'estado', CASE WHEN v_accion = 'MARCAR_LISTO_RECOJO' THEN 'LISTO_PARA_RECOJO' ELSE 'EN_PREPARACION' END,
        'total_solicitado', v_total_solicitado,
        'total_entregado', v_total_entregado,
        'notas_farmacia', COALESCE(v_notas, v_ficha.notas_farmacia)
      ),
      CASE
        WHEN v_accion = 'MARCAR_LISTO_RECOJO'
          THEN 'Ficha ' || v_ficha.numero_ficha || ' preparada y lista para recojo (' || v_total_entregado || '/' || v_total_solicitado || ' und.)'
        ELSE 'Actualización de cantidades de despacho en ficha ' || v_ficha.numero_ficha || ' (' || v_total_entregado || '/' || v_total_solicitado || ' und.)'
      END,
      jsonb_build_object(
        'ficha_id', p_ficha_id,
        'numero_ficha', v_ficha.numero_ficha,
        'operacion_id', p_operacion_id,
        'total_solicitado', v_total_solicitado,
        'total_entregado', v_total_entregado,
        'despacho_parcial', (v_total_entregado < v_total_solicitado)
      )
    );

    RETURN public.obtener_detalle_ficha_hu007(p_ficha_id);
  END IF;

  -- ===========================================================================
  -- ACCIÓN 3: CONFIRMAR_ENTREGA (HU-010 — Descuento único por lote FEFO)
  -- ===========================================================================
  IF v_accion = 'CONFIRMAR_ENTREGA' THEN
    IF v_rol NOT IN ('FARMACIA', 'ADMINISTRADOR')
       AND NOT (v_rol = 'ENFERMERIA' AND public.sitra_usuario_tiene_area(v_ficha.area_origen)) THEN
      RAISE EXCEPTION 'No tienes permiso para confirmar la entrega/recojo de esta ficha.' USING ERRCODE = '42501';
    END IF;

    IF v_ficha.estado = 'ENTREGADO' THEN
      RAISE EXCEPTION 'Esta ficha ya fue entregada anteriormente y su stock ya fue descontado.';
    END IF;

    IF v_ficha.estado NOT IN ('LISTO_PARA_RECOJO', 'EN_PREPARACION') THEN
      RAISE EXCEPTION 'La ficha debe estar en estado LISTO_PARA_RECOJO o EN_PREPARACION para confirmar la entrega (estado actual: %).', v_ficha.estado;
    END IF;

    IF v_ficha.estado = 'EN_PREPARACION' AND v_rol = 'ENFERMERIA' THEN
      RAISE EXCEPTION 'Farmacia aún no ha marcado la ficha como LISTA PARA RECOJO.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.dispensacion_item_lotes WHERE dispensacion_id = p_ficha_id) THEN
      RAISE EXCEPTION 'Esta ficha ya registra descuento de stock por lote; operación abortada para evitar doble descuento.';
    END IF;

    -- Si Farmacia/Admin envía ajustes finales de ítems al confirmar la entrega, los aplicamos primero
    IF v_rol IN ('FARMACIA', 'ADMINISTRADOR')
       AND p_items IS NOT NULL
       AND jsonb_typeof(p_items) = 'array'
       AND jsonb_array_length(p_items) > 0 THEN
      FOR v_item_json IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_item_id := NULLIF(btrim(COALESCE(v_item_json->>'item_id', v_item_json->>'id', '')), '')::UUID;
        v_med_id := NULLIF(btrim(COALESCE(v_item_json->>'medicamento_id', '')), '')::UUID;
        v_cant_entregada := COALESCE((v_item_json->>'cantidad_entregada')::INTEGER, -1);
        v_obs_item := NULLIF(btrim(COALESCE(v_item_json->>'observacion_item', '')), '');

        SELECT di.*, m.nombre_comercial
          INTO v_item_row
        FROM public.dispensacion_items di
        JOIN public.medicamentos m ON m.id = di.medicamento_id
        WHERE di.dispensacion_id = p_ficha_id
          AND (
            (v_item_id IS NOT NULL AND di.id = v_item_id)
            OR (v_item_id IS NULL AND v_med_id IS NOT NULL AND di.medicamento_id = v_med_id)
          )
        FOR UPDATE OF di;

        IF FOUND THEN
          IF v_cant_entregada < 0 OR v_cant_entregada > v_item_row.cantidad_solicitada THEN
            RAISE EXCEPTION 'La cantidad a despachar de "%" (%) debe estar entre 0 y %.',
              v_item_row.nombre_comercial, v_cant_entregada, v_item_row.cantidad_solicitada;
          END IF;

          UPDATE public.dispensacion_items
             SET cantidad_entregada = v_cant_entregada,
                 observacion_item = COALESCE(v_obs_item, observacion_item)
           WHERE id = v_item_row.id;
        END IF;
      END LOOP;
    END IF;

    -- Validar receptor que recibe la ficha
    v_receptor_id := COALESCE(p_receptor_id, v_ficha.receptor_id);
    v_recibido_por := COALESCE(NULLIF(btrim(COALESCE(p_recibido_por, '')), ''), v_ficha.recibido_por);

    IF v_receptor_id IS NOT NULL THEN
      SELECT * INTO v_receptor
      FROM public.profiles
      WHERE id = v_receptor_id;
      IF FOUND THEN
        v_recibido_por := v_receptor.nombre;
      END IF;
    END IF;

    IF v_recibido_por IS NULL OR char_length(btrim(v_recibido_por)) < 3 THEN
      RAISE EXCEPTION 'Indica el personal receptor que recibe los medicamentos e insumos.';
    END IF;

    -- Recorrer ítems, verificar totales y ejecutar descuento único FEFO por lote en FARMACIA
    FOR v_item_row IN
      SELECT
        di.*,
        m.nombre_comercial,
        m.precio_kairos
      FROM public.dispensacion_items di
      JOIN public.medicamentos m ON m.id = di.medicamento_id
      WHERE di.dispensacion_id = p_ficha_id
      ORDER BY di.id ASC
      FOR UPDATE OF di
    LOOP
      v_total_solicitado := v_total_solicitado + v_item_row.cantidad_solicitada;
      v_total_entregado := v_total_entregado + v_item_row.cantidad_entregada;

      IF v_item_row.cantidad_entregada < v_item_row.cantidad_solicitada
         AND NULLIF(btrim(COALESCE(v_item_row.observacion_item, '')), '') IS NULL
         AND v_notas IS NULL
         AND NULLIF(btrim(COALESCE(v_ficha.notas_farmacia, '')), '') IS NULL THEN
        RAISE EXCEPTION 'El ítem "%" tiene entrega parcial (% de % solicitados). Debe contar con observación justificativa.',
          v_item_row.nombre_comercial, v_item_row.cantidad_entregada, v_item_row.cantidad_solicitada;
      END IF;

      IF v_item_row.cantidad_entregada > 0 THEN
        v_restante := v_item_row.cantidad_entregada;
        v_costo_acumulado := 0;

        FOR v_stock_lote IN
          SELECT
            s.id AS stock_id,
            s.lote_id,
            s.cantidad AS cantidad_actual,
            l.numero_lote,
            l.fecha_vencimiento,
            COALESCE(l.precio_compra, 0) AS costo_lote,
            COALESCE(l.precio_venta, v_item_row.precio_unitario_aplicado, v_item_row.precio_kairos, 0) AS precio_lote
          FROM public.inventario_stock s
          JOIN public.lotes l ON l.id = s.lote_id
          WHERE l.medicamento_id = v_item_row.medicamento_id
            AND s.area_codigo = 'FARMACIA'
            AND s.cantidad > 0
            AND l.activo = true
            AND l.fecha_vencimiento >= CURRENT_DATE
          ORDER BY l.fecha_vencimiento ASC, l.created_at ASC, l.id ASC
          FOR UPDATE OF s
        LOOP
          EXIT WHEN v_restante <= 0;

          v_tomar := LEAST(v_restante, v_stock_lote.cantidad_actual);

          UPDATE public.inventario_stock
             SET cantidad = cantidad - v_tomar,
                 updated_at = now()
           WHERE id = v_stock_lote.stock_id;

          INSERT INTO public.dispensacion_item_lotes(
            dispensacion_id,
            dispensacion_item_id,
            medicamento_id,
            lote_id,
            cantidad,
            cantidad_reingresada,
            costo_compra_lote,
            precio_venta_lote
          ) VALUES (
            p_ficha_id,
            v_item_row.id,
            v_item_row.medicamento_id,
            v_stock_lote.lote_id,
            v_tomar,
            0,
            v_stock_lote.costo_lote,
            v_stock_lote.precio_lote
          );

          v_costo_acumulado := v_costo_acumulado + (v_tomar * v_stock_lote.costo_lote);
          v_restante := v_restante - v_tomar;
          v_lotes_afectados := v_lotes_afectados + 1;

          INSERT INTO public.auditoria_trazabilidad(
            tipo_evento,
            entidad_referencia_id,
            tabla_referencia,
            usuario_id,
            area_origen,
            area_destino,
            medicamento_id,
            lote_id,
            cantidad,
            descripcion,
            detalles_extra
          ) VALUES (
            'CONSUMO_FICHA_AREA',
            p_ficha_id,
            'dispensaciones',
            v_usuario,
            'FARMACIA',
            v_ficha.area_origen,
            v_item_row.medicamento_id,
            v_stock_lote.lote_id,
            v_tomar,
            'Despacho FEFO de ' || v_tomar || ' und. de ' || v_item_row.nombre_comercial || ' (Lote ' || v_stock_lote.numero_lote || ') en ficha ' || v_ficha.numero_ficha || ' hacia ' || v_ficha.area_origen,
            jsonb_build_object(
              'ficha_id', p_ficha_id,
              'numero_ficha', v_ficha.numero_ficha,
              'dispensacion_item_id', v_item_row.id,
              'tipo_ficha', v_ficha.tipo_ficha,
              'paciente_nombre', v_ficha.paciente_nombre,
              'numero_lote', v_stock_lote.numero_lote,
              'fecha_vencimiento', v_stock_lote.fecha_vencimiento,
              'costo_compra_lote', v_stock_lote.costo_lote,
              'precio_venta_lote', v_stock_lote.precio_lote,
              'precio_unitario_aplicado', v_item_row.precio_unitario_aplicado,
              'recibido_por', v_recibido_por
            )
          );
        END LOOP;

        IF v_restante > 0 THEN
          RAISE EXCEPTION 'Stock vigente insuficiente en Farmacia para "%" al momento de confirmar la entrega (faltan % unidades). Ajusta la cantidad despachada.',
            v_item_row.nombre_comercial, v_restante;
        END IF;

        UPDATE public.dispensacion_items
           SET costo_unitario_aplicado = round(v_costo_acumulado / v_item_row.cantidad_entregada, 2)
         WHERE id = v_item_row.id;
      END IF;
    END LOOP;

    IF v_total_entregado <= 0 THEN
      RAISE EXCEPTION 'No se puede confirmar la entrega con 0 unidades despachadas en total.';
    END IF;

    UPDATE public.dispensaciones
       SET estado = 'ENTREGADO',
           preparado_por = COALESCE(preparado_por, CASE WHEN v_rol IN ('FARMACIA', 'ADMINISTRADOR') THEN v_usuario ELSE NULL END),
           fecha_preparacion = COALESCE(fecha_preparacion, now()),
           fecha_listo_recojo = COALESCE(fecha_listo_recojo, now()),
           entregado_por = CASE
             WHEN v_rol IN ('FARMACIA', 'ADMINISTRADOR') THEN v_usuario
             ELSE COALESCE(entregado_por, preparado_por, v_usuario)
           END,
           receptor_id = v_receptor_id,
           recibido_por = v_recibido_por,
           observacion_entrega = COALESCE(v_notas, observacion_entrega),
           fecha_entrega = now(),
           operacion_atencion_id = p_operacion_id,
           updated_at = now()
     WHERE id = p_ficha_id;

    INSERT INTO public.auditoria_trazabilidad(
      tipo_evento,
      entidad_referencia_id,
      tabla_referencia,
      usuario_id,
      area_origen,
      area_destino,
      cantidad,
      estado_anterior,
      estado_nuevo,
      descripcion,
      detalles_extra
    ) VALUES (
      'FICHA_ENTREGADA',
      p_ficha_id,
      'dispensaciones',
      v_usuario,
      'FARMACIA',
      v_ficha.area_origen,
      v_total_entregado,
      jsonb_build_object('estado', v_estado_anterior),
      jsonb_build_object(
        'estado', 'ENTREGADO',
        'total_solicitado', v_total_solicitado,
        'total_entregado', v_total_entregado,
        'lotes_afectados', v_lotes_afectados,
        'recibido_por', v_recibido_por,
        'observacion_entrega', v_notas
      ),
      'Entrega confirmada de ficha ' || v_ficha.numero_ficha || ' a ' || v_recibido_por || ' (' || v_total_entregado || ' und. descontadas por FEFO en ' || v_lotes_afectados || ' lote(s))',
      jsonb_build_object(
        'ficha_id', p_ficha_id,
        'numero_ficha', v_ficha.numero_ficha,
        'operacion_id', p_operacion_id,
        'recibido_por', v_recibido_por,
        'receptor_id', v_receptor_id,
        'total_solicitado', v_total_solicitado,
        'total_entregado', v_total_entregado,
        'lotes_afectados', v_lotes_afectados
      )
    );

    RETURN public.obtener_detalle_ficha_hu007(p_ficha_id);
  END IF;

  -- ===========================================================================
  -- ACCIÓN 4: ANULAR_FICHA (HU-011 — Anulación con motivo y contra-asiento)
  -- ===========================================================================
  IF v_accion = 'ANULAR_FICHA' THEN
    IF v_motivo IS NULL OR char_length(v_motivo) < 5 OR char_length(v_motivo) > 500 THEN
      RAISE EXCEPTION 'Ingresa el motivo obligatorio de anulación (5 a 500 caracteres).';
    END IF;

    IF v_ficha.estado = 'CANCELADO' THEN
      RAISE EXCEPTION 'Esta ficha ya se encuentra anulada.';
    END IF;

    IF v_ficha.estado = 'SOLICITADO' THEN
      IF v_rol NOT IN ('FARMACIA', 'ADMINISTRADOR')
         AND NOT (v_rol = 'ENFERMERIA' AND (public.sitra_usuario_tiene_area(v_ficha.area_origen) OR v_ficha.solicitado_por = v_usuario)) THEN
        RAISE EXCEPTION 'No tienes permiso para anular esta ficha del área %.', v_ficha.area_origen USING ERRCODE = '42501';
      END IF;
    ELSIF v_ficha.estado IN ('EN_PREPARACION', 'LISTO_PARA_RECOJO') THEN
      IF v_rol NOT IN ('FARMACIA', 'ADMINISTRADOR') THEN
        RAISE EXCEPTION 'La ficha ya está siendo preparada por Farmacia (%). Solo Farmacia o Administración pueden anularla en este estado.', v_ficha.estado USING ERRCODE = '42501';
      END IF;
    ELSIF v_ficha.estado = 'ENTREGADO' THEN
      IF v_rol NOT IN ('FARMACIA', 'ADMINISTRADOR') THEN
        RAISE EXCEPTION 'Solo Farmacia o Administración pueden anular con contra-asiento una ficha ya entregada.' USING ERRCODE = '42501';
      END IF;

      -- Contra-asiento: reingresar cada lote descontado al stock de FARMACIA sin borrar movimientos históricos
      FOR v_lote_desp IN
        SELECT
          dil.id,
          dil.medicamento_id,
          dil.lote_id,
          dil.cantidad,
          dil.cantidad_reingresada,
          l.numero_lote,
          m.nombre_comercial
        FROM public.dispensacion_item_lotes dil
        JOIN public.lotes l ON l.id = dil.lote_id
        JOIN public.medicamentos m ON m.id = dil.medicamento_id
        WHERE dil.dispensacion_id = p_ficha_id
          AND dil.cantidad > dil.cantidad_reingresada
        ORDER BY dil.id ASC
        FOR UPDATE OF dil
      LOOP
        v_devolver := v_lote_desp.cantidad - v_lote_desp.cantidad_reingresada;

        INSERT INTO public.inventario_stock(
          lote_id,
          area_codigo,
          cantidad,
          updated_at
        ) VALUES (
          v_lote_desp.lote_id,
          'FARMACIA',
          v_devolver,
          now()
        )
        ON CONFLICT (lote_id, area_codigo)
        DO UPDATE SET
          cantidad = public.inventario_stock.cantidad + EXCLUDED.cantidad,
          updated_at = now();

        UPDATE public.dispensacion_item_lotes
           SET cantidad_reingresada = cantidad,
               reingresado_at = now()
         WHERE id = v_lote_desp.id;

        v_unidades_reingresadas := v_unidades_reingresadas + v_devolver;
        v_lotes_afectados := v_lotes_afectados + 1;

        INSERT INTO public.auditoria_trazabilidad(
          tipo_evento,
          entidad_referencia_id,
          tabla_referencia,
          usuario_id,
          area_origen,
          area_destino,
          medicamento_id,
          lote_id,
          cantidad,
          descripcion,
          detalles_extra
        ) VALUES (
          'REINGRESO_ANULACION_FICHA',
          p_ficha_id,
          'dispensaciones',
          v_usuario,
          v_ficha.area_origen,
          'FARMACIA',
          v_lote_desp.medicamento_id,
          v_lote_desp.lote_id,
          v_devolver,
          'Contra-asiento de reingreso a Farmacia de ' || v_devolver || ' und. de ' || v_lote_desp.nombre_comercial || ' (Lote ' || v_lote_desp.numero_lote || ') por anulación de ficha ' || v_ficha.numero_ficha,
          jsonb_build_object(
            'ficha_id', p_ficha_id,
            'numero_ficha', v_ficha.numero_ficha,
            'numero_lote', v_lote_desp.numero_lote,
            'motivo_anulacion', v_motivo,
            'operacion_id', p_operacion_id
          )
        );
      END LOOP;
    END IF;

    UPDATE public.dispensaciones
       SET estado = 'CANCELADO',
           anulado_por = v_usuario,
           motivo_anulacion = v_motivo,
           fecha_anulacion = now(),
           operacion_atencion_id = p_operacion_id,
           updated_at = now()
     WHERE id = p_ficha_id;

    INSERT INTO public.auditoria_trazabilidad(
      tipo_evento,
      entidad_referencia_id,
      tabla_referencia,
      usuario_id,
      area_origen,
      area_destino,
      cantidad,
      estado_anterior,
      estado_nuevo,
      descripcion,
      detalles_extra
    ) VALUES (
      CASE WHEN v_estado_anterior = 'ENTREGADO' THEN 'FICHA_ANULADA_CON_CONTRAASIENTO' ELSE 'FICHA_ANULADA' END,
      p_ficha_id,
      'dispensaciones',
      v_usuario,
      v_ficha.area_origen,
      'FARMACIA',
      CASE WHEN v_unidades_reingresadas > 0 THEN v_unidades_reingresadas ELSE NULL END,
      jsonb_build_object('estado', v_estado_anterior),
      jsonb_build_object(
        'estado', 'CANCELADO',
        'motivo_anulacion', v_motivo,
        'unidades_reingresadas', v_unidades_reingresadas,
        'lotes_reingresados', v_lotes_afectados
      ),
      CASE
        WHEN v_estado_anterior = 'ENTREGADO'
          THEN 'Anulación con contra-asiento de ficha ' || v_ficha.numero_ficha || ' (' || v_unidades_reingresadas || ' und. reingresadas a Farmacia). Motivo: ' || v_motivo
        ELSE 'Anulación de ficha ' || v_ficha.numero_ficha || ' desde estado ' || v_estado_anterior || '. Motivo: ' || v_motivo
      END,
      jsonb_build_object(
        'ficha_id', p_ficha_id,
        'numero_ficha', v_ficha.numero_ficha,
        'estado_previo', v_estado_anterior,
        'motivo_anulacion', v_motivo,
        'unidades_reingresadas', v_unidades_reingresadas,
        'lotes_reingresados', v_lotes_afectados,
        'operacion_id', p_operacion_id
      )
    );

    RETURN public.obtener_detalle_ficha_hu007(p_ficha_id);
  END IF;

  RETURN public.obtener_detalle_ficha_hu007(p_ficha_id);
END;
$$;

REVOKE ALL ON FUNCTION public.procesar_ficha_dispensacion_hu008_hu011(UUID, UUID, TEXT, JSONB, TEXT, TEXT, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.procesar_ficha_dispensacion_hu008_hu011(UUID, UUID, TEXT, JSONB, TEXT, TEXT, UUID, TEXT) TO authenticated;

-- =============================================================================
-- 7. REFINAMIENTO DEL CONTRATO DE KARDEX POR PRODUCTO (HU-025 para Sprint 8)
--    Responsable: David Anampa (validado con el flujo transaccional de Walter Salas)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.consultar_kardex_medicamento_hu025(
  p_medicamento_id UUID,
  p_limite INTEGER DEFAULT 150
) RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_rol TEXT := public.sitra_rol_actual();
  v_uid UUID := auth.uid();
  v_limite INTEGER := LEAST(GREATEST(COALESCE(p_limite, 150), 1), 500);
  v_resultado JSONB;
BEGIN
  IF v_uid IS NULL OR v_rol IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión para consultar el Kardex del producto.' USING ERRCODE = '42501';
  END IF;

  IF p_medicamento_id IS NULL THEN
    RAISE EXCEPTION 'Identificador de medicamento inválido.';
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', a.id,
        'tipo_evento', a.tipo_evento,
        'naturaleza_movimiento', CASE
          WHEN a.tipo_evento IN ('INGRESO_ALMACEN', 'REGISTRO_MEDICAMENTO_LOTE', 'INGRESO_LOTE_EXISTENTE', 'REINGRESO_ANULACION_FICHA') THEN 'ENTRADA'
          WHEN a.tipo_evento IN ('CONSUMO_FICHA_AREA', 'DISPENSACION_AREA') THEN 'SALIDA'
          WHEN a.tipo_evento IN (
            'TRANSFERENCIA_FARMACIA',
            'TRANSFERENCIA_ALMACEN_FARMACIA',
            'ENVIO_ALMACEN_A_FARMACIA',
            'CONFIRMAR_RECEPCION_FARMACIA',
            'RECHAZAR_ENVIO_FARMACIA',
            'DESPACHO_PEDIDO_ABASTECIMIENTO',
            'CONFIRMAR_RECEPCION_PEDIDO_ABASTECIMIENTO',
            'DESPACHO_PEDIDO',
            'RECEPCION_PEDIDO'
          ) THEN 'TRANSFERENCIA'
          ELSE 'AJUSTE'
        END,
        'fecha_evento', a.fecha,
        'usuario_id', a.usuario_id,
        'usuario_nombre', COALESCE(u.nombre, 'Sistema'),
        'usuario_rol', u.rol,
        'area_origen', a.area_origen,
        'area_destino', a.area_destino,
        'lote_id', a.lote_id,
        'numero_lote', COALESCE(l.numero_lote, a.detalles_extra->>'numero_lote'),
        'fecha_vencimiento', l.fecha_vencimiento,
        'cantidad', a.cantidad,
        'entidad_referencia_id', a.entidad_referencia_id,
        'tabla_referencia', a.tabla_referencia,
        'numero_ficha', a.detalles_extra->>'numero_ficha',
        'descripcion', a.descripcion,
        'detalles_extra', a.detalles_extra
      )
      ORDER BY a.fecha DESC, a.id DESC
    ),
    '[]'::JSONB
  ) INTO v_resultado
  FROM (
    SELECT *
    FROM public.auditoria_trazabilidad a
    WHERE a.medicamento_id = p_medicamento_id
    ORDER BY a.fecha DESC, a.id DESC
    LIMIT v_limite
  ) a
  LEFT JOIN public.profiles u ON u.id = a.usuario_id
  LEFT JOIN public.lotes l ON l.id = a.lote_id;

  RETURN v_resultado;
END;
$$;

REVOKE ALL ON FUNCTION public.consultar_kardex_medicamento_hu025(UUID, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.consultar_kardex_medicamento_hu025(UUID, INTEGER) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
