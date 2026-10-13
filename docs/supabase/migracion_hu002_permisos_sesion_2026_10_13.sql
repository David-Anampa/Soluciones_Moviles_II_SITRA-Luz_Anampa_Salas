-- HU-002: ejecutar después de migracion_recepcion_pedidos_2026_10_12.sql.
-- Sustituye las políticas del sistema; no elimina tablas, usuarios ni registros.
-- Las fichas y kits quedan preparados para sus futuros sprints, sin implementar sus flujos.
BEGIN;

-- Consulta el perfil de la sesión, nunca el rol enviado por el cliente.
-- SECURITY DEFINER evita recursión al consultar profiles desde sus propias políticas.
CREATE OR REPLACE FUNCTION public.sitra_rol_actual()
RETURNS TEXT LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT p.rol FROM public.profiles p WHERE p.id = auth.uid() AND p.activo = true;
$$;

CREATE OR REPLACE FUNCTION public.sitra_tiene_area(p_area TEXT)
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.areas a ON a.codigo = p_area OR lower(btrim(a.nombre)) = lower(btrim(p_area))
    CROSS JOIN LATERAL unnest(p.areas_asignadas) AS asignada(valor)
    WHERE p.id = auth.uid() AND p.activo = true
      AND (upper(btrim(asignada.valor)) = upper(a.codigo)
           OR lower(btrim(asignada.valor)) = lower(btrim(a.nombre)))
  );
$$;
REVOKE ALL ON FUNCTION public.sitra_rol_actual() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sitra_tiene_area(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sitra_rol_actual() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sitra_tiene_area(TEXT) TO authenticated;

-- El usuario únicamente puede sincronizar su propio FCM token. Rol, activo,
-- áreas y datos de perfil se administran por Administrador o servicio autorizado.
CREATE OR REPLACE FUNCTION public.sitra_proteger_perfil()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user IN ('postgres', 'service_role', 'supabase_admin') THEN RETURN NEW; END IF;
  IF public.sitra_rol_actual() = 'ADMINISTRADOR' THEN RETURN NEW; END IF;
  IF OLD.id IS DISTINCT FROM auth.uid() OR public.sitra_rol_actual() IS NULL
     OR (to_jsonb(NEW) - 'fcm_token' - 'updated_at')
        IS DISTINCT FROM (to_jsonb(OLD) - 'fcm_token' - 'updated_at') THEN
    RAISE EXCEPTION 'Solo el administrador puede modificar el perfil, rol, áreas o estado.' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.sitra_proteger_perfil() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS hu002_proteger_perfil ON public.profiles;
CREATE TRIGGER hu002_proteger_perfil BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sitra_proteger_perfil();

-- Registrarse o usar un email que contenga "admin" no concede privilegios.
-- Los nuevos perfiles requieren activación y asignación por Administración.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.profiles(id, email, nombre, rol, areas_asignadas, activo)
  VALUES (NEW.id, NEW.email,
    COALESCE(NULLIF(btrim(NEW.raw_user_meta_data->>'nombre'), ''), split_part(NEW.email, '@', 1)),
    'ENFERMERIA', '{}'::TEXT[], false)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

-- Elimina las políticas anteriores de estas tablas para que ninguna política
-- permisiva residual pueda abrir de nuevo el acceso (las políticas SELECT se suman).
DO $$
DECLARE v_tabla TEXT; v_politica RECORD;
BEGIN
  FOREACH v_tabla IN ARRAY ARRAY[
    'profiles', 'areas', 'doctores', 'medicamentos', 'lotes', 'inventario_stock',
    'pedidos_abastecimiento', 'pedidos_abastecimiento_items', 'pedido_abastecimiento_despachos',
    'kits', 'kit_items', 'dispensaciones', 'dispensacion_items', 'auditoria_trazabilidad'
  ] LOOP
    IF to_regclass(format('public.%I', v_tabla)) IS NULL THEN
      RAISE EXCEPTION 'Falta la tabla %. Ejecuta primero la migración de recepción de pedidos.', v_tabla;
    END IF;
    FOR v_politica IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = v_tabla LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', v_politica.policyname, v_tabla);
    END LOOP;
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', v_tabla);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', v_tabla);
    EXECUTE format('GRANT SELECT ON TABLE public.%I TO authenticated', v_tabla);
  END LOOP;
END;
$$;

GRANT UPDATE ON public.profiles TO authenticated;
GRANT INSERT, UPDATE ON public.areas, public.doctores, public.medicamentos,
  public.lotes, public.inventario_stock, public.kits, public.kit_items TO authenticated;
GRANT INSERT ON public.pedidos_abastecimiento, public.pedidos_abastecimiento_items,
  public.dispensaciones, public.dispensacion_items, public.auditoria_trazabilidad TO authenticated;
-- No se concede DELETE. Los pedidos emitidos y sus despachos solo cambian vía RPC.

