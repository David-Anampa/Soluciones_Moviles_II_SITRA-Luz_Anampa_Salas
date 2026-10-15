-- HU-020: estructura y consulta administrativa de usuarios.
-- Ejecutar después de migracion_hu012_catalogos_2026_10_15.sql.
-- No crea cuentas ni cambia credenciales. Supabase Auth conserva las contraseñas.
BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS nombre_usuario TEXT,
  ADD COLUMN IF NOT EXISTS nombres TEXT,
  ADD COLUMN IF NOT EXISTS apellidos TEXT;

-- Conserva nombre (nombre completo actual) sin intentar adivinar apellidos.
-- Asigna identificadores únicos a perfiles anteriores a esta estructura.
DO $$
DECLARE v_perfil RECORD; v_base TEXT; v_candidato TEXT; v_intento INTEGER;
BEGIN
  FOR v_perfil IN SELECT id,email FROM public.profiles WHERE nombre_usuario IS NULL ORDER BY created_at,id LOOP
    v_base:=left(regexp_replace(lower(split_part(COALESCE(v_perfil.email,''),'@',1)), '[^a-z0-9_.-]','','g'),24);
    IF length(v_base)<3 THEN v_base:='usuario'; END IF;
    v_candidato:=v_base; v_intento:=0;
    WHILE EXISTS (SELECT 1 FROM public.profiles WHERE lower(nombre_usuario)=v_candidato AND id<>v_perfil.id) LOOP
      v_intento:=v_intento+1;
      v_candidato:=left(v_base,24)||'_'||v_intento::TEXT;
    END LOOP;
    UPDATE public.profiles SET nombre_usuario=v_candidato WHERE id=v_perfil.id;
  END LOOP;
END;
$$;
CREATE UNIQUE INDEX IF NOT EXISTS uq_profiles_nombre_usuario
  ON public.profiles(lower(btrim(nombre_usuario))) WHERE nombre_usuario IS NOT NULL;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS hu020_nombre_usuario_check;
ALTER TABLE public.profiles ADD CONSTRAINT hu020_nombre_usuario_check
  CHECK (nombre_usuario IS NULL OR nombre_usuario ~ '^[a-z0-9][a-z0-9_.-]{2,31}$');

-- Selección explícita: nunca devuelve fcm_token, auth.users ni contraseñas.
CREATE OR REPLACE FUNCTION public.listar_usuarios_hu020(p_desde INTEGER DEFAULT 0,p_limite INTEGER DEFAULT 200)
RETURNS TABLE(id UUID,nombre_usuario TEXT,nombres TEXT,apellidos TEXT,nombre TEXT,email TEXT,
  cargo TEXT,correo_drive TEXT,rol TEXT,areas_asignadas TEXT[],activo BOOLEAN,
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
    p.cargo,p.correo_drive,p.rol,p.areas_asignadas,p.activo,p.created_at,p.updated_at
    FROM public.profiles p ORDER BY lower(p.nombre),p.id OFFSET p_desde LIMIT p_limite;
END;
$$;
REVOKE ALL ON FUNCTION public.listar_usuarios_hu020(INTEGER,INTEGER) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.listar_usuarios_hu020(INTEGER,INTEGER) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
