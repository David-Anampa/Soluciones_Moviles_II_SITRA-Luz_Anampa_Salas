-- Amplía la paleta de 6 a 12 colores. Ejecutar después de migracion_temas_areas_2026_10_26.sql.
-- Conserva los temas actuales, los permisos y la auditoría. No modifica stock.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.guardar_area_con_tema(uuid,jsonb)') IS NULL THEN
   RAISE EXCEPTION 'Aplica primero migracion_temas_areas_2026_10_26.sql.';
 END IF;
END $$;
ALTER TABLE public.areas DROP CONSTRAINT IF EXISTS areas_tema_color_check;
ALTER TABLE public.areas ADD CONSTRAINT areas_tema_color_check
 CHECK(tema_color IN ('ROJO','AZUL','CELESTE','LAVANDA','ROSA','GRIS_AZUL','VERDE','TURQUESA','INDIGO','MORADO','TERRACOTA','AMBAR'));

CREATE OR REPLACE FUNCTION public.guardar_area_con_tema(p_id UUID DEFAULT NULL,p_datos JSONB DEFAULT '{}')
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id UUID; v_tema TEXT; v_antes JSONB;
BEGIN
 IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
   RAISE EXCEPTION 'Solo Administrador puede elegir el tema de un área.' USING ERRCODE='42501'; END IF;
 IF p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' THEN RAISE EXCEPTION 'Datos de área inválidos.'; END IF;
 v_tema:=p_datos->>'tema_color';
 IF v_tema IS NULL OR v_tema NOT IN ('ROJO','AZUL','CELESTE','LAVANDA','ROSA','GRIS_AZUL','VERDE','TURQUESA','INDIGO','MORADO','TERRACOTA','AMBAR') THEN
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
NOTIFY pgrst,'reload schema';
COMMIT;
