-- HU-003: receptor por identidad, rol activo y asignación real de área.
-- Incremental: no crea usuarios, no cambia contraseñas ni reescribe fichas históricas.
BEGIN;

CREATE OR REPLACE FUNCTION public.validar_receptor_ficha_hu003(p_receptor_id UUID, p_area TEXT)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $receptor$
DECLARE
  v_rol TEXT;
  v_nombre TEXT;
BEGIN
  SELECT p.rol INTO v_rol FROM public.profiles p
  WHERE p.id = auth.uid() AND p.activo FOR SHARE;
  IF v_rol IS NULL OR v_rol NOT IN ('ADMINISTRADOR', 'FARMACIA', 'ENFERMERIA') THEN
    RAISE EXCEPTION 'No tienes permisos para validar el receptor de esta ficha.' USING ERRCODE = '42501';
  END IF;
  IF v_rol = 'ENFERMERIA' AND NOT EXISTS (
    SELECT 1 FROM public.profile_areas pa JOIN public.areas a ON a.id = pa.area_id
    WHERE pa.profile_id = auth.uid() AND a.codigo = btrim(p_area) AND a.activo
  ) THEN
    RAISE EXCEPTION 'No tienes acceso al área de esta ficha.' USING ERRCODE = '42501';
  END IF;
  IF p_receptor_id IS NULL THEN
    RAISE EXCEPTION 'Selecciona al personal receptor activo del área solicitante.' USING ERRCODE = '22023';
  END IF;
  SELECT p.nombre INTO v_nombre
  FROM public.profiles p
  JOIN public.profile_areas pa ON pa.profile_id = p.id
  JOIN public.areas a ON a.id = pa.area_id
  WHERE p.id = p_receptor_id AND p.activo AND p.rol = 'ENFERMERIA'
    AND a.activo AND a.codigo = btrim(p_area)
  FOR SHARE OF p, pa, a;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'El receptor debe ser personal de Enfermería/Técnico activo y asignado al área solicitante.' USING ERRCODE = '22023';
  END IF;
  RETURN v_nombre;
END;
$receptor$;
REVOKE ALL ON FUNCTION public.validar_receptor_ficha_hu003(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validar_receptor_ficha_hu003(UUID, TEXT) TO authenticated;

DO $patch_registro$
DECLARE
  v_oid REGPROCEDURE := to_regprocedure('public.registrar_ficha_hu003(uuid,uuid,jsonb)');
  v_def TEXT;
  v_old_simple TEXT;
  v_old TEXT := $registro_old$  -- Validación de Doctor a cargo
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

$registro_old$;
  v_new TEXT := $registro_new$  -- HU-003: médico obligatorio del catálogo activo; nunca nombre libre.
  IF NULLIF(btrim(COALESCE(p_datos->>'doctor_id', '')), '') IS NULL THEN
    RAISE EXCEPTION 'Selecciona un médico activo del catálogo.' USING ERRCODE = '22023';
  END IF;
  v_doctor_id := (p_datos->>'doctor_id')::UUID;
  SELECT * INTO v_doctor FROM public.doctores WHERE id = v_doctor_id AND activo FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'El médico seleccionado no está activo en el catálogo.' USING ERRCODE = '22023';
  END IF;
  v_doctor_nombre := v_doctor.nombre;

  v_receptor_id := NULLIF(btrim(COALESCE(p_datos->>'receptor_id', '')), '')::UUID;
  v_recibido_por := public.validar_receptor_ficha_hu003(v_receptor_id, v_area.codigo);

$registro_new$;
BEGIN
  IF v_oid IS NULL THEN
    RAISE EXCEPTION 'Falta instalar la función de registro HU-003 antes de esta migración.';
  END IF;
  v_def := replace(pg_get_functiondef(v_oid), chr(13), '');
  v_old_simple := regexp_replace(v_old, '^[[:blank:]]*--[^\n]*\n', '', 'gn');
  IF position(v_old IN v_def) > 0 THEN
    EXECUTE replace(v_def, v_old, v_new);
  ELSIF position(v_old_simple IN v_def) > 0 THEN
    EXECUTE replace(v_def, v_old_simple, v_new);
  ELSIF position(v_new IN v_def) = 0 THEN
    RAISE EXCEPTION 'La función registro tiene una versión no reconocida; revisar el parche sin reemplazar cambios ajenos.';
  END IF;
END;
$patch_registro$;

DO $patch_entrega$
DECLARE
  v_oid REGPROCEDURE := to_regprocedure('public.procesar_ficha_dispensacion_hu008_hu011(uuid,uuid,text,jsonb,text,text,uuid,text)');
  v_def TEXT;
  v_old_simple TEXT;
  v_old TEXT := $entrega_old$    -- Validar receptor que recibe la ficha
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

$entrega_old$;
  v_new TEXT := $entrega_new$    -- Revalidar identidad, rol y asignación vigente también al entregar.
    v_receptor_id := COALESCE(p_receptor_id, v_ficha.receptor_id);
    v_recibido_por := public.validar_receptor_ficha_hu003(v_receptor_id, v_ficha.area_origen);

$entrega_new$;
BEGIN
  IF v_oid IS NULL THEN
    RETURN; -- Sprint 7 aún no instalado: reaplicar esta migración después de instalarlo.
  END IF;
  v_def := replace(pg_get_functiondef(v_oid), chr(13), '');
  v_old_simple := regexp_replace(v_old, '^[[:blank:]]*--[^\n]*\n', '', 'gn');
  IF position(v_old IN v_def) > 0 THEN
    EXECUTE replace(v_def, v_old, v_new);
  ELSIF position(v_old_simple IN v_def) > 0 THEN
    EXECUTE replace(v_def, v_old_simple, v_new);
  ELSIF position(v_new IN v_def) = 0 THEN
    RAISE EXCEPTION 'La función entrega tiene una versión no reconocida; revisar el parche sin reemplazar cambios ajenos.';
  END IF;
END;
$patch_entrega$;

NOTIFY pgrst, 'reload schema';
COMMIT;
