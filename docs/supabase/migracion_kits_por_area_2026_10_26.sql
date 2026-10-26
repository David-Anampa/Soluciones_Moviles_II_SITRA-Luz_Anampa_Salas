-- HU-017/018/019: plantillas por área, permisos y disponibilidad real.
-- Aplicar después de HU-012, usuarios/colegiatura y stock en tránsito (25/10).
-- Sustituye las RPC antiguas de kits; no requiere reinstalar la migración del 22/10.
-- No toca existencias, dispensaciones ni credenciales. No ejecutar el setup en producción.
BEGIN;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS puede_gestionar_kits BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.kits ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE UNIQUE INDEX IF NOT EXISTS uq_kit_medicamento ON public.kit_items(kit_id,medicamento_id);
CREATE INDEX IF NOT EXISTS idx_kits_area_destino ON public.kits(area_destino);

-- Cargo y rol son independientes: el permiso adicional solo corresponde a personal asistencial.
CREATE OR REPLACE FUNCTION public.cargo_habilitado_kits(p_cargo TEXT)
RETURNS BOOLEAN LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT translate(lower(btrim(COALESCE(p_cargo,''))), 'áéíóú','aeiou') IN
 ('tecnica','tecnico','tecnica de enfermeria','tecnico de enfermeria',
 'enfermera','enfermero','licenciada en enfermeria','licenciado en enfermeria');
$$;

-- Protege el permiso incluso ante clientes antiguos y cambios directos de cargo/rol.
CREATE OR REPLACE FUNCTION public.proteger_permiso_kits()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='INSERT' THEN
   IF NEW.puede_gestionar_kits AND COALESCE(auth.role(),'')<>'service_role'
      AND public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
     RAISE EXCEPTION 'Solo Administrador puede asignar permisos de kits.' USING ERRCODE='42501';
   END IF;
 ELSIF NEW.puede_gestionar_kits IS DISTINCT FROM OLD.puede_gestionar_kits THEN
   IF COALESCE(auth.role(),'')<>'service_role'
      AND public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
     RAISE EXCEPTION 'Solo Administrador puede asignar permisos de kits.' USING ERRCODE='42501';
   END IF;
 END IF;
 IF NEW.rol IS DISTINCT FROM 'ENFERMERIA' OR NOT public.cargo_habilitado_kits(NEW.cargo) THEN
   NEW.puede_gestionar_kits:=false;
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS proteger_permiso_kits ON public.profiles;
CREATE TRIGGER proteger_permiso_kits BEFORE INSERT OR UPDATE ON public.profiles
 FOR EACH ROW EXECUTE FUNCTION public.proteger_permiso_kits();

-- La relación UUID evita confundir el código visible editable con la pertenencia real.
CREATE OR REPLACE FUNCTION public.puede_consultar_area_kits(p_area TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.activo AND
 (p.rol IN ('ADMINISTRADOR','JEFATURA_FARMACIA','FARMACIA') OR
 (p.rol='ENFERMERIA' AND EXISTS(SELECT 1 FROM public.profile_areas pa JOIN public.areas a ON a.id=pa.area_id
   WHERE pa.profile_id=p.id AND a.codigo=p_area))));
$$;
CREATE OR REPLACE FUNCTION public.puede_gestionar_area_kits(p_area TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.activo AND
 (p.rol='ADMINISTRADOR' OR (p.rol='ENFERMERIA' AND p.puede_gestionar_kits
 AND public.cargo_habilitado_kits(p.cargo)
 AND EXISTS(SELECT 1 FROM public.profile_areas pa JOIN public.areas a ON a.id=pa.area_id
   WHERE pa.profile_id=p.id AND a.codigo=p_area))));
$$;