CREATE POLICY hu002_perfiles_lectura ON public.profiles FOR SELECT TO authenticated USING (
  id = auth.uid() OR public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
  OR (public.sitra_rol_actual() = 'ENFERMERIA' AND rol = 'ENFERMERIA'
      AND EXISTS (SELECT 1 FROM unnest(areas_asignadas) AS area(valor) WHERE public.sitra_tiene_area(area.valor)))
);
CREATE POLICY hu002_perfiles_actualizacion ON public.profiles FOR UPDATE TO authenticated
  USING (public.sitra_rol_actual() = 'ADMINISTRADOR' OR (id = auth.uid() AND public.sitra_rol_actual() IS NOT NULL))
  WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR' OR (id = auth.uid() AND public.sitra_rol_actual() IS NOT NULL));

CREATE POLICY hu002_areas_lectura ON public.areas FOR SELECT TO authenticated USING (public.sitra_rol_actual() IS NOT NULL);
CREATE POLICY hu002_areas_creacion ON public.areas FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_areas_actualizacion ON public.areas FOR UPDATE TO authenticated USING (public.sitra_rol_actual() = 'ADMINISTRADOR') WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_doctores_lectura ON public.doctores FOR SELECT TO authenticated USING (public.sitra_rol_actual() IS NOT NULL);
CREATE POLICY hu002_doctores_creacion ON public.doctores FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_doctores_actualizacion ON public.doctores FOR UPDATE TO authenticated USING (public.sitra_rol_actual() = 'ADMINISTRADOR') WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');

CREATE POLICY hu002_medicamentos_lectura ON public.medicamentos FOR SELECT TO authenticated USING (public.sitra_rol_actual() IS NOT NULL);
CREATE POLICY hu002_medicamentos_creacion ON public.medicamentos FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN'));
CREATE POLICY hu002_medicamentos_actualizacion ON public.medicamentos FOR UPDATE TO authenticated USING (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN')) WITH CHECK (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN'));
CREATE POLICY hu002_lotes_lectura ON public.lotes FOR SELECT TO authenticated USING (public.sitra_rol_actual() IS NOT NULL);
CREATE POLICY hu002_lotes_creacion ON public.lotes FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN'));
CREATE POLICY hu002_lotes_actualizacion ON public.lotes FOR UPDATE TO authenticated USING (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN')) WITH CHECK (public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ALMACEN'));

CREATE POLICY hu002_inventario_lectura ON public.inventario_stock FOR SELECT TO authenticated USING (
  public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'ALMACEN', 'FARMACIA')
  OR (public.sitra_rol_actual() = 'ENFERMERIA'
      AND (area_codigo IN ('FARMACIA', 'ALMACEN') OR public.sitra_tiene_area(area_codigo)))
);
CREATE POLICY hu002_inventario_creacion ON public.inventario_stock FOR INSERT TO authenticated WITH CHECK (
  public.sitra_rol_actual() = 'ADMINISTRADOR'
  OR (public.sitra_rol_actual() = 'ALMACEN' AND area_codigo IN ('ALMACEN', 'FARMACIA'))
);
CREATE POLICY hu002_inventario_actualizacion ON public.inventario_stock FOR UPDATE TO authenticated USING (
  public.sitra_rol_actual() = 'ADMINISTRADOR'
  OR (public.sitra_rol_actual() = 'ALMACEN' AND area_codigo IN ('ALMACEN', 'FARMACIA'))
) WITH CHECK (
  public.sitra_rol_actual() = 'ADMINISTRADOR'
  OR (public.sitra_rol_actual() = 'ALMACEN' AND area_codigo IN ('ALMACEN', 'FARMACIA'))
);

CREATE POLICY hu002_pedidos_lectura ON public.pedidos_abastecimiento FOR SELECT TO authenticated USING (
  public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
);
CREATE POLICY hu002_pedidos_creacion ON public.pedidos_abastecimiento FOR INSERT TO authenticated WITH CHECK (
  public.sitra_rol_actual() IN ('FARMACIA', 'ADMINISTRADOR') AND solicitante_id = auth.uid()
  AND area_origen = 'FARMACIA' AND area_destino = 'ALMACEN' AND estado = 'PENDIENTE'
  AND NOT confirmado_almacen AND NOT confirmado_farmacia
  AND responsable_almacen_id IS NULL AND responsable_farmacia_id IS NULL
  AND cancelado_por IS NULL AND rechazado_por IS NULL
);
CREATE POLICY hu002_pedido_items_lectura ON public.pedidos_abastecimiento_items FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.pedidos_abastecimiento p WHERE p.id = pedido_id)
);
CREATE POLICY hu002_pedido_items_creacion ON public.pedidos_abastecimiento_items FOR INSERT TO authenticated WITH CHECK (
  public.sitra_rol_actual() IN ('FARMACIA', 'ADMINISTRADOR') AND cantidad_despachada = 0
  AND cantidad_recibida IS NULL AND lote_id IS NULL
  AND EXISTS (SELECT 1 FROM public.pedidos_abastecimiento p WHERE p.id = pedido_id
              AND p.solicitante_id = auth.uid() AND p.estado = 'PENDIENTE')
);
CREATE POLICY hu002_despachos_lectura ON public.pedido_abastecimiento_despachos FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.id = item_id)
);

