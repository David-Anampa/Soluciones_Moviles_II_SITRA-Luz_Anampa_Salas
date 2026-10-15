-- HU-012: Áreas, seguros y convenios. Ejecutar DESPUÉS de HU-002.
-- No modifica importes de fichas históricas ni implementa HU-020/021/022.
-- El código visible AREA-001 es editable. areas.codigo se conserva como alias
-- operativo para no romper el flujo existente FARMACIA/ALMACEN.
BEGIN;

CREATE SEQUENCE IF NOT EXISTS public.areas_codigo_interno_seq;
ALTER TABLE public.areas
  ADD COLUMN IF NOT EXISTS codigo_interno TEXT,
  ADD COLUMN IF NOT EXISTS administra_stock BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
DO $$
DECLARE v_id UUID; v_numero TEXT; v_codigo TEXT;
BEGIN
  FOR v_id IN SELECT id FROM public.areas WHERE codigo_interno IS NULL ORDER BY created_at,id LOOP
    LOOP
      v_numero:=nextval('public.areas_codigo_interno_seq')::TEXT;
      v_codigo:='AREA-'||lpad(v_numero,greatest(3,length(v_numero)),'0');
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.areas WHERE upper(codigo_interno)=v_codigo);
    END LOOP;
    UPDATE public.areas SET codigo_interno=v_codigo WHERE id=v_id;
  END LOOP;
END;
$$;
ALTER TABLE public.areas ALTER COLUMN codigo_interno SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_areas_codigo_interno ON public.areas (upper(btrim(codigo_interno)));
UPDATE public.areas a SET administra_stock = true
WHERE a.codigo IN ('ALMACEN','FARMACIA') OR EXISTS (
  SELECT 1 FROM public.inventario_stock s WHERE s.area_codigo = a.codigo AND s.cantidad > 0);

-- Campos solicitados para la próxima gestión de usuarios. No altera sus roles.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS cargo TEXT,
  ADD COLUMN IF NOT EXISTS correo_drive TEXT;

-- Referencias estables por UUID para nuevas asignaciones. Se conserva el array
-- existente por compatibilidad; el trigger lo sincroniza al guardar perfiles.
CREATE TABLE IF NOT EXISTS public.profile_areas (
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  area_id UUID NOT NULL REFERENCES public.areas(id) ON DELETE RESTRICT,
  PRIMARY KEY (profile_id, area_id)
);
INSERT INTO public.profile_areas(profile_id, area_id)
SELECT DISTINCT p.id, a.id FROM public.profiles p
CROSS JOIN LATERAL unnest(p.areas_asignadas) x(valor)
JOIN public.areas a ON upper(btrim(x.valor)) = upper(a.codigo)
  OR lower(btrim(x.valor)) = lower(btrim(a.nombre))
  OR upper(btrim(x.valor)) = upper(a.codigo_interno)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.financiamientos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL CHECK (length(btrim(nombre)) > 0),
  descripcion TEXT,
  tipo TEXT NOT NULL CHECK (tipo IN ('SEGURO','CONVENIO')),
  porcentaje_descuento NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (porcentaje_descuento BETWEEN 0 AND 100),
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_financiamientos_tipo_nombre
  ON public.financiamientos(tipo, lower(btrim(nombre)));
CREATE TABLE IF NOT EXISTS public.financiamiento_medicamentos (
  financiamiento_id UUID NOT NULL REFERENCES public.financiamientos(id) ON DELETE CASCADE,
  medicamento_id UUID NOT NULL REFERENCES public.medicamentos(id) ON DELETE RESTRICT,
  PRIMARY KEY (financiamiento_id, medicamento_id)
);