-- Contexto fresco de sesión: áreas autorizadas (también históricas) y capacidad de escritura.
CREATE OR REPLACE FUNCTION public.contexto_kits_por_area()
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_perfil public.profiles%ROWTYPE; v_areas JSONB;
BEGIN
 SELECT * INTO v_perfil FROM public.profiles WHERE id=auth.uid() AND activo;
 IF NOT FOUND OR v_perfil.rol IS NULL OR v_perfil.rol NOT IN ('ADMINISTRADOR','JEFATURA_FARMACIA','FARMACIA','ENFERMERIA') THEN
   RAISE EXCEPTION 'No tienes permisos para consultar kits.' USING ERRCODE='42501'; END IF;
 SELECT COALESCE(jsonb_agg(jsonb_build_object('id',a.id,'codigo',a.codigo,
   'codigo_interno',a.codigo_interno,'nombre',a.nombre,'activo',a.activo) ORDER BY a.nombre),'[]')
 INTO v_areas FROM public.areas a WHERE public.puede_consultar_area_kits(a.codigo);
 RETURN jsonb_build_object('rol',v_perfil.rol,'puede_gestionar',
   v_perfil.rol='ADMINISTRADOR' OR (v_perfil.rol='ENFERMERIA' AND v_perfil.puede_gestionar_kits
   AND public.cargo_habilitado_kits(v_perfil.cargo)), 'areas',v_areas);
END; $$;

-- Lectura paginada del permiso para integrar el formulario administrativo sin perder colegiatura.
CREATE OR REPLACE FUNCTION public.listar_permisos_kits(p_desde INTEGER DEFAULT 0,p_limite INTEGER DEFAULT 200)
RETURNS TABLE(id UUID,puede_gestionar_kits BOOLEAN)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
   RAISE EXCEPTION 'Solo Administrador puede consultar permisos.' USING ERRCODE='42501'; END IF;
 IF p_desde IS NULL OR p_desde<0 OR p_limite IS NULL OR p_limite NOT BETWEEN 1 AND 500 THEN
   RAISE EXCEPTION 'Paginación inválida.'; END IF;
 RETURN QUERY SELECT p.id,p.puede_gestionar_kits FROM public.profiles p ORDER BY p.id OFFSET p_desde LIMIT p_limite;
END; $$;

-- Helper privado: cambia y audita el permiso dentro de la misma transacción que el perfil.
CREATE OR REPLACE FUNCTION public.asignar_permiso_kits(p_admin UUID,p_usuario UUID,p_permiso BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_perfil public.profiles%ROWTYPE;
BEGIN
 IF p_permiso IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=p_admin AND activo AND rol='ADMINISTRADOR') THEN
   RAISE EXCEPTION 'Solo Administrador puede asignar permisos.' USING ERRCODE='42501'; END IF;
 SELECT * INTO STRICT v_perfil FROM public.profiles WHERE id=p_usuario FOR UPDATE;
 IF p_permiso AND (v_perfil.rol IS DISTINCT FROM 'ENFERMERIA' OR NOT public.cargo_habilitado_kits(v_perfil.cargo)) THEN
   RAISE EXCEPTION 'El permiso de kits solo se habilita para Técnica o Enfermera con rol Enfermería / Técnico.'; END IF;
 IF p_permiso AND NOT EXISTS(SELECT 1 FROM public.profile_areas WHERE profile_id=p_usuario) THEN
   RAISE EXCEPTION 'Asigna al menos un área antes de permitir gestionar kits.'; END IF;
 IF v_perfil.puede_gestionar_kits IS DISTINCT FROM p_permiso THEN
   UPDATE public.profiles SET puede_gestionar_kits=p_permiso,updated_at=now() WHERE id=p_usuario;
   INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,
      estado_anterior,estado_nuevo,descripcion)
   VALUES('USUARIO_PERMISO_KITS',p_usuario,'profiles',p_admin,
      jsonb_build_object('puede_gestionar_kits',v_perfil.puede_gestionar_kits),
      jsonb_build_object('puede_gestionar_kits',p_permiso),'Asignación administrativa de gestión de kits por área');
 END IF;
END; $$;

-- Reutiliza el contrato vigente de usuarios: mantiene reglas de último administrador y colegiatura.
CREATE OR REPLACE FUNCTION public.administrar_usuario_con_kits(p_accion TEXT,p_id UUID,p_datos JSONB DEFAULT '{}')
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF public.sitra_rol_actual() IS DISTINCT FROM 'ADMINISTRADOR' THEN
   RAISE EXCEPTION 'Solo Administrador puede gestionar usuarios.' USING ERRCODE='42501'; END IF;
 IF p_accion='EDITAR' AND jsonb_typeof(p_datos->'puede_gestionar_kits') IS DISTINCT FROM 'boolean' THEN
   RAISE EXCEPTION 'Indica el permiso de kits como verdadero o falso.'; END IF;
 PERFORM public.administrar_usuario_hu020(p_accion,p_id,p_datos);
 IF p_accion='EDITAR' THEN
   PERFORM public.asignar_permiso_kits(auth.uid(),p_id,(p_datos->>'puede_gestionar_kits')::BOOLEAN);
 END IF;
 RETURN p_id;
