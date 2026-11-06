-- Migración incremental: HU-003, HU-004 y HU-005 — Registro de fichas de pedido,
-- selección de ítems con stock real en Farmacia y aplicación de kits por área como copia independiente.
-- Fecha: 2026-11-06
-- Responsable: David Anampa (Semana 3 · Sprint 6)
-- Aplicar después de migracion_kits_por_area_2026_10_26.sql y migracion_temas_areas_2026_10_26.sql.
-- No reconstruye ni siembra la base existente. No mueve stock físico (el descuento de stock ocurre en dispensación de Farmacia, HU-006/HU-007).

BEGIN;

DO $$ BEGIN
  IF to_regprocedure('public.contexto_kits_por_area()') IS NULL THEN
    RAISE EXCEPTION 'Aplica primero migracion_kits_por_area_2026_10_26.sql.';
  END IF;
  IF to_regprocedure('public.consultar_stock_ubicaciones(text,integer,integer)') IS NULL THEN
    RAISE EXCEPTION 'Aplica primero la migración de stock separado por ubicación (HU-023).';
  END IF;
END $$;

-- 1. Clasificación de catálogo entre MEDICAMENTO y DISPOSITIVO_MEDICO (RF-003 / RF-004 / RF-015).
ALTER TABLE public.medicamentos
  ADD COLUMN IF NOT EXISTS categoria TEXT NOT NULL DEFAULT 'MEDICAMENTO';

ALTER TABLE public.medicamentos
  DROP CONSTRAINT IF EXISTS medicamentos_categoria_check;
ALTER TABLE public.medicamentos
  ADD CONSTRAINT medicamentos_categoria_check
  CHECK (categoria IN ('MEDICAMENTO', 'DISPOSITIVO_MEDICO'));

-- Clasificación inicial basada en descripción real del catálogo sin valores fijos en el cliente.
UPDATE public.medicamentos
SET categoria = 'DISPOSITIVO_MEDICO'
WHERE categoria = 'MEDICAMENTO'
  AND (
    lower(COALESCE(nombre_comercial, '') || ' ' || COALESCE(presentacion, ''))
      ~ '(jeringa|guante|gasa|cateter|catéter|sonda|aguja|esparadrapo|algodon|algodón|bisturi|bisturí|venoclisis|triple via|triple vía|mascarilla|venda|canula|cánula|aposito|apósito|sutura)'
  );

-- Sincronización de contrato HU-015 / HU-024: registrar_ingreso_lote_hu024 persiste también categoria ('MEDICAMENTO' | 'DISPOSITIVO_MEDICO')
-- y soporta recepción por escaneo GTIN de productos existentes o nuevos.
CREATE OR REPLACE FUNCTION public.registrar_ingreso_lote_hu024(
 p_operacion_id UUID,p_datos JSONB,p_medicamento JSONB DEFAULT NULL) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_actor UUID:=auth.uid();v_rol TEXT;v_med UUID;v_lote public.lotes%ROWTYPE;
 v_op RECORD;v_cantidad INTEGER;v_datos JSONB;v_numero TEXT;v_frio BOOLEAN;v_cat TEXT;