CREATE POLICY hu002_kits_lectura ON public.kits FOR SELECT TO authenticated USING (
  public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA', 'ALMACEN')
  OR (public.sitra_rol_actual() = 'ENFERMERIA' AND public.sitra_tiene_area(area_destino))
);
CREATE POLICY hu002_kits_creacion ON public.kits FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_kits_actualizacion ON public.kits FOR UPDATE TO authenticated USING (public.sitra_rol_actual() = 'ADMINISTRADOR') WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_kit_items_lectura ON public.kit_items FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.kits k WHERE k.id = kit_id));
CREATE POLICY hu002_kit_items_creacion ON public.kit_items FOR INSERT TO authenticated WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');
CREATE POLICY hu002_kit_items_actualizacion ON public.kit_items FOR UPDATE TO authenticated USING (public.sitra_rol_actual() = 'ADMINISTRADOR') WITH CHECK (public.sitra_rol_actual() = 'ADMINISTRADOR');

CREATE POLICY hu002_fichas_lectura ON public.dispensaciones FOR SELECT TO authenticated USING (
  public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA')
  OR (public.sitra_rol_actual() = 'ENFERMERIA' AND public.sitra_tiene_area(area_origen))
);
CREATE POLICY hu002_fichas_creacion ON public.dispensaciones FOR INSERT TO authenticated WITH CHECK (
  solicitado_por = auth.uid() AND estado = 'SOLICITADO' AND entregado_por IS NULL AND fecha_entrega IS NULL
  AND (public.sitra_rol_actual() = 'ADMINISTRADOR'
       OR (public.sitra_rol_actual() = 'ENFERMERIA' AND public.sitra_tiene_area(area_origen)))
);
CREATE POLICY hu002_ficha_items_lectura ON public.dispensacion_items FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.dispensaciones d WHERE d.id = dispensacion_id));
CREATE POLICY hu002_ficha_items_creacion ON public.dispensacion_items FOR INSERT TO authenticated WITH CHECK (
  cantidad_entregada = 0 AND public.sitra_rol_actual() IN ('ADMINISTRADOR', 'ENFERMERIA')
  AND EXISTS (SELECT 1 FROM public.dispensaciones d WHERE d.id = dispensacion_id
              AND d.solicitado_por = auth.uid() AND d.estado = 'SOLICITADO')
);
-- La preparación, entrega y anulación de fichas se incorporarán con RPC en sus HU.

CREATE POLICY hu002_auditoria_lectura ON public.auditoria_trazabilidad FOR SELECT TO authenticated USING (
  public.sitra_rol_actual() IN ('ADMINISTRADOR', 'JEFATURA_FARMACIA', 'FARMACIA')
  OR (public.sitra_rol_actual() = 'ALMACEN' AND (
    usuario_id = auth.uid() OR area_origen = 'ALMACEN' OR area_destino = 'ALMACEN'
    OR (tabla_referencia = 'pedidos_abastecimiento' AND EXISTS (
      SELECT 1 FROM public.pedidos_abastecimiento p WHERE p.id = entidad_referencia_id))
  ))
  OR (public.sitra_rol_actual() = 'ENFERMERIA' AND (
    usuario_id = auth.uid() OR public.sitra_tiene_area(area_origen) OR public.sitra_tiene_area(area_destino)
  ))
);
CREATE POLICY hu002_auditoria_creacion ON public.auditoria_trazabilidad FOR INSERT TO authenticated WITH CHECK (
  usuario_id = auth.uid() AND public.sitra_rol_actual() IN ('ADMINISTRADOR', 'FARMACIA', 'ALMACEN')
);
-- Ningún rol de la aplicación recibe UPDATE/DELETE sobre auditoría.

-- Extiende únicamente el control de rol de la RPC existente: Administración
-- puede operar los módulos, pero conserva las mismas reglas de estado y stock.
DO $$
DECLARE v_funcion TEXT;
  v_anterior TEXT := $viejo$IF p_accion IN ('CANCELAR', 'RECIBIR') AND v_rol <> 'FARMACIA'
     OR p_accion IN ('TOMAR', 'RECHAZAR', 'DESPACHAR') AND v_rol <> 'ALMACEN' THEN$viejo$;
  v_nuevo TEXT := $nuevo$IF v_rol <> 'ADMINISTRADOR' AND (
     p_accion IN ('CANCELAR', 'RECIBIR') AND v_rol <> 'FARMACIA'
     OR p_accion IN ('TOMAR', 'RECHAZAR', 'DESPACHAR') AND v_rol <> 'ALMACEN') THEN$nuevo$;
BEGIN
  SELECT pg_get_functiondef(to_regprocedure('public.procesar_pedido_abastecimiento(uuid,text,text,jsonb,text,text)')) INTO v_funcion;
  IF v_funcion IS NULL THEN RAISE EXCEPTION 'Falta la función de pedidos. Ejecuta primero la migración de recepción.'; END IF;
  IF position(v_anterior IN v_funcion) > 0 THEN
    EXECUTE replace(v_funcion, v_anterior, v_nuevo);
  ELSIF position(v_nuevo IN v_funcion) = 0 THEN
    RAISE EXCEPTION 'La función de pedidos tiene otra versión. Revísala antes de aplicar HU-002.';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