END; $$;
-- Conserva el nombre que ya utiliza la Edge Function: no exige volver a desplegarla.
CREATE OR REPLACE FUNCTION public.registrar_perfil_usuario_hu021(p_admin_id UUID,p_id UUID,p_datos JSONB)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_normal JSONB; v_despues JSONB;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=p_admin_id AND activo AND rol='ADMINISTRADOR') THEN
   RAISE EXCEPTION 'Solo Administrador puede crear usuarios.' USING ERRCODE='42501'; END IF;
 IF p_datos ? 'puede_gestionar_kits' AND jsonb_typeof(p_datos->'puede_gestionar_kits') IS DISTINCT FROM 'boolean' THEN
   RAISE EXCEPTION 'Indica el permiso de kits como verdadero o falso.'; END IF;
 PERFORM pg_advisory_xact_lock(12020,2);
 v_normal:=public.hu021_normalizar_perfil(p_datos,p_id);
 BEGIN
   UPDATE public.profiles SET nombres=v_normal->>'nombres',apellidos=v_normal->>'apellidos',
     nombre=v_normal->>'nombre',nombre_usuario=v_normal->>'nombre_usuario',cargo=v_normal->>'cargo',
     rol=v_normal->>'rol',colegio_codigo=v_normal->>'colegio_codigo',
     numero_colegiatura=v_normal->>'numero_colegiatura',especialidad_codigo=v_normal->>'especialidad_codigo',
     areas_asignadas=ARRAY(SELECT jsonb_array_elements_text(v_normal->'areas')),activo=true,updated_at=now()
   WHERE id=p_id AND activo=false;
 EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'Ese nombre de usuario ya está registrado.';
 END;
 IF NOT FOUND THEN RAISE EXCEPTION 'No se encontró el perfil pendiente de la nueva cuenta.'; END IF;
 PERFORM public.asignar_permiso_kits(p_admin_id,p_id,COALESCE((p_datos->>'puede_gestionar_kits')::BOOLEAN,false));
 SELECT to_jsonb(p)-'fcm_token'-'correo_drive' INTO v_despues FROM public.profiles p WHERE p.id=p_id;
 INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,estado_nuevo,descripcion)
 VALUES('USUARIO_CREAR',p_id,'profiles',p_admin_id,v_despues,'Alta de usuario y permiso de kits por área');
 RETURN p_id;
END; $$;

-- Consulta stock usando las reglas vigentes (vencidos y tránsito excluidos de disponible).
-- La consulta no reserva, traslada ni consume unidades.
CREATE OR REPLACE FUNCTION public.medicamentos_para_kits(p_busqueda TEXT DEFAULT '',p_desde INTEGER DEFAULT 0,p_limite INTEGER DEFAULT 100)
RETURNS TABLE(id UUID,nombre TEXT,presentacion TEXT,laboratorio TEXT,activo BOOLEAN,
 farmacia BIGINT,almacen BIGINT,transito BIGINT)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.contexto_kits_por_area();
 RETURN QUERY SELECT s.medicamento_id,s.nombre,s.presentacion,m.laboratorio,s.activo,
 s.farmacia_disponible,s.almacen_disponible,s.en_transito
 FROM public.consultar_stock_ubicaciones(p_busqueda,p_desde,p_limite) s
 JOIN public.medicamentos m ON m.id=s.medicamento_id;
END; $$;