-- Preparación de la ficha para HU-003: Particular no es una tercera fila del catálogo.
ALTER TABLE public.dispensaciones
  ADD COLUMN IF NOT EXISTS tipo_atencion TEXT NOT NULL DEFAULT 'PARTICULAR'
    CHECK (tipo_atencion IN ('PARTICULAR','SEGURO','CONVENIO')),
  ADD COLUMN IF NOT EXISTS financiamiento_id UUID REFERENCES public.financiamientos(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS financiamiento_nombre_aplicado TEXT;
-- Se completarán al registrar/entregar ítems en HU-003/HU-010; NULL significa
-- histórico sin valoración registrada, nunca costo o precio cero.
ALTER TABLE public.dispensacion_items
  ADD COLUMN IF NOT EXISTS precio_kairos_aplicado NUMERIC(10,2) CHECK (precio_kairos_aplicado >= 0),
  ADD COLUMN IF NOT EXISTS porcentaje_descuento_aplicado NUMERIC(5,2) CHECK (porcentaje_descuento_aplicado BETWEEN 0 AND 100),
  ADD COLUMN IF NOT EXISTS precio_unitario_aplicado NUMERIC(10,2) CHECK (precio_unitario_aplicado >= 0);
ALTER TABLE public.dispensaciones DROP CONSTRAINT IF EXISTS hu012_ficha_financiamiento_check;
ALTER TABLE public.dispensaciones ADD CONSTRAINT hu012_ficha_financiamiento_check CHECK (
  (tipo_atencion = 'PARTICULAR' AND financiamiento_id IS NULL)
  OR (tipo_atencion IN ('SEGURO','CONVENIO') AND financiamiento_id IS NOT NULL));

CREATE OR REPLACE FUNCTION public.hu012_validar_ficha()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_area public.areas%ROWTYPE; v_fin public.financiamientos%ROWTYPE;
BEGIN
  IF TG_OP = 'INSERT' OR NEW.area_origen IS DISTINCT FROM OLD.area_origen THEN
    SELECT * INTO v_area FROM public.areas WHERE codigo = NEW.area_origen FOR SHARE;
    IF NOT FOUND OR NOT v_area.activo THEN RAISE EXCEPTION 'Selecciona un área habilitada.'; END IF;
  END IF;
  IF NEW.financiamiento_id IS NOT NULL AND (TG_OP = 'INSERT'
     OR NEW.financiamiento_id IS DISTINCT FROM OLD.financiamiento_id
     OR NEW.tipo_atencion IS DISTINCT FROM OLD.tipo_atencion) THEN
    SELECT * INTO v_fin FROM public.financiamientos WHERE id = NEW.financiamiento_id FOR SHARE;
    IF NOT FOUND OR NOT v_fin.activo OR v_fin.tipo <> NEW.tipo_atencion THEN
      RAISE EXCEPTION 'El seguro/convenio debe estar habilitado y coincidir con el tipo de atención.';
    END IF;
    NEW.financiamiento_nombre_aplicado:=v_fin.nombre;
  ELSIF NEW.financiamiento_id IS NULL THEN
    NEW.financiamiento_nombre_aplicado:=NULL;
  END IF;
  RETURN NEW;
END;
$$;

-- Contrato para futuras fichas: calcula Kairos sin descuento si no hay cobertura.
-- No factura ni escribe ítems; HU-003/HU-010 guardarán el resultado como snapshot.
CREATE OR REPLACE FUNCTION public.cotizar_medicamento_hu012(p_medicamento_id UUID,p_financiamiento_id UUID DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_base NUMERIC; v_porcentaje NUMERIC:=0; v_fin public.financiamientos%ROWTYPE;
BEGIN
  IF public.sitra_rol_actual() IS NULL THEN RAISE EXCEPTION 'Inicia sesión para consultar precios.' USING ERRCODE='42501'; END IF;
  SELECT precio_kairos INTO v_base FROM public.medicamentos WHERE id=p_medicamento_id AND activo;
  IF NOT FOUND THEN RAISE EXCEPTION 'El medicamento no está disponible.'; END IF;
  IF v_base IS NULL OR v_base<0 THEN RAISE EXCEPTION 'Registra un precio Kairos válido antes de valorizar el medicamento.'; END IF;
  IF p_financiamiento_id IS NOT NULL THEN
    SELECT * INTO v_fin FROM public.financiamientos WHERE id=p_financiamiento_id AND activo;
    IF NOT FOUND THEN RAISE EXCEPTION 'Selecciona un seguro/convenio habilitado.'; END IF;
    IF EXISTS (SELECT 1 FROM public.financiamiento_medicamentos WHERE financiamiento_id=p_financiamiento_id AND medicamento_id=p_medicamento_id) THEN
      v_porcentaje:=v_fin.porcentaje_descuento;
    END IF;
  END IF;
  RETURN jsonb_build_object('precio_kairos_aplicado',v_base,'porcentaje_descuento_aplicado',v_porcentaje,
    'precio_unitario_aplicado',round(v_base*(1-v_porcentaje/100),2));
END;
$$;
DROP TRIGGER IF EXISTS hu012_validar_ficha ON public.dispensaciones;
CREATE TRIGGER hu012_validar_ficha BEFORE INSERT OR UPDATE ON public.dispensaciones
FOR EACH ROW EXECUTE FUNCTION public.hu012_validar_ficha();

CREATE OR REPLACE FUNCTION public.hu012_validar_area_nueva()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_codigo TEXT; v_anterior TEXT;
BEGIN
  IF TG_TABLE_NAME = 'pedidos_abastecimiento' THEN
    IF TG_OP = 'INSERT' OR NEW.area_origen IS DISTINCT FROM OLD.area_origen
      OR NEW.area_destino IS DISTINCT FROM OLD.area_destino THEN
      PERFORM id FROM public.areas WHERE codigo IN (NEW.area_origen,NEW.area_destino) ORDER BY id FOR SHARE;
      IF (SELECT count(*) FROM public.areas WHERE codigo IN (NEW.area_origen,NEW.area_destino) AND activo) <> 2 THEN
        RAISE EXCEPTION 'Las áreas del nuevo pedido deben estar habilitadas.';
      END IF;
    END IF;
  ELSE
    v_codigo := NEW.area_destino;
    IF TG_OP = 'UPDATE' THEN v_anterior := OLD.area_destino; END IF;
    IF TG_OP = 'INSERT' OR v_codigo IS DISTINCT FROM v_anterior THEN
      PERFORM id FROM public.areas WHERE codigo = v_codigo AND activo FOR SHARE;
      IF NOT FOUND THEN RAISE EXCEPTION 'El área destino debe estar habilitada.'; END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS hu012_area_pedido ON public.pedidos_abastecimiento;
CREATE TRIGGER hu012_area_pedido BEFORE INSERT OR UPDATE ON public.pedidos_abastecimiento
FOR EACH ROW EXECUTE FUNCTION public.hu012_validar_area_nueva();
DROP TRIGGER IF EXISTS hu012_area_kit ON public.kits;
CREATE TRIGGER hu012_area_kit BEFORE INSERT OR UPDATE ON public.kits
FOR EACH ROW EXECUTE FUNCTION public.hu012_validar_area_nueva();

-- Un ingreso directo nuevo no utiliza un área deshabilitada. Las RPC de
-- pedidos, que ya validan su transición, pueden cerrar operaciones anteriores.
CREATE OR REPLACE FUNCTION public.hu012_validar_stock_area()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user = 'authenticated' AND (TG_OP='INSERT'
    OR NEW.area_codigo IS DISTINCT FROM OLD.area_codigo OR NEW.cantidad>OLD.cantidad) THEN
    PERFORM id FROM public.areas WHERE codigo=NEW.area_codigo AND activo;
    IF NOT FOUND THEN RAISE EXCEPTION 'No se admiten ingresos nuevos en un área deshabilitada.'; END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS hu012_stock_area ON public.inventario_stock;
CREATE TRIGGER hu012_stock_area BEFORE INSERT OR UPDATE ON public.inventario_stock
FOR EACH ROW EXECUTE FUNCTION public.hu012_validar_stock_area();

CREATE OR REPLACE FUNCTION public.hu012_sincronizar_areas_perfil()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_token TEXT; v_area public.areas%ROWTYPE; v_previas TEXT[] := '{}';
BEGIN
  IF TG_OP = 'UPDATE' THEN v_previas := COALESCE(OLD.areas_asignadas,'{}'); END IF;
  FOR v_token IN SELECT unnest(COALESCE(NEW.areas_asignadas,'{}')) LOOP
    SELECT * INTO v_area FROM public.areas
      WHERE upper(codigo) = upper(btrim(v_token)) OR upper(codigo_interno) = upper(btrim(v_token))
        OR lower(nombre) = lower(btrim(v_token)) ORDER BY id LIMIT 1 FOR SHARE;
    IF NOT FOUND THEN
      IF NOT (v_token = ANY(v_previas)) THEN RAISE EXCEPTION 'Área desconocida: %', v_token; END IF;
    ELSE
      IF NOT v_area.activo AND NOT EXISTS (
        SELECT 1 FROM public.profile_areas WHERE profile_id = NEW.id AND area_id = v_area.id)
        AND NOT (v_token = ANY(v_previas)) THEN
        RAISE EXCEPTION 'No se puede asignar un área deshabilitada: %', v_area.nombre;
      END IF;
    END IF;
  END LOOP;
  DELETE FROM public.profile_areas WHERE profile_id = NEW.id;
  INSERT INTO public.profile_areas(profile_id,area_id)
  SELECT DISTINCT NEW.id,a.id FROM unnest(COALESCE(NEW.areas_asignadas,'{}')) x(valor)
  JOIN public.areas a ON upper(btrim(x.valor)) = upper(a.codigo)
    OR upper(btrim(x.valor)) = upper(a.codigo_interno) OR lower(btrim(x.valor)) = lower(a.nombre)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS hu012_areas_perfil ON public.profiles;
CREATE TRIGGER hu012_areas_perfil AFTER INSERT OR UPDATE OF areas_asignadas ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.hu012_sincronizar_areas_perfil();

CREATE OR REPLACE FUNCTION public.sitra_tiene_area(p_area TEXT)
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles p JOIN public.profile_areas pa ON pa.profile_id=p.id
    JOIN public.areas a ON a.id=pa.area_id WHERE p.id=auth.uid() AND p.activo
    AND (a.codigo=p_area OR a.codigo_interno=p_area OR lower(a.nombre)=lower(btrim(p_area))))
  OR EXISTS (SELECT 1 FROM public.profiles p CROSS JOIN LATERAL unnest(p.areas_asignadas) x(valor)
    WHERE p.id=auth.uid() AND p.activo AND lower(btrim(x.valor))=lower(btrim(p_area)));
$$;

-- Todas las escrituras de HU-012 pasan por esta operación atómica y auditada.
CREATE OR REPLACE FUNCTION public.administrar_catalogo_hu012(
  p_entidad TEXT, p_accion TEXT, p_id UUID DEFAULT NULL, p_datos JSONB DEFAULT '{}'::JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_id UUID := p_id; v_area public.areas%ROWTYPE; v_fin public.financiamientos%ROWTYPE;
  v_antes JSONB; v_despues JSONB; v_codigo TEXT; v_nombre TEXT; v_tipo TEXT;
  v_porcentaje NUMERIC; v_meds JSONB; v_cobertura JSONB; v_numero TEXT;
BEGIN
  IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
    RAISE EXCEPTION 'Solo Administrador puede gestionar estos catálogos.' USING ERRCODE='42501';
  END IF;
  IF p_entidad NOT IN ('AREA','FINANCIAMIENTO') OR p_entidad IS NULL
    OR p_accion NOT IN ('GUARDAR','ESTADO','ELIMINAR') OR p_accion IS NULL THEN
    RAISE EXCEPTION 'Operación de catálogo inválida.';
  END IF;
  -- Serializa cambios del catálogo y evita renombres duplicados concurrentes.
  PERFORM pg_advisory_xact_lock(12012,1);
  IF p_entidad='AREA' THEN
    IF p_id IS NOT NULL THEN
      SELECT * INTO v_area FROM public.areas WHERE id=p_id FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'El área ya no existe.'; END IF;
      v_antes:=to_jsonb(v_area);
    ELSIF p_accion<>'GUARDAR' THEN RAISE EXCEPTION 'Selecciona un área.';
    END IF;
    IF p_accion='ELIMINAR' THEN
      IF v_area.codigo IN ('FARMACIA','ALMACEN')
        OR EXISTS (SELECT 1 FROM public.inventario_stock WHERE area_codigo=v_area.codigo)
        OR EXISTS (SELECT 1 FROM public.pedidos_abastecimiento WHERE area_origen=v_area.codigo OR area_destino=v_area.codigo)
        OR EXISTS (SELECT 1 FROM public.dispensaciones WHERE area_origen=v_area.codigo)
        OR EXISTS (SELECT 1 FROM public.kits WHERE area_destino=v_area.codigo)
        OR EXISTS (SELECT 1 FROM public.auditoria_trazabilidad WHERE area_origen=v_area.codigo OR area_destino=v_area.codigo)
        OR EXISTS (SELECT 1 FROM public.profile_areas WHERE area_id=p_id)
        OR EXISTS (SELECT 1 FROM public.profiles p, unnest(p.areas_asignadas) x(valor)
          WHERE lower(btrim(x.valor)) IN (lower(v_area.codigo),lower(v_area.codigo_interno),lower(v_area.nombre))) THEN
        RAISE EXCEPTION 'El área tiene asociaciones o es necesaria para abastecimiento. Puedes deshabilitarla conservando su historial.';
      END IF;
      DELETE FROM public.areas WHERE id=p_id;
    ELSIF p_accion='ESTADO' THEN
      IF jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Estado inválido.'; END IF;
      UPDATE public.areas SET activo=(p_datos->>'activo')::BOOLEAN, updated_at=now() WHERE id=p_id RETURNING to_jsonb(areas.*) INTO v_despues;
    ELSE
      v_nombre:=btrim(p_datos->>'nombre');
      IF v_nombre IS NULL OR v_nombre='' THEN RAISE EXCEPTION 'Escribe el nombre del área.'; END IF;
      v_codigo:=upper(btrim(COALESCE(p_datos->>'codigo_interno','')));
      IF v_codigo='' AND p_id IS NULL THEN
        LOOP
          v_numero:=nextval('public.areas_codigo_interno_seq')::TEXT;
          v_codigo:='AREA-'||lpad(v_numero,greatest(3,length(v_numero)),'0');
          EXIT WHEN NOT EXISTS (SELECT 1 FROM public.areas WHERE upper(codigo_interno)=v_codigo);
        END LOOP;
      END IF;
      IF v_codigo !~ '^AREA-[0-9]{3,}$' THEN RAISE EXCEPTION 'Usa un código como AREA-001.'; END IF;
      IF EXISTS (SELECT 1 FROM public.areas WHERE upper(codigo_interno)=v_codigo AND id IS DISTINCT FROM p_id) THEN
        RAISE EXCEPTION 'Ese código interno ya está registrado.';
      END IF;
      IF EXISTS (SELECT 1 FROM public.areas WHERE lower(btrim(nombre))=lower(v_nombre) AND id IS DISTINCT FROM p_id) THEN
        RAISE EXCEPTION 'Ya existe un área con ese nombre.';
      END IF;
      IF p_id IS NULL THEN
        v_id:=gen_random_uuid();
        INSERT INTO public.areas(id,codigo,codigo_interno,nombre,descripcion,administra_stock)
          VALUES(v_id,'AREA_'||replace(v_id::TEXT,'-',''),v_codigo,v_nombre,NULLIF(btrim(p_datos->>'descripcion'),''),COALESCE((p_datos->>'administra_stock')::BOOLEAN,false))
          RETURNING to_jsonb(areas.*) INTO v_despues;
      ELSE
        UPDATE public.areas SET codigo_interno=v_codigo,nombre=v_nombre,
          descripcion=NULLIF(btrim(p_datos->>'descripcion'),''),
          administra_stock=COALESCE((p_datos->>'administra_stock')::BOOLEAN,administra_stock),updated_at=now()
          WHERE id=p_id RETURNING to_jsonb(areas.*) INTO v_despues;
        -- Cambiar el nombre/código visible no pierde asignaciones históricas.
        UPDATE public.profiles p SET areas_asignadas=ARRAY(
          SELECT CASE WHEN lower(btrim(x)) IN (lower(v_area.nombre),lower(v_area.codigo_interno)) THEN v_area.codigo ELSE x END
          FROM unnest(p.areas_asignadas) x)
        WHERE EXISTS (SELECT 1 FROM unnest(p.areas_asignadas) x WHERE lower(btrim(x)) IN (lower(v_area.nombre),lower(v_area.codigo_interno)));
      END IF;
    END IF;
  ELSE
    IF p_id IS NOT NULL THEN
      SELECT * INTO v_fin FROM public.financiamientos WHERE id=p_id FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'El seguro/convenio ya no existe.'; END IF;
      SELECT COALESCE(jsonb_agg(medicamento_id ORDER BY medicamento_id),'[]'::JSONB) INTO v_cobertura
        FROM public.financiamiento_medicamentos WHERE financiamiento_id=p_id;
      v_antes:=to_jsonb(v_fin)||jsonb_build_object('medicamentos',v_cobertura);
    ELSIF p_accion<>'GUARDAR' THEN RAISE EXCEPTION 'Selecciona un seguro/convenio.';
    END IF;
    IF p_accion='ELIMINAR' THEN
      IF EXISTS (SELECT 1 FROM public.dispensaciones WHERE financiamiento_id=p_id) THEN
        RAISE EXCEPTION 'Tiene fichas asociadas. Deshabilítalo para conservar el historial.';
      END IF;
      DELETE FROM public.financiamientos WHERE id=p_id;
    ELSIF p_accion='ESTADO' THEN
      IF jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Estado inválido.'; END IF;
      UPDATE public.financiamientos SET activo=(p_datos->>'activo')::BOOLEAN,updated_at=now() WHERE id=p_id
        RETURNING to_jsonb(financiamientos.*) INTO v_despues;
      v_despues:=v_despues||jsonb_build_object('medicamentos',v_cobertura);
    ELSE
      v_nombre:=btrim(p_datos->>'nombre'); v_tipo:=p_datos->>'tipo';
      v_porcentaje:=(p_datos->>'porcentaje_descuento')::NUMERIC;
      v_meds:=p_datos->'medicamentos';
      IF v_nombre IS NULL OR v_nombre='' OR v_tipo IS NULL OR v_tipo NOT IN ('SEGURO','CONVENIO')
        OR v_porcentaje IS NULL OR v_porcentaje<0 OR v_porcentaje>100
        OR jsonb_typeof(v_meds) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Revisa nombre, tipo, descuento y cobertura.'; END IF;
      IF EXISTS (SELECT 1 FROM public.financiamientos WHERE tipo=v_tipo AND lower(btrim(nombre))=lower(v_nombre) AND id IS DISTINCT FROM p_id) THEN
        RAISE EXCEPTION 'Ya existe ese nombre en el tipo seleccionado.';
      END IF;
      IF EXISTS (SELECT 1 FROM jsonb_array_elements_text(v_meds) x(id)
        WHERE NOT EXISTS (SELECT 1 FROM public.medicamentos m WHERE m.id=x.id::UUID)) THEN RAISE EXCEPTION 'Hay medicamentos que ya no existen.'; END IF;
      IF p_id IS NULL THEN
        INSERT INTO public.financiamientos(nombre,descripcion,tipo,porcentaje_descuento)
        VALUES(v_nombre,NULLIF(btrim(p_datos->>'descripcion'),''),v_tipo,round(v_porcentaje,2)) RETURNING id INTO v_id;
      ELSE
        UPDATE public.financiamientos SET nombre=v_nombre,descripcion=NULLIF(btrim(p_datos->>'descripcion'),''),
          tipo=v_tipo,porcentaje_descuento=round(v_porcentaje,2),updated_at=now() WHERE id=p_id;
      END IF;
      DELETE FROM public.financiamiento_medicamentos WHERE financiamiento_id=v_id;
      INSERT INTO public.financiamiento_medicamentos(financiamiento_id,medicamento_id)
        SELECT DISTINCT v_id,x.id::UUID FROM jsonb_array_elements_text(v_meds) x(id);
      SELECT to_jsonb(f.*)||jsonb_build_object('medicamentos',v_meds) INTO v_despues FROM public.financiamientos f WHERE id=v_id;
    END IF;
  END IF;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,estado_anterior,estado_nuevo,descripcion)
    VALUES('CATALOGO_'||p_accion,v_id,CASE WHEN p_entidad='AREA' THEN 'areas' ELSE 'financiamientos' END,
      auth.uid(),v_antes,v_despues,'Administración de catálogo: '||p_entidad);
  RETURN v_id;
END;
$$;

ALTER TABLE public.profile_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financiamientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financiamiento_medicamentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hu012_asignaciones_lectura ON public.profile_areas;
CREATE POLICY hu012_asignaciones_lectura ON public.profile_areas FOR SELECT TO authenticated
  USING (profile_id=auth.uid() OR public.sitra_rol_actual()='ADMINISTRADOR');
DROP POLICY IF EXISTS hu012_financiamientos_lectura ON public.financiamientos;
CREATE POLICY hu012_financiamientos_lectura ON public.financiamientos FOR SELECT TO authenticated
  USING (public.sitra_rol_actual() IS NOT NULL);
DROP POLICY IF EXISTS hu012_cobertura_lectura ON public.financiamiento_medicamentos;
CREATE POLICY hu012_cobertura_lectura ON public.financiamiento_medicamentos FOR SELECT TO authenticated
  USING (public.sitra_rol_actual() IS NOT NULL);
REVOKE ALL ON public.profile_areas,public.financiamientos,public.financiamiento_medicamentos FROM anon,authenticated;
GRANT SELECT ON public.profile_areas,public.financiamientos,public.financiamiento_medicamentos TO authenticated;
REVOKE INSERT,UPDATE,DELETE ON public.areas FROM authenticated;
REVOKE ALL ON SEQUENCE public.areas_codigo_interno_seq FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.administrar_catalogo_hu012(TEXT,TEXT,UUID,JSONB) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.administrar_catalogo_hu012(TEXT,TEXT,UUID,JSONB) TO authenticated;
REVOKE ALL ON FUNCTION public.cotizar_medicamento_hu012(UUID,UUID) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.cotizar_medicamento_hu012(UUID,UUID) TO authenticated;
REVOKE ALL ON FUNCTION public.hu012_validar_ficha(), public.hu012_validar_area_nueva(),public.hu012_sincronizar_areas_perfil() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.hu012_validar_stock_area() FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
