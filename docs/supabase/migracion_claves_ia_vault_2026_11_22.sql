BEGIN;
CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;
REVOKE ALL ON vault.secrets, vault.decrypted_secrets FROM anon, authenticated;

-- La tabla pública contiene únicamente metadatos. El secreto vive cifrado en Vault.
CREATE TABLE IF NOT EXISTS public.claves_ia (
  id UUID PRIMARY KEY,
  nombre TEXT NOT NULL CHECK (char_length(nombre) BETWEEN 2 AND 60),
  activa BOOLEAN NOT NULL DEFAULT false,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  creado_por UUID REFERENCES public.profiles(id),
  actualizado_por UUID REFERENCES public.profiles(id)
);
CREATE UNIQUE INDEX IF NOT EXISTS claves_ia_una_activa ON public.claves_ia(activa) WHERE activa;
ALTER TABLE public.claves_ia ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.claves_ia FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.exigir_admin_claves_ia() RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND activo AND rol='ADMINISTRADOR') THEN
    RAISE EXCEPTION 'Solo Administrador puede gestionar las claves.' USING ERRCODE='42501';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.exigir_admin_claves_ia() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.listar_claves_ia() RETURNS SETOF public.claves_ia
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM public.exigir_admin_claves_ia();
  RETURN QUERY SELECT * FROM public.claves_ia ORDER BY activa DESC, creado_en DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.listar_claves_ia() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.listar_claves_ia() TO authenticated;