-- Mismo contrato de lectura de HU-017, con permisos por pertenencia UUID.
CREATE OR REPLACE FUNCTION public.listar_kits_hu017(p_area TEXT DEFAULT NULL,p_solo_activos BOOLEAN DEFAULT NULL)
RETURNS TABLE(id UUID,nombre TEXT,descripcion TEXT,area_destino TEXT,area_nombre TEXT,
 area_codigo_interno TEXT,activo BOOLEAN,created_at TIMESTAMPTZ,updated_at TIMESTAMPTZ,total_items BIGINT,items JSONB)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.contexto_kits_por_area();
 RETURN QUERY SELECT k.id,k.nombre,k.descripcion,k.area_destino,COALESCE(a.nombre,k.area_destino),
 COALESCE(a.codigo_interno,k.area_destino),k.activo,k.created_at,k.updated_at,count(ki.id),
 COALESCE(jsonb_agg(jsonb_build_object('id',ki.id,'medicamento_id',ki.medicamento_id,
 'nombre_comercial',m.nombre_comercial,'presentacion',m.presentacion,'laboratorio',m.laboratorio,
 'cantidad',ki.cantidad,'activo',m.activo) ORDER BY m.nombre_comercial,ki.id)
 FILTER(WHERE ki.id IS NOT NULL),'[]')
 FROM public.kits k LEFT JOIN public.areas a ON a.codigo=k.area_destino
 LEFT JOIN public.kit_items ki ON ki.kit_id=k.id LEFT JOIN public.medicamentos m ON m.id=ki.medicamento_id
 WHERE public.puede_consultar_area_kits(k.area_destino)
 AND (p_area IS NULL OR a.codigo=p_area OR a.id::TEXT=p_area)
 AND (p_solo_activos IS NULL OR k.activo=p_solo_activos)
 GROUP BY k.id,a.nombre,a.codigo_interno ORDER BY k.activo DESC,lower(k.nombre),k.id;
END; $$;

-- Operación atómica: cabecera, composición y auditoría. No actualiza copias de fichas previas.
CREATE OR REPLACE FUNCTION public.administrar_kit_hu018(p_accion TEXT,p_id UUID DEFAULT NULL,p_datos JSONB DEFAULT '{}')
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid UUID:=auth.uid(); v_kit public.kits%ROWTYPE; v_area public.areas%ROWTYPE;
 v_origen public.kits%ROWTYPE; v_id UUID:=p_id; v_nombre TEXT; v_items JSONB; v_item JSONB;
 v_med UUID; v_cantidad INTEGER; v_ids UUID[]:='{}'; v_antes JSONB; v_despues JSONB; v_evento TEXT;