BEGIN
 SELECT rol INTO v_rol FROM public.profiles WHERE id=v_actor AND activo;
 IF v_actor IS NULL OR v_rol IS NULL OR v_rol NOT IN ('ALMACEN','ADMINISTRADOR') THEN
  RAISE EXCEPTION 'Solo Almacén puede registrar ingresos.'; END IF;
 IF p_operacion_id IS NULL OR p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' THEN RAISE EXCEPTION 'Ingreso no válido.'; END IF;
 v_datos:=jsonb_build_object('ingreso',p_datos,'medicamento',p_medicamento);
 PERFORM pg_advisory_xact_lock(hashtextextended(v_actor::text||p_operacion_id::text,0));
 SELECT * INTO v_op FROM public.operaciones_ingreso_lote WHERE usuario_id=v_actor AND operacion_id=p_operacion_id;
 IF FOUND THEN
  IF v_op.datos<>v_datos OR v_op.accion<>'INGRESO' THEN RAISE EXCEPTION 'La clave de envío corresponde a otro contenido.'; END IF;
  RETURN v_op.resultado;
 END IF;
 IF COALESCE(p_datos->>'cantidad','') !~ '^[0-9]+$' OR (p_datos->>'cantidad')::numeric NOT BETWEEN 1 AND 2147483647 THEN
  RAISE EXCEPTION 'La cantidad debe ser un entero positivo.'; END IF;
 v_cantidad:=(p_datos->>'cantidad')::integer;v_numero:=upper(btrim(p_datos->>'numero_lote'));
 IF v_numero IS NULL OR length(v_numero) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Ingrese un número de lote válido.'; END IF;
 IF p_datos->>'fecha_vencimiento' IS NULL OR (p_datos->>'fecha_vencimiento')::date<=CURRENT_DATE THEN
  RAISE EXCEPTION 'El vencimiento debe ser posterior a hoy.'; END IF;
 IF NULLIF(p_datos->>'fecha_fabricacion','')::date>(p_datos->>'fecha_vencimiento')::date THEN RAISE EXCEPTION 'Fabricación posterior al vencimiento.'; END IF;
 IF p_datos->>'justificacion' IS NULL OR p_datos->>'justificacion' NOT IN ('Compra','Donacion') THEN RAISE EXCEPTION 'Seleccione Compra o Donación.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_each(p_datos) e WHERE e.key IN ('precio_compra','precio_venta') AND e.value<>'null'
  AND (jsonb_typeof(e.value)<>'number' OR e.value::numeric<0 OR e.value::numeric>99999999.99)) THEN
  RAISE EXCEPTION 'El precio debe ser un número entre cero y 99999999.99.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.areas WHERE codigo='ALMACEN' AND activo) THEN RAISE EXCEPTION 'Almacén no está habilitado.'; END IF;
 IF p_medicamento IS NOT NULL THEN
  IF jsonb_typeof(p_medicamento)<>'object' OR NULLIF(btrim(p_medicamento->>'gtin'),'') IS NULL
   OR NULLIF(btrim(p_medicamento->>'nombre_comercial'),'') IS NULL OR NULLIF(btrim(p_medicamento->>'principio_activo'),'') IS NULL
   OR NULLIF(btrim(p_medicamento->>'presentacion'),'') IS NULL THEN RAISE EXCEPTION 'Complete los datos del medicamento nuevo.'; END IF;
  IF COALESCE((p_medicamento->>'cantidad_por_presentacion')::integer,1)<=0
   OR COALESCE((p_medicamento->>'precio_kairos')::numeric,0)<0
   OR COALESCE((p_medicamento->>'temperatura_min')::numeric,2)>COALESCE((p_medicamento->>'temperatura_max')::numeric,8) THEN
   RAISE EXCEPTION 'Revise presentación, precio y rango de temperatura del medicamento.'; END IF;
  v_cat := CASE WHEN upper(btrim(COALESCE(p_medicamento->>'categoria',''))) = 'DISPOSITIVO_MEDICO'
                THEN 'DISPOSITIVO_MEDICO' ELSE 'MEDICAMENTO' END;
  INSERT INTO public.medicamentos(gtin,nombre_comercial,principio_activo,presentacion,laboratorio,cod_art,
   registro_sanitario,unidad_presentacion,cantidad_por_presentacion,requiere_cadena_frio,temperatura_min,temperatura_max,precio_kairos,categoria)
  VALUES(btrim(p_medicamento->>'gtin'),btrim(p_medicamento->>'nombre_comercial'),btrim(p_medicamento->>'principio_activo'),
   btrim(p_medicamento->>'presentacion'),NULLIF(btrim(p_medicamento->>'laboratorio'),''),NULLIF(btrim(p_medicamento->>'cod_art'),''),
   NULLIF(btrim(p_medicamento->>'registro_sanitario'),''),COALESCE(NULLIF(btrim(p_medicamento->>'unidad_presentacion'),''),'unidad'),
   COALESCE((p_medicamento->>'cantidad_por_presentacion')::integer,1),COALESCE((p_medicamento->>'requiere_cadena_frio')::boolean,false),
   COALESCE((p_medicamento->>'temperatura_min')::numeric,2),COALESCE((p_medicamento->>'temperatura_max')::numeric,8),
   (p_medicamento->>'precio_kairos')::numeric,v_cat)
  ON CONFLICT (gtin) DO UPDATE SET
   nombre_comercial = EXCLUDED.nombre_comercial,
   principio_activo = EXCLUDED.principio_activo,
   presentacion = EXCLUDED.presentacion,
   laboratorio = COALESCE(EXCLUDED.laboratorio, public.medicamentos.laboratorio),
   cod_art = COALESCE(EXCLUDED.cod_art, public.medicamentos.cod_art),
   registro_sanitario = COALESCE(EXCLUDED.registro_sanitario, public.medicamentos.registro_sanitario),
   unidad_presentacion = EXCLUDED.unidad_presentacion,
   cantidad_por_presentacion = EXCLUDED.cantidad_por_presentacion,
   requiere_cadena_frio = EXCLUDED.requiere_cadena_frio,
   temperatura_min = EXCLUDED.temperatura_min,
   temperatura_max = EXCLUDED.temperatura_max,
   precio_kairos = COALESCE(EXCLUDED.precio_kairos, public.medicamentos.precio_kairos),
   categoria = EXCLUDED.categoria,
   activo = true
  RETURNING id INTO v_med;
 ELSE v_med:=(p_datos->>'medicamento_id')::uuid;
 END IF;
 SELECT requiere_cadena_frio INTO v_frio FROM public.medicamentos WHERE id=v_med AND activo FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'El medicamento no existe o está inhabilitado.'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(v_med::text||':'||v_numero,0));
 IF EXISTS(SELECT 1 FROM public.lotes WHERE medicamento_id=v_med AND upper(btrim(numero_lote))=v_numero) THEN
  RAISE EXCEPTION 'Este lote ya existe para el producto. Consulte Ingresos y correcciones; no registre otro ingreso.'; END IF;
 INSERT INTO public.lotes(medicamento_id,numero_lote,fecha_fabricacion,fecha_vencimiento,laboratorio,proveedor,
  precio_compra,precio_venta,num_boleta,justificacion,temperatura_recepcion,observaciones)
 VALUES(v_med,v_numero,NULLIF(p_datos->>'fecha_fabricacion','')::date,(p_datos->>'fecha_vencimiento')::date,
  NULLIF(btrim(p_datos->>'laboratorio'),''),NULLIF(btrim(p_datos->>'proveedor'),''),
  (p_datos->>'precio_compra')::numeric,(p_datos->>'precio_venta')::numeric,NULLIF(btrim(p_datos->>'num_boleta'),''),
  p_datos->>'justificacion',(p_datos->>'temperatura_recepcion')::numeric,NULLIF(btrim(p_datos->>'observaciones'),'')) RETURNING * INTO v_lote;
 INSERT INTO public.inventario_stock(lote_id,area_codigo,cantidad) VALUES(v_lote.id,'ALMACEN',v_cantidad);
 INSERT INTO public.ingresos_lote(lote_id,cantidad_original,cantidad_registrada,datos_originales)
  VALUES(v_lote.id,v_cantidad,v_cantidad,to_jsonb(v_lote));
 INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,
  medicamento_id,lote_id,area_destino,cantidad,descripcion,estado_nuevo,detalles_extra)
 VALUES('INGRESO_ALMACEN',v_lote.id,'lotes',v_actor,v_med,v_lote.id,'ALMACEN',v_cantidad,
  'Ingreso completo de lote y stock en Almacén',to_jsonb(v_lote),jsonb_build_object('cantidad',v_cantidad,
  'documento',v_lote.num_boleta,'precio_compra',v_lote.precio_compra,'justificacion',v_lote.justificacion));
 INSERT INTO public.operaciones_ingreso_lote(usuario_id,operacion_id,lote_id,accion,datos,resultado)
 VALUES(v_actor,p_operacion_id,v_lote.id,'INGRESO',v_datos,to_jsonb(v_lote));
 RETURN to_jsonb(v_lote);
END $$;
REVOKE ALL ON FUNCTION public.registrar_ingreso_lote_hu024(UUID,JSONB,JSONB) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.registrar_ingreso_lote_hu024(UUID,JSONB,JSONB) TO authenticated;

-- 2. Ampliación de public.dispensaciones para soportar Ficha General y Ficha Neonatología (RF-003 / RF-005).
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
  ADD COLUMN IF NOT EXISTS solicitud_id UUID,
  ADD COLUMN IF NOT EXISTS solicitud_datos JSONB,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE public.dispensaciones
  DROP CONSTRAINT IF EXISTS dispensaciones_tipo_ficha_check;
ALTER TABLE public.dispensaciones
  ADD CONSTRAINT dispensaciones_tipo_ficha_check
  CHECK (tipo_ficha IN ('GENERAL', 'NEONATOLOGIA'));

ALTER TABLE public.dispensaciones
  DROP CONSTRAINT IF EXISTS dispensaciones_turno_check;
ALTER TABLE public.dispensaciones
  ADD CONSTRAINT dispensaciones_turno_check
  CHECK (turno IN ('DIA', 'TARDE', 'NOCHE'));

ALTER TABLE public.dispensaciones
  DROP CONSTRAINT IF EXISTS dispensaciones_procedencia_check;
ALTER TABLE public.dispensaciones
  ADD CONSTRAINT dispensaciones_procedencia_check
  CHECK (procedencia IS NULL OR procedencia IN ('EMERGENCIA', 'HOSPITALIZACION', 'OTRO'));

ALTER TABLE public.dispensaciones
  DROP CONSTRAINT IF EXISTS dispensaciones_tipo_parto_check;
ALTER TABLE public.dispensaciones
  ADD CONSTRAINT dispensaciones_tipo_parto_check
  CHECK (tipo_parto IS NULL OR tipo_parto IN ('EUTOCICO', 'DISTOCICO', 'CESAREA', 'OTRO'));

CREATE UNIQUE INDEX IF NOT EXISTS uq_dispensaciones_solicitud_usuario
  ON public.dispensaciones(solicitado_por, solicitud_id)
  WHERE solicitud_id IS NOT NULL;

CREATE SEQUENCE IF NOT EXISTS public.dispensaciones_numero_seq;
REVOKE ALL ON SEQUENCE public.dispensaciones_numero_seq FROM PUBLIC, anon, authenticated;

-- 3. Ampliación de public.dispensacion_items para separar secciones y marcar copia de kit (RF-003 / RF-005).
ALTER TABLE public.dispensacion_items
  ADD COLUMN IF NOT EXISTS categoria_item TEXT NOT NULL DEFAULT 'MEDICAMENTO',
  ADD COLUMN IF NOT EXISTS origen_kit BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.dispensacion_items
  DROP CONSTRAINT IF EXISTS dispensacion_items_categoria_check;