CREATE OR REPLACE FUNCTION public.gestionar_clave_ia(
  p_accion TEXT, p_id UUID DEFAULT NULL, p_nombre TEXT DEFAULT NULL, p_clave TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, vault, pg_temp AS $$
DECLARE
  v_id UUID := p_id;
  v_nombre TEXT := btrim(p_nombre);
  v_antes public.claves_ia;
  v_despues public.claves_ia;
BEGIN
  PERFORM public.exigir_admin_claves_ia();
  -- Serializa el cambio de clave activa y las eliminaciones concurrentes.
  LOCK TABLE public.claves_ia IN EXCLUSIVE MODE;
  IF p_accion NOT IN ('CREAR','EDITAR','ACTIVAR','ELIMINAR') OR p_accion IS NULL THEN
    RAISE EXCEPTION 'Acción de clave no válida.' USING ERRCODE='22023';
  END IF;
  IF p_accion IN ('CREAR','EDITAR') AND (v_nombre IS NULL OR char_length(v_nombre) NOT BETWEEN 2 AND 60) THEN
    RAISE EXCEPTION 'El nombre debe tener entre 2 y 60 caracteres.' USING ERRCODE='22023';
  END IF;
  IF p_accion='CREAR' AND COALESCE(p_clave,'')='' THEN
    RAISE EXCEPTION 'Ingresa la nueva clave.' USING ERRCODE='22023';
  END IF;
  IF p_clave IS NOT NULL AND (char_length(p_clave) NOT BETWEEN 20 AND 200 OR p_clave ~ '\s') THEN
    RAISE EXCEPTION 'La clave no tiene un formato válido.' USING ERRCODE='22023';
  END IF;
  IF p_accion <> 'CREAR' THEN
    SELECT * INTO v_antes FROM public.claves_ia WHERE id=p_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'La clave ya no existe.' USING ERRCODE='22023'; END IF;
  END IF;
  IF p_clave IS NOT NULL AND EXISTS (
    SELECT 1 FROM vault.decrypted_secrets s JOIN public.claves_ia c ON c.id=s.id
    WHERE s.decrypted_secret=p_clave AND (p_id IS NULL OR c.id<>p_id)
  ) THEN RAISE EXCEPTION 'Esta clave ya está registrada.' USING ERRCODE='22023'; END IF;

  IF p_accion='CREAR' THEN
    v_id := vault.create_secret(p_clave);
    INSERT INTO public.claves_ia(id,nombre,activa,creado_por,actualizado_por)
    VALUES(v_id,v_nombre,NOT EXISTS(SELECT 1 FROM public.claves_ia),auth.uid(),auth.uid());
  ELSIF p_accion='EDITAR' THEN
    IF p_clave IS NOT NULL THEN PERFORM vault.update_secret(p_id,p_clave); END IF;
    UPDATE public.claves_ia SET nombre=v_nombre,actualizado_en=now(),actualizado_por=auth.uid() WHERE id=p_id;
  ELSIF p_accion='ACTIVAR' THEN
    UPDATE public.claves_ia SET activa=false,actualizado_en=now(),actualizado_por=auth.uid() WHERE activa AND id<>p_id;
    UPDATE public.claves_ia SET activa=true,actualizado_en=now(),actualizado_por=auth.uid() WHERE id=p_id;
  ELSE
    DELETE FROM public.claves_ia WHERE id=p_id;
    DELETE FROM vault.secrets WHERE id=p_id;
    -- No activar otra automáticamente al eliminar la que estaba en uso.
  END IF;
  SELECT * INTO v_despues FROM public.claves_ia WHERE id=v_id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento,tabla_referencia,entidad_referencia_id,usuario_id,descripcion,estado_anterior,estado_nuevo)
  VALUES('CLAVE_IA_'||p_accion,'claves_ia',v_id,auth.uid(),'Gestión administrativa de credencial Gemini',
    CASE WHEN p_accion='CREAR' THEN NULL ELSE to_jsonb(v_antes) END,
    CASE WHEN p_accion='ELIMINAR' THEN NULL ELSE to_jsonb(v_despues) END);
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.gestionar_clave_ia(TEXT,UUID,TEXT,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gestionar_clave_ia(TEXT,UUID,TEXT,TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.estado_clave_ia() RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND activo AND rol IN ('ADMINISTRADOR','ALMACEN')) THEN
    RAISE EXCEPTION 'Sin permiso para consultar el servicio IA.' USING ERRCODE='42501';
  END IF;
  RETURN EXISTS(SELECT 1 FROM public.claves_ia WHERE activa);
END;
$$;
REVOKE ALL ON FUNCTION public.estado_clave_ia() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.estado_clave_ia() TO authenticated;

-- Solo la Edge Function con service_role puede obtener la credencial descifrada.
CREATE OR REPLACE FUNCTION public.credencial_gemini_servidor()
RETURNS TABLE(id UUID, clave TEXT) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, vault, pg_temp AS $$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Acceso reservado al servidor.' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT c.id,s.decrypted_secret FROM public.claves_ia c JOIN vault.decrypted_secrets s ON s.id=c.id WHERE c.activa;
END;
$$;
REVOKE ALL ON FUNCTION public.credencial_gemini_servidor() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.credencial_gemini_servidor() TO service_role;

-- Importa solo la última configuración vigente; no reactiva claves eliminadas.
DO $$
DECLARE v_legacy RECORD; v_id UUID;
BEGIN
  SELECT estado_nuevo,usuario_id,fecha INTO v_legacy FROM public.auditoria_trazabilidad
  WHERE tipo_evento='CONFIG_GEMINI_IA' AND area_destino='ALMACEN' AND estado_nuevo ? 'gemini_api_key'
  ORDER BY fecha DESC,id DESC LIMIT 1;
  IF FOUND AND NOT EXISTS(SELECT 1 FROM public.claves_ia) AND
     COALESCE(v_legacy.estado_nuevo->>'gemini_api_key','')<>'' AND
     COALESCE(v_legacy.estado_nuevo->>'limpiada','false')<>'true' THEN
    v_id := vault.create_secret(v_legacy.estado_nuevo->>'gemini_api_key');
    INSERT INTO public.claves_ia(id,nombre,activa,creado_por,actualizado_por,creado_en,actualizado_en)
    VALUES(v_id,'Clave principal migrada',true,v_legacy.usuario_id,v_legacy.usuario_id,v_legacy.fecha,now());
  END IF;
  -- Conserva eventos y fechas históricos, retirando únicamente el secreto expuesto.
  UPDATE public.auditoria_trazabilidad
  SET estado_nuevo=(estado_nuevo-'gemini_api_key')||jsonb_build_object('secreto_retirado',true)
  WHERE tipo_evento='CONFIG_GEMINI_IA' AND estado_nuevo ? 'gemini_api_key';
  UPDATE public.auditoria_trazabilidad SET estado_anterior=estado_anterior-'gemini_api_key'
  WHERE tipo_evento='CONFIG_GEMINI_IA' AND estado_anterior ? 'gemini_api_key';
END;
$$;

CREATE OR REPLACE FUNCTION public.impedir_clave_ia_en_auditoria() RETURNS TRIGGER
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
  IF NEW.tipo_evento='CONFIG_GEMINI_IA' AND
    (COALESCE(NEW.estado_nuevo ? 'gemini_api_key',false) OR COALESCE(NEW.estado_anterior ? 'gemini_api_key',false)) THEN
    RAISE EXCEPTION 'Actualiza la aplicación para gestionar claves de forma segura.' USING ERRCODE='22023';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS impedir_clave_ia_en_auditoria ON public.auditoria_trazabilidad;
CREATE TRIGGER impedir_clave_ia_en_auditoria BEFORE INSERT OR UPDATE ON public.auditoria_trazabilidad
FOR EACH ROW EXECUTE FUNCTION public.impedir_clave_ia_en_auditoria();
NOTIFY pgrst,'reload schema';
COMMIT;