BEGIN
 -- Bloquea el perfil frente a una revocación concurrente y rechaza explícitamente NULL/inactivos.
 PERFORM 1 FROM public.profiles WHERE id=v_uid AND activo FOR SHARE;
 IF NOT FOUND OR public.sitra_rol_actual() IS NULL THEN
   RAISE EXCEPTION 'Inicia sesión con un perfil activo.' USING ERRCODE='42501'; END IF;
 IF p_accion IS NULL OR p_accion NOT IN ('GUARDAR','ESTADO','ELIMINAR') OR p_datos IS NULL
 OR jsonb_typeof(p_datos)<>'object' THEN RAISE EXCEPTION 'Operación de kit inválida.'; END IF;
 IF p_id IS NOT NULL THEN
   SELECT * INTO v_kit FROM public.kits WHERE id=p_id FOR UPDATE;
   IF NOT FOUND THEN RAISE EXCEPTION 'El kit ya no existe.'; END IF;
   IF NOT public.puede_gestionar_area_kits(v_kit.area_destino) THEN
     RAISE EXCEPTION 'No tienes permisos para gestionar kits de esta área.' USING ERRCODE='42501'; END IF;
   SELECT to_jsonb(v_kit)||jsonb_build_object('items',COALESCE(jsonb_agg(to_jsonb(ki)),'[]'))
   INTO v_antes FROM public.kit_items ki WHERE ki.kit_id=p_id;
 ELSIF p_accion<>'GUARDAR' THEN RAISE EXCEPTION 'Indica el kit.';
 END IF;
 IF p_accion='ELIMINAR' THEN
   IF EXISTS(SELECT 1 FROM public.dispensaciones WHERE kit_id=p_id) THEN
     RAISE EXCEPTION 'El kit tiene fichas y dispensaciones históricas asociadas. Inhabilítalo para conservarlo.'; END IF;
   DELETE FROM public.kit_items WHERE kit_id=p_id;
   DELETE FROM public.kits WHERE kits.id=p_id;
   v_evento:='KIT_ELIMINADO';
 ELSIF p_accion='ESTADO' THEN
   IF jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Estado inválido.'; END IF;
   SELECT * INTO STRICT v_area FROM public.areas WHERE codigo=v_kit.area_destino FOR SHARE;
   IF (p_datos->>'activo')::BOOLEAN AND NOT v_area.activo THEN RAISE EXCEPTION 'Habilita primero el área del kit.'; END IF;
   UPDATE public.kits SET activo=(p_datos->>'activo')::BOOLEAN,updated_at=now() WHERE kits.id=p_id;
   v_evento:='KIT_ESTADO';
 ELSE
   v_nombre:=regexp_replace(btrim(COALESCE(p_datos->>'nombre','')),'\s+',' ','g');
   IF length(v_nombre) NOT BETWEEN 3 AND 120 THEN RAISE EXCEPTION 'El nombre debe tener de 3 a 120 caracteres.'; END IF;
   IF length(COALESCE(p_datos->>'descripcion',''))>300 THEN RAISE EXCEPTION 'La descripción admite hasta 300 caracteres.'; END IF;
   -- Coincidencia exacta: nunca convertir UUID/alias operativos a mayúsculas.
   SELECT * INTO v_area FROM public.areas WHERE codigo=p_datos->>'area_destino' FOR SHARE;
   IF NOT FOUND THEN RAISE EXCEPTION 'El área indicada no existe.'; END IF;
   IF NOT public.puede_gestionar_area_kits(v_area.codigo) THEN
     RAISE EXCEPTION 'No tienes permisos para gestionar kits de esta área.' USING ERRCODE='42501'; END IF;
   IF NOT v_area.activo AND (p_id IS NULL OR v_kit.area_destino IS DISTINCT FROM v_area.codigo) THEN
     RAISE EXCEPTION 'No se pueden asignar nuevos kits a un área deshabilitada.'; END IF;
   -- Serializa la comprobación de nombre por área sin imponer cambios a datos históricos.
   PERFORM pg_advisory_xact_lock(hashtextextended(v_area.id::TEXT,171819));
   IF EXISTS(SELECT 1 FROM public.kits k WHERE k.area_destino=v_area.codigo
     AND lower(btrim(k.nombre))=lower(v_nombre) AND k.id IS DISTINCT FROM p_id) THEN
     RAISE EXCEPTION 'Ya existe un kit con el nombre indicado en esta área.'; END IF;
   IF p_datos->>'kit_origen_id' IS NOT NULL THEN
     IF p_id IS NOT NULL THEN RAISE EXCEPTION 'Una variante debe crearse como otro kit.'; END IF;
     SELECT * INTO v_origen FROM public.kits WHERE kits.id=(p_datos->>'kit_origen_id')::UUID FOR SHARE;
     IF NOT FOUND OR NOT public.puede_gestionar_area_kits(v_origen.area_destino)
        OR v_origen.area_destino<>v_area.codigo THEN
       RAISE EXCEPTION 'La variante debe pertenecer al área del kit original.' USING ERRCODE='42501'; END IF;
   END IF;
   v_items:=p_datos->'items';
   IF jsonb_typeof(v_items) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Indica la composición del kit.'; END IF;
   IF jsonb_array_length(v_items) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Incluye entre 1 y 500 medicamentos.'; END IF;
   FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) LOOP
     v_med:=(v_item->>'medicamento_id')::UUID;
     IF jsonb_typeof(v_item->'cantidad') IS DISTINCT FROM 'number' OR COALESCE(v_item->>'cantidad','') !~ '^[0-9]+$' THEN
       RAISE EXCEPTION 'La cantidad debe ser un entero positivo.'; END IF;
     v_cantidad:=(v_item->>'cantidad')::INTEGER;
     IF v_cantidad<=0 OR v_med IS NULL OR v_med=ANY(v_ids) THEN RAISE EXCEPTION 'Cantidad inválida o medicamento repetido.'; END IF;
     -- Permite conservar un componente histórico inactivo; no incorporarlo a un kit nuevo.
     IF NOT EXISTS(SELECT 1 FROM public.medicamentos m WHERE m.id=v_med AND (m.activo OR
       EXISTS(SELECT 1 FROM public.kit_items ki WHERE ki.kit_id=p_id AND ki.medicamento_id=v_med AND ki.cantidad=v_cantidad))) THEN
       RAISE EXCEPTION 'Un medicamento está inactivo o ya no existe. Retíralo o conserva su cantidad histórica.'; END IF;
     v_ids:=array_append(v_ids,v_med);
   END LOOP;
   IF p_id IS NULL THEN
     INSERT INTO public.kits(nombre,descripcion,area_destino,activo)
     VALUES(v_nombre,NULLIF(btrim(p_datos->>'descripcion'),''),v_area.codigo,true) RETURNING kits.id INTO v_id;
     v_evento:=CASE WHEN v_origen.id IS NULL THEN 'KIT_CREADO' ELSE 'KIT_DUPLICADO' END;
   ELSE
     UPDATE public.kits SET nombre=v_nombre,descripcion=NULLIF(btrim(p_datos->>'descripcion'),''),
       area_destino=v_area.codigo,updated_at=now() WHERE kits.id=p_id;
     DELETE FROM public.kit_items WHERE kit_id=p_id;
     v_evento:='KIT_ACTUALIZADO';
   END IF;
   INSERT INTO public.kit_items(kit_id,medicamento_id,cantidad)
     SELECT v_id,(x->>'medicamento_id')::UUID,(x->>'cantidad')::INTEGER FROM jsonb_array_elements(v_items) x;
 END IF;
 IF p_accion<>'ELIMINAR' THEN
   SELECT to_jsonb(k)||jsonb_build_object('items',(SELECT COALESCE(jsonb_agg(to_jsonb(ki)),'[]')
     FROM public.kit_items ki WHERE ki.kit_id=v_id)) INTO v_despues FROM public.kits k WHERE k.id=v_id;
 END IF;
 INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,
   estado_anterior,estado_nuevo,descripcion)
 VALUES(v_evento,v_id,'kits',v_uid,v_antes,v_despues||jsonb_build_object('kit_origen_id',v_origen.id),
   'Gestión de plantilla por área; no mueve stock ni modifica fichas anteriores.');
 RETURN v_id;