ALTER TABLE public.dispensacion_items
  ADD CONSTRAINT dispensacion_items_categoria_check
  CHECK (categoria_item IN ('MEDICAMENTO', 'DISPOSITIVO_MEDICO'));

CREATE UNIQUE INDEX IF NOT EXISTS uq_dispensacion_item_medicamento
  ON public.dispensacion_items(dispensacion_id, medicamento_id);

-- 4. Permisos por pertenencia real de área (UUID en profile_areas).
CREATE OR REPLACE FUNCTION public.puede_registrar_ficha_area(p_area TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.activo
      AND (
        p.rol = 'ADMINISTRADOR'
        OR (
          p.rol = 'ENFERMERIA'
          AND EXISTS (
            SELECT 1 FROM public.profile_areas pa
            JOIN public.areas a ON a.id = pa.area_id
            WHERE pa.profile_id = p.id AND a.codigo = p_area AND a.activo
          )
        )
      )
  );
$$;
REVOKE ALL ON FUNCTION public.puede_registrar_ficha_area(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.puede_registrar_ficha_area(TEXT) TO authenticated;

-- 5. Contexto dinámico para la vista de registro de ficha (HU-003 / HU-005).
-- Devuelve áreas habilitadas del usuario, financiamientos activos con su cobertura,
-- doctores activos, personal receptor activo del área y kits activos con stock actual en Farmacia.
CREATE OR REPLACE FUNCTION public.contexto_registro_ficha_hu003(p_area TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_perfil public.profiles%ROWTYPE;
  v_areas JSONB;
  v_financiamientos JSONB;
  v_doctores JSONB;
  v_receptores JSONB;
  v_kits JSONB;
BEGIN
  SELECT * INTO v_perfil FROM public.profiles WHERE id = auth.uid() AND activo;
  IF NOT FOUND OR v_perfil.rol IS NULL OR v_perfil.rol NOT IN ('ADMINISTRADOR', 'ENFERMERIA', 'FARMACIA', 'JEFATURA_FARMACIA') THEN
    RAISE EXCEPTION 'No tienes permisos para acceder al registro de fichas.' USING ERRCODE = '42501';
  END IF;

  -- Áreas clínicas activas autorizadas para el usuario
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', a.id,
        'codigo', a.codigo,
        'codigo_interno', a.codigo_interno,
        'nombre', a.nombre,
        'tema_color', a.tema_color,
        'activo', a.activo
      ) ORDER BY a.nombre
    ),
    '[]'::JSONB
  ) INTO v_areas
  FROM public.areas a
  WHERE a.activo
    AND upper(translate(btrim(a.codigo), 'ÁÉÍÓÚáéíóú', 'AEIOUaeiou')) !~ '^(FARMACIA|ALMACEN|JEFATURA)([ _-]|$)'
    AND (
      v_perfil.rol IN ('ADMINISTRADOR', 'FARMACIA', 'JEFATURA_FARMACIA')
      OR EXISTS (
        SELECT 1 FROM public.profile_areas pa
        WHERE pa.profile_id = v_perfil.id AND pa.area_id = a.id
      )
    );

  -- Financiamientos activos y su lista de medicamentos cubiertos
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', f.id,
        'nombre', f.nombre,
        'tipo', f.tipo,
        'descripcion', f.descripcion,
        'porcentaje_descuento', f.porcentaje_descuento,
        'medicamentos', COALESCE(
          (
            SELECT jsonb_agg(fm.medicamento_id)
            FROM public.financiamiento_medicamentos fm
            WHERE fm.financiamiento_id = f.id
          ),
          '[]'::JSONB
        )
      ) ORDER BY f.tipo, f.nombre
    ),
    '[]'::JSONB
  ) INTO v_financiamientos
  FROM public.financiamientos f
  WHERE f.activo;

  -- Doctores registrados activos en public.doctores
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', d.id,
        'nombre', d.nombre,
        'colegiatura', d.colegiatura,
        'especialidad', d.especialidad
      ) ORDER BY lower(d.nombre), d.id
    ),
    '[]'::JSONB
  ) INTO v_doctores
  FROM public.doctores d
  WHERE d.activo;

  -- Personal receptor activo de Enfermería/Técnico asignado a las áreas clínicas
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'nombre', p.nombre,
        'cargo', COALESCE(p.cargo, 'Enfermería / Técnico'),
        'areas', COALESCE(
          (
            SELECT jsonb_agg(a.codigo ORDER BY a.codigo)
            FROM public.profile_areas pa
            JOIN public.areas a ON a.id = pa.area_id
            WHERE pa.profile_id = p.id AND a.activo
          ),
          '[]'::JSONB
        )
      ) ORDER BY lower(p.nombre), p.id
    ),
    '[]'::JSONB
  ) INTO v_receptores
  FROM public.profiles p
  WHERE p.activo
    AND p.rol = 'ENFERMERIA'
    AND (
      p_area IS NULL
      OR EXISTS (
        SELECT 1 FROM public.profile_areas pa
        JOIN public.areas a ON a.id = pa.area_id
        WHERE pa.profile_id = p.id AND a.codigo = p_area
      )
    );

  -- Kits activos disponibles para el área con stock disponible actual en Farmacia por cada ítem
  WITH stock_actual AS (
    SELECT
      s.medicamento_id,
      s.farmacia_disponible,
      s.almacen_disponible,
      s.en_transito
    FROM public.consultar_stock_ubicaciones('', 0, 500) s
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', k.id,
        'nombre', k.nombre,
        'descripcion', k.descripcion,
        'area_destino', k.area_destino,
        'area_nombre', COALESCE(a.nombre, k.area_destino),
        'items', COALESCE(
          (
            SELECT jsonb_agg(
              jsonb_build_object(
                'medicamento_id', ki.medicamento_id,
                'nombre_comercial', m.nombre_comercial,
                'principio_activo', m.principio_activo,
                'presentacion', m.presentacion,
                'laboratorio', m.laboratorio,
                'unidad', m.unidad_presentacion,
                'categoria', m.categoria,
                'precio_kairos', m.precio_kairos,
                'cantidad', ki.cantidad,
                'activo', m.activo,
                'farmacia_disponible', COALESCE(st.farmacia_disponible, 0),
                'almacen_disponible', COALESCE(st.almacen_disponible, 0),
                'en_transito', COALESCE(st.en_transito, 0)
              ) ORDER BY m.nombre_comercial, ki.id
            )
            FROM public.kit_items ki
            JOIN public.medicamentos m ON m.id = ki.medicamento_id
            LEFT JOIN stock_actual st ON st.medicamento_id = ki.medicamento_id
            WHERE ki.kit_id = k.id
          ),
          '[]'::JSONB
        )
      ) ORDER BY lower(k.nombre), k.id
    ),
    '[]'::JSONB
  ) INTO v_kits
  FROM public.kits k
  JOIN public.areas a ON a.codigo = k.area_destino
  WHERE k.activo
    AND a.activo
    AND public.puede_consultar_area_kits(k.area_destino)
    AND (p_area IS NULL OR k.area_destino = p_area);

  RETURN jsonb_build_object(
    'rol', v_perfil.rol,
    'usuario_id', v_perfil.id,
    'usuario_nombre', v_perfil.nombre,
    'areas', v_areas,
    'financiamientos', v_financiamientos,
    'doctores', v_doctores,
    'receptores', v_receptores,
    'kits', v_kits
  );
