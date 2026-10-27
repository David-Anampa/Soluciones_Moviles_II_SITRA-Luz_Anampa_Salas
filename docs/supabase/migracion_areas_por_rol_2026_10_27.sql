-- HU-020/HU-021/HU-022: áreas coherentes con el rol.
-- Aplicar después de migracion_nombre_usuario_mayusculas_2026_10_27.sql.
-- No modifica perfiles existentes; valida únicamente futuras altas y ediciones.
BEGIN;

CREATE OR REPLACE FUNCTION public.hu021_normalizar_perfil(p_datos JSONB, p_id UUID DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SET search_path = '' AS $$
DECLARE
  v_nombres TEXT; v_apellidos TEXT; v_usuario TEXT; v_cargo TEXT; v_rol TEXT;
  v_colegio TEXT; v_numero TEXT; v_especialidad TEXT;
  v_token TEXT; v_codigo TEXT; v_areas TEXT[] := '{}';
BEGIN
  IF p_datos IS NULL OR jsonb_typeof(p_datos) <> 'object' THEN
    RAISE EXCEPTION 'Datos de usuario inválidos.';
  END IF;

  v_nombres   := regexp_replace(btrim(COALESCE(p_datos->>'nombres', '')), '\s+', ' ', 'g');
  v_apellidos := regexp_replace(btrim(COALESCE(p_datos->>'apellidos', '')), '\s+', ' ', 'g');
  IF length(v_nombres) < 2 OR length(v_nombres) > 80 THEN
    RAISE EXCEPTION 'Escribe los nombres (2 a 80 caracteres).';
  END IF;
  IF length(v_apellidos) < 2 OR length(v_apellidos) > 80 THEN
    RAISE EXCEPTION 'Escribe los apellidos (2 a 80 caracteres).';
  END IF;

  v_usuario := btrim(COALESCE(p_datos->>'nombre_usuario', ''));
  IF v_usuario !~ '^[A-Za-z0-9][A-Za-z0-9_.-]{2,31}$' OR v_usuario !~ '[A-Za-z]' THEN
    RAISE EXCEPTION 'El nombre de usuario debe tener 3 a 32 caracteres e incluir al menos una letra. Se permiten letras, números, punto, guion o guion bajo.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE lower(btrim(nombre_usuario)) = lower(v_usuario) AND id IS DISTINCT FROM p_id) THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END IF;

  v_cargo := NULLIF(btrim(COALESCE(p_datos->>'cargo', '')), '');
  IF v_cargo IS NOT NULL AND length(v_cargo) > 80 THEN
    RAISE EXCEPTION 'El cargo no puede superar 80 caracteres.';
  END IF;

  -- Datos opcionales: colegio y número se completan juntos.
  -- Conservar ceros iniciales no equivale a verificar habilitación profesional.
  v_colegio := NULLIF(upper(btrim(COALESCE(p_datos->>'colegio_codigo',''))),'');
  v_numero := NULLIF(btrim(COALESCE(p_datos->>'numero_colegiatura','')),'');
  v_especialidad := NULLIF(btrim(COALESCE(p_datos->>'especialidad_codigo','')),'');
  IF v_colegio IS NULL THEN
    IF v_numero IS NOT NULL OR v_especialidad IS NOT NULL THEN
      RAISE EXCEPTION 'Selecciona el colegio profesional de la colegiatura o especialidad.';
    END IF;
  ELSE
    IF v_numero IS NULL OR v_numero !~ '^[0-9]{1,20}$' THEN
      RAISE EXCEPTION 'Ingresa el número de colegiatura (solo dígitos, máximo 20).';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.colegios_profesionales WHERE codigo=v_colegio) THEN
      RAISE EXCEPTION 'Colegio profesional desconocido.';
    END IF;
    IF v_especialidad IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.especialidades_profesionales
      WHERE codigo=v_especialidad AND colegio_codigo=v_colegio
    ) THEN RAISE EXCEPTION 'La especialidad no corresponde al colegio profesional.'; END IF;
  END IF;

  v_rol := p_datos->>'rol';
  IF v_rol IS NULL OR v_rol NOT IN ('ADMINISTRADOR','JEFATURA_FARMACIA','FARMACIA','ALMACEN','ENFERMERIA') THEN
    RAISE EXCEPTION 'Selecciona un rol válido.';
  END IF;

  IF jsonb_typeof(p_datos->'areas') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Las áreas asignadas deben enviarse como una lista.';
  END IF;
  -- Cada área se guarda con su alias operativo (areas.codigo). Una asignación
  -- histórica desconocida solo se conserva si el usuario ya la tenía.
  FOR v_token IN SELECT DISTINCT btrim(x) FROM jsonb_array_elements_text(p_datos->'areas') AS t(x) LOOP
    v_codigo := NULL;
    SELECT a.codigo INTO v_codigo FROM public.areas a
      WHERE upper(a.codigo) = upper(v_token) OR upper(a.codigo_interno) = upper(v_token)
         OR lower(a.nombre) = lower(v_token)
      ORDER BY a.id LIMIT 1;
    IF v_codigo IS NOT NULL THEN
      v_areas := v_areas || v_codigo;
    ELSIF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_id AND v_token = ANY(areas_asignadas)) THEN
      v_areas := v_areas || v_token;
    ELSE
      RAISE EXCEPTION 'Área desconocida: %', v_token;
    END IF;
  END LOOP;

  -- Regla de asignación: solo Enfermería/Técnico selecciona áreas clínicas.
  v_areas := ARRAY(SELECT DISTINCT unnest(v_areas) ORDER BY 1);
  IF v_rol = 'ENFERMERIA' THEN
    IF EXISTS (
      SELECT 1 FROM unnest(v_areas) AS asignada(codigo)
      LEFT JOIN public.areas a ON a.codigo = asignada.codigo
      WHERE upper(translate(btrim(asignada.codigo),'ÁÉÍÓÚáéíóú','AEIOUaeiou'))
              ~ '^(FARMACIA|ALMACEN|JEFATURA)([ _-]|$)'
         OR upper(translate(btrim(COALESCE(a.nombre,'')),'ÁÉÍÓÚáéíóú','AEIOUaeiou'))
              ~ '^(FARMACIA|ALMACEN|JEFATURA)([ _-]|$)'
    ) THEN
      RAISE EXCEPTION 'Enfermería/Técnico solo puede asignarse a áreas clínicas, no a Farmacia, Almacén o Jefatura.';
    END IF;
  ELSIF v_rol = 'ADMINISTRADOR' THEN
    IF cardinality(v_areas) <> 0 THEN
      RAISE EXCEPTION 'Administrador tiene acceso global por su rol y no requiere áreas asignadas.';
    END IF;
  ELSE
    v_codigo := CASE WHEN v_rol = 'ALMACEN' THEN 'ALMACEN' ELSE 'FARMACIA' END;
    IF cardinality(v_areas) <> 1 OR v_areas[1] IS DISTINCT FROM v_codigo THEN
      RAISE EXCEPTION 'El rol % debe estar asignado únicamente al área %.', v_rol, v_codigo;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'nombres', v_nombres, 'apellidos', v_apellidos,
    'nombre', v_nombres || ' ' || v_apellidos,
    'nombre_usuario', v_usuario, 'cargo', v_cargo,
    'colegio_codigo',v_colegio,'numero_colegiatura',v_numero,'especialidad_codigo',v_especialidad,
    'rol', v_rol, 'areas', to_jsonb(ARRAY(SELECT DISTINCT unnest(v_areas) ORDER BY 1)));
END;
$$;
REVOKE ALL ON FUNCTION public.hu021_normalizar_perfil(JSONB, UUID) FROM PUBLIC, anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