END; $$;

-- Ningún cliente escribe directamente la cabecera o sus componentes, ni siquiera Administrador.
ALTER TABLE public.kits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kit_items ENABLE ROW LEVEL SECURITY;
REVOKE INSERT,UPDATE,DELETE ON public.kits,public.kit_items FROM authenticated,anon;
DO $$ DECLARE r RECORD; BEGIN
 FOR r IN SELECT tablename,policyname FROM pg_policies WHERE schemaname='public' AND tablename IN ('kits','kit_items') LOOP
   EXECUTE format('DROP POLICY %I ON public.%I',r.policyname,r.tablename);
 END LOOP;
END $$;
CREATE POLICY kits_consulta_area ON public.kits FOR SELECT TO authenticated
 USING(public.puede_consultar_area_kits(area_destino));
CREATE POLICY kit_items_consulta_area ON public.kit_items FOR SELECT TO authenticated
 USING(EXISTS(SELECT 1 FROM public.kits k WHERE k.id=kit_id));

REVOKE ALL ON FUNCTION public.asignar_permiso_kits(UUID,UUID,BOOLEAN),public.proteger_permiso_kits(),
 public.registrar_perfil_usuario_hu021(UUID,UUID,JSONB) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_perfil_usuario_hu021(UUID,UUID,JSONB) TO service_role;
REVOKE ALL ON FUNCTION public.cargo_habilitado_kits(TEXT),public.puede_consultar_area_kits(TEXT),
 public.puede_gestionar_area_kits(TEXT),public.contexto_kits_por_area(),public.listar_permisos_kits(INTEGER,INTEGER),
 public.administrar_usuario_con_kits(TEXT,UUID,JSONB),public.medicamentos_para_kits(TEXT,INTEGER,INTEGER),
 public.listar_kits_hu017(TEXT,BOOLEAN),public.administrar_kit_hu018(TEXT,UUID,JSONB) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.cargo_habilitado_kits(TEXT),public.puede_consultar_area_kits(TEXT),
 public.puede_gestionar_area_kits(TEXT),public.contexto_kits_por_area(),public.listar_permisos_kits(INTEGER,INTEGER),
 public.administrar_usuario_con_kits(TEXT,UUID,JSONB),public.medicamentos_para_kits(TEXT,INTEGER,INTEGER),
 public.listar_kits_hu017(TEXT,BOOLEAN),public.administrar_kit_hu018(TEXT,UUID,JSONB) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