END;
$$;
REVOKE ALL ON FUNCTION public.contexto_registro_ficha_hu003(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.contexto_registro_ficha_hu003(TEXT) TO authenticated;

-- 6. Catálogo con stock real en Farmacia para selección individual (HU-004).
CREATE OR REPLACE FUNCTION public.catalogo_stock_ficha_hu004(
  p_busqueda TEXT DEFAULT '',
  p_desde INTEGER DEFAULT 0,
  p_limite INTEGER DEFAULT 100
)
RETURNS TABLE(
  id UUID,
  nombre TEXT,
  principio_activo TEXT,
  presentacion TEXT,
  laboratorio TEXT,
  unidad TEXT,
  categoria TEXT,
  precio_kairos NUMERIC,
  activo BOOLEAN,
  farmacia_disponible BIGINT,
  almacen_disponible BIGINT,
  en_transito BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF public.sitra_rol_actual() IS NULL THEN
    RAISE EXCEPTION 'Inicia sesión con un perfil activo.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    s.medicamento_id,
    s.nombre,
    m.principio_activo,
    s.presentacion,
    m.laboratorio,
    m.unidad_presentacion,
    m.categoria,
    m.precio_kairos,
    s.activo,
    s.farmacia_disponible,
    s.almacen_disponible,
    s.en_transito
  FROM public.consultar_stock_ubicaciones(p_busqueda, p_desde, p_limite) s
  JOIN public.medicamentos m ON m.id = s.medicamento_id
  WHERE s.activo = true
  ORDER BY (s.farmacia_disponible > 0) DESC, lower(s.nombre), s.medicamento_id;
END;
$$;
REVOKE ALL ON FUNCTION public.catalogo_stock_ficha_hu004(TEXT, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.catalogo_stock_ficha_hu004(TEXT, INTEGER, INTEGER) TO authenticated;

-- 7. Consulta de fichas recientes del área para seguimiento y edición mientras siguen en SOLICITADO (RF-003).
CREATE OR REPLACE FUNCTION public.listar_fichas_recientes_hu003(
  p_area TEXT DEFAULT NULL,
  p_limite INTEGER DEFAULT 30
)
RETURNS SETOF JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_rol TEXT := public.sitra_rol_actual();
BEGIN
  IF v_rol IS NULL OR v_rol NOT IN ('ADMINISTRADOR', 'ENFERMERIA', 'FARMACIA', 'JEFATURA_FARMACIA') THEN
    RAISE EXCEPTION 'No tienes permisos para consultar fichas.' USING ERRCODE = '42501';
  END IF;
  IF p_limite IS NULL OR p_limite NOT BETWEEN 1 AND 200 THEN
    RAISE EXCEPTION 'Límite de consulta inválido.';
  END IF;

  RETURN QUERY
  SELECT
    to_jsonb(d) || jsonb_build_object(
      'area_nombre', COALESCE(a.nombre, d.area_origen),
      'area_tema_color', COALESCE(a.tema_color, 'ROJO'),
      'kit_nombre', k.nombre,
      'solicitante_nombre', ps.nombre,
      'items', COALESCE(
        (
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', di.id,
              'medicamento_id', di.medicamento_id,
              'nombre_comercial', m.nombre_comercial,
              'presentacion', m.presentacion,
              'laboratorio', m.laboratorio,
              'unidad', m.unidad_presentacion,
              'cantidad_solicitada', di.cantidad_solicitada,
              'cantidad_entregada', di.cantidad_entregada,
              'categoria_item', di.categoria_item,
              'origen_kit', di.origen_kit,
              'precio_kairos_aplicado', di.precio_kairos_aplicado,
              'porcentaje_descuento_aplicado', di.porcentaje_descuento_aplicado,
              'precio_unitario_aplicado', di.precio_unitario_aplicado
            ) ORDER BY di.categoria_item, lower(m.nombre_comercial), di.id
          )
          FROM public.dispensacion_items di
          JOIN public.medicamentos m ON m.id = di.medicamento_id
          WHERE di.dispensacion_id = d.id
        ),
        '[]'::JSONB
      )
    )
  FROM public.dispensaciones d
  LEFT JOIN public.areas a ON a.codigo = d.area_origen
  LEFT JOIN public.kits k ON k.id = d.kit_id
  LEFT JOIN public.profiles ps ON ps.id = d.solicitado_por
  WHERE (
    v_rol IN ('ADMINISTRADOR', 'FARMACIA', 'JEFATURA_FARMACIA')
    OR public.puede_consultar_area_kits(d.area_origen)
  )
  AND (p_area IS NULL OR d.area_origen = p_area)
  ORDER BY d.fecha_creacion DESC, d.id
  LIMIT p_limite;
END;
$$;
REVOKE ALL ON FUNCTION public.listar_fichas_recientes_hu003(TEXT, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.listar_fichas_recientes_hu003(TEXT, INTEGER) TO authenticated;

-- 8. Registro y edición atómica de ficha de pedido (HU-003 / HU-004 / HU-005).
-- Copia los ítems del kit de forma independiente en dispensacion_items para que futuras
-- modificaciones a la plantilla del kit nunca alteren las fichas ya emitidas.
CREATE OR REPLACE FUNCTION public.registrar_ficha_hu003(
  p_solicitud_id UUID,
  p_id UUID DEFAULT NULL,
  p_datos JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_usuario UUID := auth.uid();
  v_rol TEXT := public.sitra_rol_actual();
  v_ficha public.dispensaciones%ROWTYPE;
  v_antes JSONB;
  v_area public.areas%ROWTYPE;
  v_fin public.financiamientos%ROWTYPE;
  v_kit public.kits%ROWTYPE;
  v_receptor public.profiles%ROWTYPE;
  v_doctor public.doctores%ROWTYPE;
  v_tipo_ficha TEXT;
  v_area_origen TEXT;
  v_turno TEXT;
  v_prioridad TEXT;
  v_tipo_atencion TEXT;
  v_financiamiento_id UUID;
  v_kit_id UUID;
  v_doctor_id UUID;
  v_doctor_nombre TEXT;
  v_receptor_id UUID;
  v_recibido_por TEXT;
  v_paciente_nombre TEXT;
  v_procedencia TEXT;
  v_procedencia_detalle TEXT;
  v_diagnostico TEXT;
  v_madre_nombre TEXT;
  v_habitacion TEXT;
  v_rn_apellidos TEXT;
  v_tipo_parto TEXT;
  v_observaciones TEXT;
  v_confirmar_faltante_kit BOOLEAN;
  v_items JSONB;
  v_item JSONB;
  v_med_id UUID;
  v_med public.medicamentos%ROWTYPE;
  v_cantidad INTEGER;
  v_categoria_item TEXT;
  v_origen_kit BOOLEAN;
  v_stock_farmacia BIGINT;
  v_descuento NUMERIC(5,2);
  v_precio_unit NUMERIC(12,2);
  v_ids UUID[] := '{}';
  v_numero BIGINT;
  v_codigo TEXT;
  v_items_guardados JSONB;
  v_resultado JSONB;
  v_evento TEXT;
BEGIN
  IF v_usuario IS NULL OR v_rol IS NULL OR v_rol NOT IN ('ENFERMERIA', 'ADMINISTRADOR') THEN
    RAISE EXCEPTION 'Solo el personal de Enfermería o Administración puede registrar fichas de pedido.' USING ERRCODE = '42501';
  END IF;
  IF p_solicitud_id IS NULL OR p_datos IS NULL OR jsonb_typeof(p_datos) <> 'object' THEN
    RAISE EXCEPTION 'Datos de ficha inválidos.';
  END IF;

  -- Serializa reintentos del mismo usuario con la misma clave de solicitud
  PERFORM pg_advisory_xact_lock(hashtextextended(v_usuario::TEXT || ':' || p_solicitud_id::TEXT, 300405));
  IF p_id IS NULL THEN
    SELECT * INTO v_ficha FROM public.dispensaciones
    WHERE solicitado_por = v_usuario AND solicitud_id = p_solicitud_id;
    IF FOUND THEN
      SELECT COALESCE(jsonb_agg(to_jsonb(i) ORDER BY i.id), '[]'::JSONB) INTO v_items_guardados
      FROM public.dispensacion_items i WHERE i.dispensacion_id = v_ficha.id;
      RETURN to_jsonb(v_ficha) || jsonb_build_object('items', v_items_guardados);
    END IF;
  END IF;

  v_tipo_ficha := upper(btrim(COALESCE(p_datos->>'tipo_ficha', 'GENERAL')));
  IF v_tipo_ficha NOT IN ('GENERAL', 'NEONATOLOGIA') THEN
    RAISE EXCEPTION 'Selecciona un tipo de ficha válido (General o Neonatología).';
  END IF;

  v_area_origen := btrim(COALESCE(p_datos->>'area_origen', ''));
  SELECT * INTO v_area FROM public.areas WHERE codigo = v_area_origen FOR SHARE;
  IF NOT FOUND OR NOT v_area.activo THEN
    RAISE EXCEPTION 'Selecciona un área clínica activa.';
  END IF;
  IF NOT public.puede_registrar_ficha_area(v_area.codigo) THEN
    RAISE EXCEPTION 'No tienes permisos para registrar fichas en el área %.', v_area.nombre USING ERRCODE = '42501';
  END IF;

  -- Si es edición (RF-003 flujo de excepción), bloquea la ficha y verifica que siga en SOLICITADO
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_ficha FROM public.dispensaciones WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'La ficha que intentas editar ya no existe.';
    END IF;
    IF v_ficha.estado <> 'SOLICITADO' THEN
      RAISE EXCEPTION 'Solo se pueden editar fichas en estado SOLICITADO antes de que Farmacia inicie su preparación.';
    END IF;
    IF v_rol <> 'ADMINISTRADOR' AND NOT public.puede_registrar_ficha_area(v_ficha.area_origen) THEN
      RAISE EXCEPTION 'No tienes permisos para editar esta ficha.' USING ERRCODE = '42501';
    END IF;
    SELECT to_jsonb(v_ficha) || jsonb_build_object(
      'items', COALESCE((SELECT jsonb_agg(to_jsonb(di) ORDER BY di.id) FROM public.dispensacion_items di WHERE di.dispensacion_id = p_id), '[]'::JSONB)
    ) INTO v_antes;
  END IF;

  v_turno := upper(btrim(COALESCE(p_datos->>'turno', 'DIA')));
  IF v_turno NOT IN ('DIA', 'TARDE', 'NOCHE') THEN
    RAISE EXCEPTION 'Selecciona un turno válido (Día, Tarde o Noche).';
  END IF;

  v_prioridad := upper(btrim(COALESCE(p_datos->>'prioridad', 'NORMAL')));
  IF v_prioridad NOT IN ('NORMAL', 'URGENTE') THEN
    RAISE EXCEPTION 'Selecciona una prioridad válida (Normal o Urgente).';
  END IF;

  -- Validación de financiamiento (Particular, Seguro o Convenio) respetando hu012_ficha_financiamiento_check
  v_tipo_atencion := upper(btrim(COALESCE(p_datos->>'tipo_atencion', 'PARTICULAR')));
  IF v_tipo_atencion NOT IN ('PARTICULAR', 'SEGURO', 'CONVENIO') THEN
    RAISE EXCEPTION 'Selecciona la modalidad de financiamiento (Particular, Seguro o Convenio).';
  END IF;
  IF v_tipo_atencion = 'PARTICULAR' THEN
    v_financiamiento_id := NULL;
    v_fin := NULL;
  ELSIF NULLIF(btrim(COALESCE(p_datos->>'financiamiento_id', '')), '') IS NOT NULL THEN
    v_financiamiento_id := (p_datos->>'financiamiento_id')::UUID;
    SELECT * INTO v_fin FROM public.financiamientos WHERE id = v_financiamiento_id FOR SHARE;
    IF NOT FOUND OR NOT v_fin.activo THEN
      RAISE EXCEPTION 'El financiamiento seleccionado no existe o está inactivo.';
    END IF;
    IF v_fin.tipo <> v_tipo_atencion THEN
      RAISE EXCEPTION 'El financiamiento seleccionado no corresponde al tipo de atención %.', v_tipo_atencion;
    END IF;
  ELSE
    RAISE EXCEPTION 'Selecciona el seguro o convenio aplicable.';
  END IF;

  -- Validación de Doctor a cargo
  IF NULLIF(btrim(COALESCE(p_datos->>'doctor_id', '')), '') IS NOT NULL THEN
    v_doctor_id := (p_datos->>'doctor_id')::UUID;
    SELECT * INTO v_doctor FROM public.doctores WHERE id = v_doctor_id AND activo;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'El médico seleccionado no está activo en el catálogo.';
    END IF;
    v_doctor_nombre := v_doctor.nombre;
  ELSE
    v_doctor_nombre := regexp_replace(btrim(COALESCE(p_datos->>'doctor_nombre', '')), '\s+', ' ', 'g');
    IF length(v_doctor_nombre) < 3 OR length(v_doctor_nombre) > 120 THEN
      RAISE EXCEPTION 'Indica el médico a cargo (3 a 120 caracteres).';
    END IF;
  END IF;

  -- Validación de personal receptor del área
  IF NULLIF(btrim(COALESCE(p_datos->>'receptor_id', '')), '') IS NOT NULL THEN
    v_receptor_id := (p_datos->>'receptor_id')::UUID;
    SELECT * INTO v_receptor FROM public.profiles WHERE id = v_receptor_id AND activo;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'El personal receptor seleccionado no está activo.';
    END IF;
    v_recibido_por := v_receptor.nombre;
  ELSE
    v_recibido_por := regexp_replace(btrim(COALESCE(p_datos->>'recibido_por', '')), '\s+', ' ', 'g');
    IF length(v_recibido_por) < 3 OR length(v_recibido_por) > 120 THEN
      RAISE EXCEPTION 'Selecciona o indica el personal receptor del área.';
    END IF;
  END IF;

  -- Validación según el tipo de ficha: GENERAL vs NEONATOLOGIA (RF-003)
  IF v_tipo_ficha = 'GENERAL' THEN
    v_paciente_nombre := regexp_replace(btrim(COALESCE(p_datos->>'paciente_nombre', '')), '\s+', ' ', 'g');
    IF length(v_paciente_nombre) < 3 OR length(v_paciente_nombre) > 120 THEN
      RAISE EXCEPTION 'Ingresa los nombres y apellidos del paciente (3 a 120 caracteres).';
    END IF;
    v_procedencia := upper(btrim(COALESCE(p_datos->>'procedencia', '')));
    IF v_procedencia NOT IN ('EMERGENCIA', 'HOSPITALIZACION', 'OTRO') THEN
      RAISE EXCEPTION 'Selecciona la procedencia del paciente (Emergencia, Hospitalización u Otro).';
    END IF;
    v_procedencia_detalle := NULLIF(regexp_replace(btrim(COALESCE(p_datos->>'procedencia_detalle', '')), '\s+', ' ', 'g'), '');
    IF v_procedencia = 'OTRO' AND (v_procedencia_detalle IS NULL OR length(v_procedencia_detalle) < 2) THEN
      RAISE EXCEPTION 'Especifica el detalle de procedencia cuando seleccionas "Otro".';
    END IF;
    v_diagnostico := regexp_replace(btrim(COALESCE(p_datos->>'diagnostico_motivo', '')), '\s+', ' ', 'g');
    IF length(v_diagnostico) < 3 OR length(v_diagnostico) > 250 THEN
      RAISE EXCEPTION 'Ingresa el diagnóstico o motivo del pedido (3 a 250 caracteres).';
    END IF;
    v_madre_nombre := NULL;
    v_habitacion := NULLIF(btrim(COALESCE(p_datos->>'habitacion', '')), '');
    v_rn_apellidos := NULL;
    v_tipo_parto := NULL;
  ELSE
    v_madre_nombre := regexp_replace(btrim(COALESCE(p_datos->>'madre_nombre', '')), '\s+', ' ', 'g');
    IF length(v_madre_nombre) < 3 OR length(v_madre_nombre) > 120 THEN
      RAISE EXCEPTION 'Ingresa los nombres y apellidos de la madre (3 a 120 caracteres).';
    END IF;
    v_rn_apellidos := regexp_replace(btrim(COALESCE(p_datos->>'recien_nacido_apellidos', '')), '\s+', ' ', 'g');
    IF length(v_rn_apellidos) < 2 OR length(v_rn_apellidos) > 120 THEN
      RAISE EXCEPTION 'Ingresa los apellidos del recién nacido (2 a 120 caracteres).';
    END IF;
    v_tipo_parto := upper(btrim(COALESCE(p_datos->>'tipo_parto', '')));
    IF v_tipo_parto NOT IN ('EUTOCICO', 'DISTOCICO', 'CESAREA', 'OTRO') THEN
      RAISE EXCEPTION 'Selecciona el tipo de parto (Eutócico, Distócico, Cesárea u Otro).';
    END IF;
    v_habitacion := NULLIF(regexp_replace(btrim(COALESCE(p_datos->>'habitacion', '')), '\s+', ' ', 'g'), '');
    v_diagnostico := COALESCE(
      NULLIF(regexp_replace(btrim(COALESCE(p_datos->>'diagnostico_motivo', '')), '\s+', ' ', 'g'), ''),
      'Atención neonatal - Parto ' || initcap(lower(v_tipo_parto))
    );
    v_paciente_nombre := 'RN ' || v_rn_apellidos || ' (Madre: ' || v_madre_nombre || ')';
    v_procedencia := NULL;
    v_procedencia_detalle := NULL;
  END IF;

  v_observaciones := NULLIF(btrim(COALESCE(p_datos->>'observaciones', '')), '');
  v_confirmar_faltante_kit := COALESCE((p_datos->>'confirmar_faltante_kit')::BOOLEAN, false);

  -- Validación opcional de plantilla de kit aplicada (HU-005)
  IF NULLIF(btrim(COALESCE(p_datos->>'kit_id', '')), '') IS NOT NULL THEN
    v_kit_id := (p_datos->>'kit_id')::UUID;
    SELECT * INTO v_kit FROM public.kits WHERE id = v_kit_id FOR SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'El kit seleccionado ya no existe.';
    END IF;
    IF v_kit.area_destino <> v_area.codigo THEN
      RAISE EXCEPTION 'El kit "%" pertenece al área % y no puede aplicarse a %.', v_kit.nombre, v_kit.area_destino, v_area.codigo;
    END IF;
    IF NOT v_kit.activo AND (p_id IS NULL OR v_ficha.kit_id IS DISTINCT FROM v_kit_id) THEN
      RAISE EXCEPTION 'El kit "%" está inhabilitado para nuevas fichas.', v_kit.nombre;
    END IF;
  END IF;

  -- Validación de ítems solicitados y stock disponible en Farmacia (HU-004 / HU-005)
  v_items := p_datos->'items';
  IF jsonb_typeof(v_items) IS DISTINCT FROM 'array' OR jsonb_array_length(v_items) NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'La ficha debe incluir al menos un medicamento o dispositivo médico.';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
    IF NULLIF(btrim(COALESCE(v_item->>'medicamento_id', '')), '') IS NULL THEN
      RAISE EXCEPTION 'Cada ítem debe indicar un medicamento o dispositivo válido.';
    END IF;
    v_med_id := (v_item->>'medicamento_id')::UUID;
    IF v_med_id = ANY(v_ids) THEN
      RAISE EXCEPTION 'No repitas el mismo medicamento o dispositivo en la ficha; suma su cantidad en una sola línea.';
    END IF;
    IF jsonb_typeof(v_item->'cantidad') IS DISTINCT FROM 'number' OR COALESCE(v_item->>'cantidad', '') !~ '^[1-9][0-9]*$' THEN
      RAISE EXCEPTION 'La cantidad solicitada de cada ítem debe ser un número entero mayor que cero.';
    END IF;
    v_cantidad := (v_item->>'cantidad')::INTEGER;
    v_origen_kit := COALESCE((v_item->>'origen_kit')::BOOLEAN, false);

    SELECT * INTO v_med FROM public.medicamentos WHERE id = v_med_id FOR SHARE;
    IF NOT FOUND OR NOT v_med.activo THEN
      RAISE EXCEPTION 'El ítem "%" no existe o está inhabilitado.', COALESCE(v_med.nombre_comercial, v_med_id::TEXT);
    END IF;

    v_categoria_item := upper(btrim(COALESCE(v_item->>'categoria_item', v_med.categoria, 'MEDICAMENTO')));
    IF v_categoria_item NOT IN ('MEDICAMENTO', 'DISPOSITIVO_MEDICO') THEN
      v_categoria_item := v_med.categoria;
    END IF;

    -- Consulta el stock disponible real en Farmacia (excluyendo vencidos y tránsito)
    SELECT COALESCE(s.farmacia_disponible, 0) INTO v_stock_farmacia
    FROM public.consultar_stock_ubicaciones('', 0, 500) s
    WHERE s.medicamento_id = v_med_id;
    v_stock_farmacia := COALESCE(v_stock_farmacia, 0);

    IF NOT v_origen_kit AND v_stock_farmacia <= 0 THEN
      RAISE EXCEPTION 'El ítem "%" no tiene stock disponible en Farmacia y no puede seleccionarse individualmente.', v_med.nombre_comercial;
    END IF;
    IF v_cantidad > v_stock_farmacia AND NOT (v_origen_kit AND v_confirmar_faltante_kit) THEN
      RAISE EXCEPTION 'La cantidad solicitada de "%" (%) supera el stock disponible en Farmacia (%).',
        v_med.nombre_comercial, v_cantidad, v_stock_farmacia;
    END IF;

    v_ids := array_append(v_ids, v_med_id);
  END LOOP;

  -- Persistencia de cabecera (INSERT o UPDATE)
  IF p_id IS NULL THEN
    v_numero := nextval('public.dispensaciones_numero_seq');
    v_codigo := 'FCH-' || to_char(CURRENT_DATE, 'YYYYMMDD') || '-' || lpad(v_numero::TEXT, GREATEST(6, length(v_numero::TEXT)), '0');
    INSERT INTO public.dispensaciones(
      numero_ficha,
      tipo,
      tipo_ficha,
      kit_id,
      area_origen,
      turno,
      doctor_id,
      doctor_nombre,
      paciente_nombre,
      procedencia,
      procedencia_detalle,
      diagnostico_motivo,
      madre_nombre,
      habitacion,
      recien_nacido_apellidos,
      tipo_parto,
      prioridad,
      estado,
      tipo_atencion,
      financiamiento_id,
      financiamiento_nombre_aplicado,
      solicitado_por,
      receptor_id,
      recibido_por,
      observaciones,
      solicitud_id,
      solicitud_datos,
      updated_at
    ) VALUES (
      v_codigo,
      CASE WHEN v_kit_id IS NOT NULL THEN 'KIT' ELSE 'INDIVIDUAL' END,
      v_tipo_ficha,
      v_kit_id,
      v_area.codigo,
      v_turno,
      v_doctor_id,
      v_doctor_nombre,
      v_paciente_nombre,
      v_procedencia,
      v_procedencia_detalle,
      v_diagnostico,
      v_madre_nombre,
      v_habitacion,
      v_rn_apellidos,
      v_tipo_parto,
      v_prioridad,
      'SOLICITADO',
      v_tipo_atencion,
      v_financiamiento_id,
      v_fin.nombre,
      v_usuario,
      v_receptor_id,
      v_recibido_por,
      v_observaciones,
      p_solicitud_id,
      p_datos,
      now()
    ) RETURNING * INTO v_ficha;
    v_evento := 'FICHA_CREADA';
  ELSE
    UPDATE public.dispensaciones SET
      tipo = CASE WHEN v_kit_id IS NOT NULL THEN 'KIT' ELSE 'INDIVIDUAL' END,
      tipo_ficha = v_tipo_ficha,
      kit_id = v_kit_id,
      area_origen = v_area.codigo,
      turno = v_turno,
      doctor_id = v_doctor_id,
      doctor_nombre = v_doctor_nombre,
      paciente_nombre = v_paciente_nombre,
      procedencia = v_procedencia,
      procedencia_detalle = v_procedencia_detalle,
      diagnostico_motivo = v_diagnostico,
      madre_nombre = v_madre_nombre,
      habitacion = v_habitacion,
      recien_nacido_apellidos = v_rn_apellidos,
      tipo_parto = v_tipo_parto,
      prioridad = v_prioridad,
      tipo_atencion = v_tipo_atencion,
      financiamiento_id = v_financiamiento_id,
      financiamiento_nombre_aplicado = v_fin.nombre,
      receptor_id = v_receptor_id,
      recibido_por = v_recibido_por,
      observaciones = v_observaciones,
      solicitud_datos = p_datos,
      updated_at = now()
    WHERE id = p_id
    RETURNING * INTO v_ficha;
    DELETE FROM public.dispensacion_items WHERE dispensacion_id = p_id;
    v_evento := 'FICHA_ACTUALIZADA';
  END IF;

  -- Inserta la copia independiente de ítems con su foto de precio/descuento del momento (HU-005 / HU-012)
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
    v_med_id := (v_item->>'medicamento_id')::UUID;
    v_cantidad := (v_item->>'cantidad')::INTEGER;
    v_origen_kit := COALESCE((v_item->>'origen_kit')::BOOLEAN, false);
    SELECT * INTO v_med FROM public.medicamentos WHERE id = v_med_id;
    v_categoria_item := upper(btrim(COALESCE(v_item->>'categoria_item', v_med.categoria, 'MEDICAMENTO')));
    IF v_categoria_item NOT IN ('MEDICAMENTO', 'DISPOSITIVO_MEDICO') THEN
      v_categoria_item := v_med.categoria;
    END IF;

    v_descuento := 0;
    v_precio_unit := NULL;
    IF v_med.precio_kairos IS NOT NULL THEN
      IF v_fin.id IS NOT NULL AND v_fin.tipo IN ('SEGURO', 'CONVENIO') AND EXISTS (
        SELECT 1 FROM public.financiamiento_medicamentos fm
        WHERE fm.financiamiento_id = v_fin.id AND fm.medicamento_id = v_med_id
      ) THEN
        v_descuento := COALESCE(v_fin.porcentaje_descuento, 0);
      END IF;
      v_precio_unit := round(v_med.precio_kairos * (1 - v_descuento / 100.0), 2);
    END IF;

    INSERT INTO public.dispensacion_items(
      dispensacion_id,
      medicamento_id,
      cantidad_solicitada,
      cantidad_entregada,
      categoria_item,
      origen_kit,
      precio_kairos_aplicado,
      porcentaje_descuento_aplicado,
      precio_unitario_aplicado
    ) VALUES (
      v_ficha.id,
      v_med_id,
      v_cantidad,
      0,
      v_categoria_item,
      v_origen_kit,
      v_med.precio_kairos,
      v_descuento,
      v_precio_unit
    );
  END LOOP;

  SELECT COALESCE(jsonb_agg(to_jsonb(i) ORDER BY i.id), '[]'::JSONB) INTO v_items_guardados
  FROM public.dispensacion_items i WHERE i.dispensacion_id = v_ficha.id;

  v_resultado := to_jsonb(v_ficha) || jsonb_build_object('items', v_items_guardados);

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
    v_evento,
    v_ficha.id,
    'dispensaciones',
    v_usuario,
    v_area.codigo,
    'FARMACIA',
    v_antes,
    v_resultado,
    CASE WHEN v_evento = 'FICHA_CREADA'
      THEN 'Registro de ficha de pedido ' || v_ficha.numero_ficha || ' (' || v_tipo_ficha || ')'
      ELSE 'Edición de ficha de pedido ' || v_ficha.numero_ficha || ' (' || v_tipo_ficha || ')'
    END,
    jsonb_build_object(
      'solicitud_id', p_solicitud_id,
      'kit_id', v_kit_id,
      'tipo_ficha', v_tipo_ficha,
      'total_items', jsonb_array_length(v_items)
    )
  );

  RETURN v_resultado;
END;
$$;
REVOKE ALL ON FUNCTION public.registrar_ficha_hu003(UUID, UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_ficha_hu003(UUID, UUID, JSONB) TO authenticated;

-- Toda escritura de fichas y sus ítems ocurre mediante RPC atómica auditada.
REVOKE INSERT, UPDATE, DELETE ON public.dispensaciones, public.dispensacion_items FROM authenticated, anon;

-- ----------------------------------------------------------------------------
-- 5. SANEAMIENTO DE CUENTAS OFICIALES (auth.users + auth.identities + profiles)
-- Garantiza que almacen@sitraluz.pe y los demás roles institucionales puedan
-- iniciar sesión en Supabase GoTrue sin fallos de columnas NULL o inactividad.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  uid_admin UUID := COALESCE((SELECT id FROM auth.users WHERE lower(email) = 'admin@sitraluz.pe' LIMIT 1), 'a0000000-0000-0000-0000-000000000001');
  uid_jefe UUID := COALESCE((SELECT id FROM auth.users WHERE lower(email) = 'jefatura@sitraluz.pe' LIMIT 1), 'a0000000-0000-0000-0000-000000000002');
  uid_farma UUID := COALESCE((SELECT id FROM auth.users WHERE lower(email) = 'farmacia@sitraluz.pe' LIMIT 1), 'a0000000-0000-0000-0000-000000000003');
  uid_almacen UUID := COALESCE((SELECT id FROM auth.users WHERE lower(email) = 'almacen@sitraluz.pe' LIMIT 1), 'a0000000-0000-0000-0000-000000000004');
  uid_enferm UUID := COALESCE((SELECT id FROM auth.users WHERE lower(email) = 'enfermeria@sitraluz.pe' LIMIT 1), 'a0000000-0000-0000-0000-000000000005');
  v_areas_enferm TEXT[];
BEGIN
  -- Asegura que las áreas base y Neonatología estén activas con su codigo_interno
  INSERT INTO public.areas (codigo, codigo_interno, nombre, descripcion, stock_minimo_alerta, administra_stock, activo)
  VALUES
    ('ALMACEN', 'AREA-ALM', 'Almacén General', 'Recepción de proveedores y custodia principal', 20, true, true),
    ('FARMACIA', 'AREA-FAR', 'Farmacia Central', 'Dispensación interna a pisos y pacientes', 15, true, true),
    ('SOP', 'AREA-SOP', 'Sala de Operaciones (Quirófano)', 'Procedimientos quirúrgicos programados y de urgencia', 5, false, true),
    ('EMERGENCIA', 'AREA-EMG', 'Servicio de Emergencias', 'Atención crítica continua 24 horas', 10, false, true),
    ('HOSPITALIZACION', 'AREA-HOS', 'Pabellón de Hospitalización', 'Habitaciones y camas de reposo clínico', 8, false, true),
    ('NEONATOLOGIA', 'AREA-NEO', 'Servicio de Neonatología', 'Atención integral del recién nacido', 5, false, true)
  ON CONFLICT (codigo) DO UPDATE SET
    activo = true,
    updated_at = now();

  SELECT COALESCE(array_agg(codigo ORDER BY codigo), ARRAY['SOP', 'EMERGENCIA'])
  INTO v_areas_enferm
  FROM public.areas
  WHERE codigo IN ('SOP', 'EMERGENCIA', 'NEONATOLOGIA') AND activo;

  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, confirmation_token, recovery_token, email_change_token_new, email_change, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
  VALUES
    (uid_admin, '00000000-0000-0000-0000-000000000000', 'admin@sitraluz.pe', extensions.crypt('admin123', extensions.gen_salt('bf')), now(), '', '', '', '', '{"provider":"email","providers":["email"]}', '{"nombre":"Ing. Carlos Mendoza","rol":"ADMINISTRADOR","areas":"FARMACIA,ALMACEN"}', now(), now(), 'authenticated', 'authenticated'),
    (uid_jefe, '00000000-0000-0000-0000-000000000000', 'jefatura@sitraluz.pe', extensions.crypt('jefe123', extensions.gen_salt('bf')), now(), '', '', '', '', '{"provider":"email","providers":["email"]}', '{"nombre":"Dra. Elena Ramos","rol":"JEFATURA_FARMACIA","areas":"FARMACIA"}', now(), now(), 'authenticated', 'authenticated'),
    (uid_farma, '00000000-0000-0000-0000-000000000000', 'farmacia@sitraluz.pe', extensions.crypt('farma123', extensions.gen_salt('bf')), now(), '', '', '', '', '{"provider":"email","providers":["email"]}', '{"nombre":"Q.F. Manuel Flores","rol":"FARMACIA","areas":"FARMACIA"}', now(), now(), 'authenticated', 'authenticated'),
    (uid_almacen, '00000000-0000-0000-0000-000000000000', 'almacen@sitraluz.pe', extensions.crypt('almacen123', extensions.gen_salt('bf')), now(), '', '', '', '', '{"provider":"email","providers":["email"]}', '{"nombre":"Sr. Roberto Paredes","rol":"ALMACEN","areas":"ALMACEN"}', now(), now(), 'authenticated', 'authenticated'),
    (uid_enferm, '00000000-0000-0000-0000-000000000000', 'enfermeria@sitraluz.pe', extensions.crypt('enfermera123', extensions.gen_salt('bf')), now(), '', '', '', '', '{"provider":"email","providers":["email"]}', '{"nombre":"Lic. Ana Morales","rol":"ENFERMERIA","areas":"SOP,EMERGENCIA"}', now(), now(), 'authenticated', 'authenticated')
  ON CONFLICT (id) DO UPDATE SET
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = COALESCE(auth.users.email_confirmed_at, now()),
    confirmation_token = COALESCE(auth.users.confirmation_token, ''),
    recovery_token = COALESCE(auth.users.recovery_token, ''),
    email_change_token_new = COALESCE(auth.users.email_change_token_new, ''),
    email_change = COALESCE(auth.users.email_change, ''),
    updated_at = now();

  -- Saneamiento general de cualquier fila en auth.users con tokens NULL
  UPDATE auth.users SET
    confirmation_token = COALESCE(confirmation_token, ''),
    recovery_token = COALESCE(recovery_token, ''),
    email_change_token_new = COALESCE(email_change_token_new, ''),
    email_change = COALESCE(email_change, ''),
    email_confirmed_at = COALESCE(email_confirmed_at, now())
  WHERE confirmation_token IS NULL
     OR recovery_token IS NULL
     OR email_change_token_new IS NULL
     OR email_change IS NULL
     OR email_confirmed_at IS NULL;

  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  SELECT u.id, u.id, u.id::text, jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true), 'email', now(), now(), now()
  FROM auth.users u
  WHERE lower(u.email) IN ('admin@sitraluz.pe', 'jefatura@sitraluz.pe', 'farmacia@sitraluz.pe', 'almacen@sitraluz.pe', 'enfermeria@sitraluz.pe')
  ON CONFLICT (provider_id, provider) DO NOTHING;

  -- Garantizar perfiles activos y con el rol/área correcto en public.profiles
  INSERT INTO public.profiles (id, email, nombre, nombres, apellidos, rol, areas_asignadas, activo)
  VALUES
    (uid_admin, 'admin@sitraluz.pe', 'Ing. Carlos Mendoza', 'Carlos', 'Mendoza', 'ADMINISTRADOR', ARRAY['FARMACIA', 'ALMACEN'], true),
    (uid_jefe, 'jefatura@sitraluz.pe', 'Dra. Elena Ramos', 'Elena', 'Ramos', 'JEFATURA_FARMACIA', ARRAY['FARMACIA'], true),
    (uid_farma, 'farmacia@sitraluz.pe', 'Q.F. Manuel Flores', 'Manuel', 'Flores', 'FARMACIA', ARRAY['FARMACIA'], true),
    (uid_almacen, 'almacen@sitraluz.pe', 'Sr. Roberto Paredes', 'Roberto', 'Paredes', 'ALMACEN', ARRAY['ALMACEN'], true),
    (uid_enferm, 'enfermeria@sitraluz.pe', 'Lic. Ana Morales', 'Ana', 'Morales', 'ENFERMERIA', v_areas_enferm, true)
  ON CONFLICT (id) DO UPDATE SET
    rol = EXCLUDED.rol,
    nombre = EXCLUDED.nombre,
    nombres = COALESCE(public.profiles.nombres, EXCLUDED.nombres),
    apellidos = COALESCE(public.profiles.apellidos, EXCLUDED.apellidos),
    areas_asignadas = EXCLUDED.areas_asignadas,
    activo = true,
    updated_at = now();
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;

