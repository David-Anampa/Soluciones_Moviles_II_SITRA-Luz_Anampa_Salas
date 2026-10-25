-- HU-020/HU-021/HU-022: un único correo para acceso y futura vinculación con Drive.
-- Aplicar DESPUÉS de las migraciones HU-020 y HU-021/HU-022 del 15 y 22 de octubre.
-- No modifica correos de Auth. Conserva correo_drive como columna heredada sin
-- utilizarla ni borrar sus valores; la aplicación usa exclusivamente profiles.email.
-- La autorización de Google y la carpeta de destino corresponden a HU-027.
-- HU-020 (habilitación), HU-021 (crear usuario) y HU-022 (editar usuario).
-- Ejecutar después de migracion_hu020_estructura_usuarios_2026_10_15.sql.
-- No crea cuentas de Supabase Auth: eso lo hace la Edge Function `crear-usuario`,
-- que usa la clave service-role en el servidor (nunca dentro de Flutter).
BEGIN;

-- Cambia el contrato de lectura; DROP sin CASCADE conserva la seguridad ante dependencias.
DROP FUNCTION IF EXISTS public.listar_usuarios_hu020(INTEGER,INTEGER);
CREATE OR REPLACE FUNCTION public.listar_usuarios_hu020(p_desde INTEGER DEFAULT 0,p_limite INTEGER DEFAULT 200)
RETURNS TABLE(id UUID,nombre_usuario TEXT,nombres TEXT,apellidos TEXT,nombre TEXT,email TEXT,
  cargo TEXT,rol TEXT,areas_asignadas TEXT[],activo BOOLEAN,
  created_at TIMESTAMPTZ,updated_at TIMESTAMPTZ)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
    RAISE EXCEPTION 'Solo Administrador puede consultar la gestión de usuarios.' USING ERRCODE='42501';
  END IF;
  IF p_desde IS NULL OR p_desde<0 OR p_limite IS NULL OR p_limite<1 OR p_limite>500 THEN
    RAISE EXCEPTION 'Paginación inválida.';
  END IF;
  RETURN QUERY SELECT p.id,p.nombre_usuario,p.nombres,p.apellidos,p.nombre,p.email,
    p.cargo,p.rol,p.areas_asignadas,p.activo,p.created_at,p.updated_at
    FROM public.profiles p ORDER BY lower(p.nombre),p.id OFFSET p_desde LIMIT p_limite;
END;
$$;
REVOKE ALL ON FUNCTION public.listar_usuarios_hu020(INTEGER,INTEGER) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.listar_usuarios_hu020(INTEGER,INTEGER) TO authenticated;



-- Validación y normalización ÚNICA de los datos de perfil. La reutilizan la
-- edición (administrar_usuario_hu020) y el alta (registrar_perfil_usuario_hu021),
-- de modo que ambas operaciones aplican exactamente las mismas reglas.
-- Recibe el JSON enviado por la app y, opcionalmente, el UUID del perfil que se
-- edita (para excluirlo de las comprobaciones de unicidad). Devuelve el JSON
-- normalizado o lanza una excepción con un mensaje apto para mostrar al usuario.
CREATE OR REPLACE FUNCTION public.hu021_normalizar_perfil(p_datos JSONB, p_id UUID DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SET search_path = '' AS $$
DECLARE
  v_nombres TEXT; v_apellidos TEXT; v_usuario TEXT; v_cargo TEXT; v_rol TEXT;
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

  v_usuario := lower(btrim(COALESCE(p_datos->>'nombre_usuario', '')));
  IF v_usuario !~ '^[a-z0-9][a-z0-9_.-]{2,31}$' THEN
    RAISE EXCEPTION 'El nombre de usuario debe tener 3 a 32 caracteres: minúsculas, números, punto, guion o guion bajo.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.profiles
             WHERE lower(btrim(nombre_usuario)) = v_usuario AND id IS DISTINCT FROM p_id) THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END IF;

  v_cargo := NULLIF(btrim(COALESCE(p_datos->>'cargo', '')), '');
  IF v_cargo IS NOT NULL AND length(v_cargo) > 80 THEN
    RAISE EXCEPTION 'El cargo no puede superar 80 caracteres.';
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

  RETURN jsonb_build_object(
    'nombres', v_nombres, 'apellidos', v_apellidos,
    'nombre', v_nombres || ' ' || v_apellidos,
    'nombre_usuario', v_usuario, 'cargo', v_cargo,
    'rol', v_rol, 'areas', to_jsonb(ARRAY(SELECT DISTINCT unnest(v_areas) ORDER BY 1)));
END;
$$;
REVOKE ALL ON FUNCTION public.hu021_normalizar_perfil(JSONB, UUID) FROM PUBLIC, anon, authenticated;

