-- Después de migracion_kits_por_area_2026_10_26.sql. No mueve stock ni modifica fichas.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.contexto_kits_por_area()') IS NULL THEN
   RAISE EXCEPTION 'Aplica primero migracion_kits_por_area_2026_10_26.sql.';
 END IF;
END $$;
ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS tema_color TEXT NOT NULL DEFAULT 'ROJO';
ALTER TABLE public.areas DROP CONSTRAINT IF EXISTS areas_tema_color_check;
ALTER TABLE public.areas ADD CONSTRAINT areas_tema_color_check
 CHECK(tema_color IN ('ROJO','AZUL','CELESTE','LAVANDA','ROSA','GRIS_AZUL'));

-- Guardar datos y tema juntos, reutilizando las validaciones vigentes de HU-012.
-- Si falla cualquier paso se revierten el área, el tema y sus eventos de auditoría.
CREATE OR REPLACE FUNCTION public.guardar_area_con_tema(p_id UUID DEFAULT NULL,p_datos JSONB DEFAULT '{}')
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id UUID; v_tema TEXT; v_antes JSONB;
BEGIN
 IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
   RAISE EXCEPTION 'Solo Administrador puede elegir el tema de un área.' USING ERRCODE='42501'; END IF;
 IF p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' THEN RAISE EXCEPTION 'Datos de área inválidos.'; END IF;
 v_tema:=p_datos->>'tema_color';
 IF v_tema IS NULL OR v_tema NOT IN ('ROJO','AZUL','CELESTE','LAVANDA','ROSA','GRIS_AZUL') THEN
   RAISE EXCEPTION 'Selecciona un tema de la paleta disponible.'; END IF;
 PERFORM pg_advisory_xact_lock(12012,1);
 IF p_id IS NOT NULL THEN
   SELECT jsonb_build_object('tema_color',a.tema_color) INTO v_antes FROM public.areas a WHERE a.id=p_id FOR UPDATE;
 END IF;
 v_id:=public.administrar_catalogo_hu012('AREA','GUARDAR',p_id,p_datos);
 UPDATE public.areas SET tema_color=v_tema,updated_at=now() WHERE id=v_id;
 IF v_antes IS NULL OR v_antes->>'tema_color' IS DISTINCT FROM v_tema THEN
   INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,
     usuario_id,estado_anterior,estado_nuevo,descripcion)
   VALUES('AREA_TEMA',v_id,'areas',auth.uid(),v_antes,jsonb_build_object('tema_color',v_tema),
     'Tema visual del área. No modifica los colores semánticos de mensajes.');
 END IF;
 RETURN v_id;
END; $$;
REVOKE ALL ON FUNCTION public.guardar_area_con_tema(UUID,JSONB) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.guardar_area_con_tema(UUID,JSONB) TO authenticated;

-- Conserva las reglas de acceso y agrega el tema al mismo contexto consultado por Kits.
CREATE OR REPLACE FUNCTION public.contexto_kits_por_area()
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_perfil public.profiles%ROWTYPE; v_areas JSONB;
BEGIN
 SELECT * INTO v_perfil FROM public.profiles WHERE id=auth.uid() AND activo;
 IF NOT FOUND OR v_perfil.rol IS NULL OR v_perfil.rol NOT IN ('ADMINISTRADOR','JEFATURA_FARMACIA','FARMACIA','ENFERMERIA') THEN
   RAISE EXCEPTION 'No tienes permisos para consultar kits.' USING ERRCODE='42501'; END IF;
 SELECT COALESCE(jsonb_agg(jsonb_build_object('id',a.id,'codigo',a.codigo,
   'codigo_interno',a.codigo_interno,'nombre',a.nombre,'activo',a.activo,'tema_color',a.tema_color)
   ORDER BY a.nombre),'[]') INTO v_areas FROM public.areas a WHERE public.puede_consultar_area_kits(a.codigo);
 RETURN jsonb_build_object('rol',v_perfil.rol,'puede_gestionar',v_perfil.rol='ADMINISTRADOR' OR
   (v_perfil.rol='ENFERMERIA' AND v_perfil.puede_gestionar_kits AND public.cargo_habilitado_kits(v_perfil.cargo)), 'areas',v_areas);
END; $$;
REVOKE ALL ON FUNCTION public.contexto_kits_por_area() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.contexto_kits_por_area() TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