-- Edición y habilitación de usuarios (HU-020 / HU-022). Solo Administrador activo.
-- p_accion: EDITAR (usa p_datos con los campos del perfil) o ESTADO (p_datos.activo).
-- Reglas de seguridad: no se puede deshabilitar ni quitar el rol a la propia cuenta
-- y siempre debe quedar al menos un Administrador activo. El correo no se edita aquí
-- porque pertenece a Supabase Auth. Registra el antes/después sin tokens FCM.
CREATE OR REPLACE FUNCTION public.administrar_usuario_hu020(
  p_accion TEXT, p_id UUID, p_datos JSONB DEFAULT '{}'::JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_antes public.profiles%ROWTYPE; v_normal JSONB; v_despues JSONB; v_activo BOOLEAN;
  v_pierde_admin BOOLEAN;
BEGIN
  IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
    RAISE EXCEPTION 'Solo Administrador puede gestionar usuarios.' USING ERRCODE = '42501';
  END IF;
  IF p_accion IS NULL OR p_accion NOT IN ('EDITAR','ESTADO') OR p_id IS NULL THEN
    RAISE EXCEPTION 'Operación de usuario inválida.';
  END IF;
  -- Serializa los cambios para que dos administradores no dejen el sistema sin ninguno activo.
  PERFORM pg_advisory_xact_lock(12020, 2);
  SELECT * INTO v_antes FROM public.profiles WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El usuario ya no existe.'; END IF;

  IF p_accion = 'ESTADO' THEN
    IF jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN
      RAISE EXCEPTION 'Estado inválido.';
    END IF;
    v_activo := (p_datos->>'activo')::BOOLEAN;
    v_pierde_admin := NOT v_activo;
  ELSE
    v_normal := public.hu021_normalizar_perfil(p_datos, p_id);
    v_pierde_admin := (v_normal->>'rol') <> 'ADMINISTRADOR';
    IF p_id = auth.uid() AND (v_normal->>'rol') <> v_antes.rol THEN
      RAISE EXCEPTION 'No puedes cambiar el rol de tu propia cuenta.';
    END IF;
  END IF;

  IF p_accion = 'ESTADO' AND NOT v_activo AND p_id = auth.uid() THEN
    RAISE EXCEPTION 'No puedes deshabilitar tu propia cuenta.';
  END IF;
  IF v_pierde_admin AND v_antes.rol = 'ADMINISTRADOR' AND v_antes.activo AND NOT EXISTS (
       SELECT 1 FROM public.profiles WHERE rol = 'ADMINISTRADOR' AND activo AND id <> p_id) THEN
    RAISE EXCEPTION 'Debe quedar al menos un Administrador activo.';
  END IF;

  BEGIN
    IF p_accion = 'ESTADO' THEN
      UPDATE public.profiles SET activo = v_activo, updated_at = now() WHERE id = p_id;
    ELSE
      UPDATE public.profiles SET
        nombres = v_normal->>'nombres', apellidos = v_normal->>'apellidos',
        nombre = v_normal->>'nombre', nombre_usuario = v_normal->>'nombre_usuario',
        cargo = v_normal->>'cargo',
        rol = v_normal->>'rol',
        areas_asignadas = ARRAY(SELECT jsonb_array_elements_text(v_normal->'areas')),
        updated_at = now()
      WHERE id = p_id;
    END IF;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END;

  SELECT to_jsonb(p.*) - 'fcm_token' - 'correo_drive' INTO v_despues FROM public.profiles p WHERE p.id = p_id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_anterior, estado_nuevo, descripcion)
  VALUES('USUARIO_' || p_accion, p_id, 'profiles', auth.uid(),
    to_jsonb(v_antes) - 'fcm_token' - 'correo_drive', v_despues, 'Administración de usuario: ' || p_accion);
  RETURN p_id;
END;
$$;
REVOKE ALL ON FUNCTION public.administrar_usuario_hu020(TEXT, UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.administrar_usuario_hu020(TEXT, UUID, JSONB) TO authenticated;

-- Completa y activa el perfil de una cuenta recién creada en Supabase Auth (HU-021).
-- SOLO la Edge Function `crear-usuario` puede llamarla (rol service_role): la función
-- recibe el UUID del administrador que solicita el alta y lo vuelve a validar.
-- El perfil lo crea handle_new_user con activo = false; esta función solo acepta
-- perfiles en ese estado para que no pueda reutilizarse sobre usuarios existentes.
CREATE OR REPLACE FUNCTION public.registrar_perfil_usuario_hu021(
  p_admin_id UUID, p_id UUID, p_datos JSONB
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_normal JSONB; v_despues JSONB;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = p_admin_id AND rol = 'ADMINISTRADOR' AND activo) THEN
    RAISE EXCEPTION 'Solo Administrador puede crear usuarios.' USING ERRCODE = '42501';
  END IF;
  PERFORM pg_advisory_xact_lock(12020, 2);
  v_normal := public.hu021_normalizar_perfil(p_datos, p_id);
  BEGIN
    UPDATE public.profiles SET
      nombres = v_normal->>'nombres', apellidos = v_normal->>'apellidos',
      nombre = v_normal->>'nombre', nombre_usuario = v_normal->>'nombre_usuario',
      cargo = v_normal->>'cargo',
      rol = v_normal->>'rol',
      areas_asignadas = ARRAY(SELECT jsonb_array_elements_text(v_normal->'areas')),
      activo = true, updated_at = now()
    WHERE id = p_id AND activo = false;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
  END;
  IF NOT FOUND THEN RAISE EXCEPTION 'No se encontró el perfil pendiente de la nueva cuenta.'; END IF;

  SELECT to_jsonb(p.*) - 'fcm_token' - 'correo_drive' INTO v_despues FROM public.profiles p WHERE p.id = p_id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_nuevo, descripcion)
  VALUES('USUARIO_CREAR', p_id, 'profiles', p_admin_id, v_despues, 'Alta de usuario');
  RETURN p_id;
END;
$$;
REVOKE ALL ON FUNCTION public.registrar_perfil_usuario_hu021(UUID, UUID, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_perfil_usuario_hu021(UUID, UUID, JSONB) TO service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
