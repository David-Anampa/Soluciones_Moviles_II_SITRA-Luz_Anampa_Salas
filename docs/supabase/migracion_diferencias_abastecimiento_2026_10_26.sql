-- Requiere stock en tránsito 25/10/2026. No modifica existencias históricas.
BEGIN;
CREATE TABLE IF NOT EXISTS public.diferencias_abastecimiento(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 pedido_id UUID NOT NULL REFERENCES public.pedidos_abastecimiento(id),
 reportado_por UUID NOT NULL REFERENCES public.profiles(id),
 estado TEXT NOT NULL CHECK(estado IN ('PENDIENTE','PROPUESTA','RESUELTO','CANCELADO','RECHAZADO')),
 conteo JSONB NOT NULL, motivo TEXT NOT NULL CHECK(length(btrim(motivo)) BETWEEN 1 AND 1000),
 propuesta JSONB, destino TEXT CHECK(destino IN ('ALMACEN','PERDIDA','ENTREGA')),
 justificacion TEXT, version INTEGER NOT NULL DEFAULT 1,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS diferencia_activa_pedido ON public.diferencias_abastecimiento(pedido_id)
 WHERE estado IN ('PENDIENTE','PROPUESTA');
CREATE TABLE IF NOT EXISTS public.diferencias_abastecimiento_historial(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 reporte_id UUID NOT NULL REFERENCES public.diferencias_abastecimiento(id),
 usuario_id UUID NOT NULL REFERENCES public.profiles(id),
 operacion_id UUID NOT NULL, accion TEXT NOT NULL, motivo TEXT NOT NULL,
 datos JSONB NOT NULL, resultado JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(usuario_id,operacion_id)
);
ALTER TABLE public.diferencias_abastecimiento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diferencias_abastecimiento_historial ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.diferencias_abastecimiento,public.diferencias_abastecimiento_historial FROM PUBLIC,anon,authenticated;

ALTER TABLE public.pedido_abastecimiento_despachos ADD COLUMN IF NOT EXISTS cantidad_perdida INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.pedido_abastecimiento_despachos DROP CONSTRAINT IF EXISTS despacho_conteo_check;
ALTER TABLE public.pedido_abastecimiento_despachos ADD CONSTRAINT despacho_conteo_check
 CHECK(cantidad_recibida>=0 AND cantidad_devuelta>=0 AND cantidad_perdida>=0
 AND cantidad_recibida+cantidad_devuelta+cantidad_perdida<=cantidad);

-- La ruta antigua queda privada y se protege la recepción con reportes abiertos.
DO $$ BEGIN
 IF to_regprocedure('public.procesar_abastecimiento_sin_reporte(uuid,text,text,jsonb,text,text)') IS NULL THEN
  ALTER FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT)
   RENAME TO procesar_abastecimiento_sin_reporte;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.procesar_abastecimiento_sin_reporte(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.procesar_pedido_abastecimiento(
 p_pedido_id UUID,p_accion TEXT,p_motivo TEXT DEFAULT NULL,p_cantidades JSONB DEFAULT '{}',
 p_modalidad TEXT DEFAULT NULL,p_notas TEXT DEFAULT NULL) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM 1 FROM public.pedidos_abastecimiento WHERE id=p_pedido_id FOR UPDATE;
 IF p_accion='RECIBIR' AND EXISTS(SELECT 1 FROM public.diferencias_abastecimiento
  WHERE pedido_id=p_pedido_id AND estado IN ('PENDIENTE','PROPUESTA')) THEN
  RAISE EXCEPTION 'Hay un reporte pendiente. Revise Diferencias e historial antes de recibir.';
 END IF;
 PERFORM public.procesar_abastecimiento_sin_reporte(p_pedido_id,p_accion,p_motivo,p_cantidades,p_modalidad,p_notas);
END $$;
REVOKE ALL ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.huella_stock_diferencia(p_pedido UUID) RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT md5(COALESCE(string_agg(to_jsonb(s)::text,'|' ORDER BY s.lote_id,s.area_codigo),''))
 FROM public.inventario_stock s WHERE s.area_codigo IN ('ALMACEN','FARMACIA')
 AND s.lote_id IN(SELECT l.id FROM public.lotes l JOIN public.pedidos_abastecimiento_items i
 ON i.medicamento_id=l.medicamento_id WHERE i.pedido_id=p_pedido)
$$;
REVOKE ALL ON FUNCTION public.huella_stock_diferencia(UUID) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.gestionar_diferencia_abastecimiento(
 p_pedido_id UUID,p_accion TEXT,p_motivo TEXT,p_cantidades JSONB DEFAULT '{}',
 p_destino TEXT DEFAULT NULL,p_version INTEGER DEFAULT 0,p_operacion_id UUID DEFAULT NULL,
 p_saldo_version TEXT DEFAULT NULL) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 v_actor UUID:=auth.uid(); v_rol TEXT; v_p public.pedidos_abastecimiento%ROWTYPE;
 v_r public.diferencias_abastecimiento%ROWTYPE; v_h RECORD; v_i RECORD; v_d RECORD;
 v_datos JSONB; v_resultado JSONB; v_antes JSONB; v_conteo JSONB; v_destino TEXT;
 v_n INTEGER; v_restante INTEGER; v_aceptado INTEGER; v_diferencia INTEGER; v_evento TEXT;
BEGIN
 SELECT rol INTO v_rol FROM public.profiles WHERE id=v_actor AND activo;
 IF v_actor IS NULL OR v_rol IS NULL OR v_rol NOT IN ('FARMACIA','ALMACEN','ADMINISTRADOR') THEN
  RAISE EXCEPTION 'Su usuario no puede gestionar diferencias.'; END IF;
 IF p_operacion_id IS NULL THEN RAISE EXCEPTION 'Falta la clave de la operación.'; END IF;
 IF p_accion IS NULL OR p_accion NOT IN ('REPORTAR','CANCELAR','RECHAZAR','RESOLVER','CONFIRMAR','DEVOLVER_PROPUESTA') THEN
  RAISE EXCEPTION 'Acción no válida.'; END IF;
 IF p_motivo IS NULL OR length(btrim(p_motivo)) NOT BETWEEN 1 AND 1000 THEN
  RAISE EXCEPTION 'Escriba una justificación de hasta 1000 caracteres.'; END IF;
 v_datos:=jsonb_build_object('pedido',p_pedido_id,'accion',p_accion,'motivo',btrim(p_motivo),
  'cantidades',p_cantidades,'destino',p_destino,'version',p_version,'saldo_version',p_saldo_version);
 PERFORM pg_advisory_xact_lock(hashtextextended(v_actor::text||p_operacion_id::text,0));
 SELECT * INTO v_h FROM public.diferencias_abastecimiento_historial WHERE usuario_id=v_actor AND operacion_id=p_operacion_id;
 IF FOUND THEN
  IF v_h.datos<>v_datos THEN RAISE EXCEPTION 'La clave ya corresponde a otra operación.'; END IF;
  RETURN v_h.resultado;
 END IF;
 SELECT * INTO v_p FROM public.pedidos_abastecimiento WHERE id=p_pedido_id FOR UPDATE;
 IF NOT FOUND OR v_p.estado<>'LISTO' OR NOT v_p.despacho_en_transito THEN
  RAISE EXCEPTION 'El pedido debe estar en tránsito y pendiente de recepción.'; END IF;
 SELECT * INTO v_r FROM public.diferencias_abastecimiento WHERE pedido_id=p_pedido_id
 AND estado IN ('PENDIENTE','PROPUESTA') FOR UPDATE;
 IF p_accion='REPORTAR' THEN
  IF v_rol NOT IN ('FARMACIA','ADMINISTRADOR') THEN RAISE EXCEPTION 'Solo Farmacia reporta su conteo.'; END IF;
  IF v_r.id IS NOT NULL THEN RAISE EXCEPTION 'Ya existe un reporte abierto.'; END IF;
  v_conteo:=p_cantidades;
 ELSE
  IF v_r.id IS NULL OR v_r.version<>p_version THEN RAISE EXCEPTION 'El reporte cambió. Actualice antes de continuar.'; END IF;
  IF p_accion IN ('CANCELAR','CONFIRMAR','DEVOLVER_PROPUESTA') AND v_rol<>'ADMINISTRADOR'
   AND (v_rol<>'FARMACIA' OR v_r.reportado_por<>v_actor) THEN
   RAISE EXCEPTION 'Solo quien reportó en Farmacia puede realizar esta acción.'; END IF;
  IF p_accion IN ('RESOLVER','RECHAZAR') AND v_rol NOT IN ('ALMACEN','ADMINISTRADOR') THEN
   RAISE EXCEPTION 'Solo Almacén revisa y soluciona.'; END IF;
  v_conteo:=CASE WHEN p_accion='RESOLVER' THEN p_cantidades ELSE v_r.propuesta END;
 END IF;
 IF p_accion IN ('REPORTAR','RESOLVER') THEN
  IF v_conteo IS NULL OR jsonb_typeof(v_conteo)<>'object' THEN RAISE EXCEPTION 'Conteo no válido.'; END IF;
  IF (SELECT count(*) FROM jsonb_object_keys(v_conteo))<>(SELECT count(*) FROM public.pedidos_abastecimiento_items WHERE pedido_id=p_pedido_id)
   OR EXISTS(SELECT 1 FROM jsonb_each(v_conteo) x WHERE jsonb_typeof(x.value)<>'number' OR x.value::text !~ '^[0-9]+$'
    OR x.value::numeric>2147483647 OR NOT EXISTS(SELECT 1 FROM public.pedidos_abastecimiento_items i
     WHERE i.pedido_id=p_pedido_id AND i.id::text=x.key AND x.value::numeric<=i.cantidad_despachada)) THEN
   RAISE EXCEPTION 'Revise cada cantidad: debe estar entre cero y lo despachado.'; END IF;
 END IF;
 v_antes:=to_jsonb(v_r);
 IF p_accion='REPORTAR' THEN
  IF NOT EXISTS(SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=p_pedido_id
   AND (v_conteo->>i.id::text)::integer<i.cantidad_despachada) THEN RAISE EXCEPTION 'El conteo es conforme: utilice recepción conforme.'; END IF;
  INSERT INTO public.diferencias_abastecimiento(pedido_id,reportado_por,estado,conteo,motivo)
   VALUES(p_pedido_id,v_actor,'PENDIENTE',v_conteo,btrim(p_motivo)) RETURNING * INTO v_r;
 ELSIF p_accion IN ('CANCELAR','RECHAZAR') THEN
  UPDATE public.diferencias_abastecimiento SET estado=CASE WHEN p_accion='CANCELAR' THEN 'CANCELADO' ELSE 'RECHAZADO' END,
   version=version+1,updated_at=now() WHERE id=v_r.id RETURNING * INTO v_r;
 ELSIF p_accion='DEVOLVER_PROPUESTA' THEN
  IF v_r.estado<>'PROPUESTA' THEN RAISE EXCEPTION 'No hay propuesta que revisar.'; END IF;
  UPDATE public.diferencias_abastecimiento SET estado='PENDIENTE',propuesta=NULL,destino=NULL,justificacion=NULL,
   version=version+1,updated_at=now() WHERE id=v_r.id RETURNING * INTO v_r;
 ELSE
  IF p_accion='RESOLVER' THEN
   IF v_r.estado<>'PENDIENTE' THEN RAISE EXCEPTION 'Farmacia debe responder primero a la propuesta vigente.'; END IF;
   IF p_destino IS NULL OR p_destino NOT IN ('ALMACEN','PERDIDA','ENTREGA') THEN RAISE EXCEPTION 'Seleccione una solución.'; END IF;
   IF p_destino='ENTREGA' AND EXISTS(SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=p_pedido_id
    AND (v_conteo->>i.id::text)::integer<>i.cantidad_despachada) THEN RAISE EXCEPTION 'La entrega pendiente requiere confirmar el total despachado.'; END IF;
   UPDATE public.diferencias_abastecimiento SET propuesta=v_conteo,destino=p_destino,justificacion=btrim(p_motivo),
    version=version+1,updated_at=now() WHERE id=v_r.id RETURNING * INTO v_r;
   IF v_conteo<>v_r.conteo THEN
    UPDATE public.diferencias_abastecimiento SET estado='PROPUESTA' WHERE id=v_r.id RETURNING * INTO v_r;
   END IF;
  ELSE
   IF v_r.estado<>'PROPUESTA' THEN RAISE EXCEPTION 'No hay propuesta pendiente de confirmación.'; END IF;
   v_conteo:=v_r.propuesta;
  END IF;
  IF v_r.estado<>'PROPUESTA' OR p_accion='CONFIRMAR' THEN
   -- La vista previa se invalida si otra operación alteró estos lotes.
   LOCK TABLE public.inventario_stock IN SHARE ROW EXCLUSIVE MODE;
   PERFORM 1 FROM public.inventario_stock s WHERE s.lote_id IN(
    SELECT d.lote_id FROM public.pedido_abastecimiento_despachos d JOIN public.pedidos_abastecimiento_items i ON i.id=d.item_id
    WHERE i.pedido_id=p_pedido_id) ORDER BY s.lote_id,s.area_codigo FOR UPDATE;
   IF p_saldo_version IS NULL OR p_saldo_version<>public.huella_stock_diferencia(p_pedido_id) THEN
    RAISE EXCEPTION 'El stock cambió desde la vista previa. Actualice y revise nuevamente.'; END IF;
   v_destino:=v_r.destino;
   FOR v_i IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id=p_pedido_id ORDER BY id LOOP
    v_n:=(v_conteo->>v_i.id::text)::integer; v_restante:=v_n;
    IF (SELECT COALESCE(sum(cantidad),0) FROM public.pedido_abastecimiento_despachos WHERE item_id=v_i.id)<>v_i.cantidad_despachada THEN
     RAISE EXCEPTION 'Los lotes no coinciden con el despacho; requiere revisión técnica.'; END IF;
    FOR v_d IN SELECT d.* FROM public.pedido_abastecimiento_despachos d JOIN public.lotes l ON l.id=d.lote_id
     WHERE d.item_id=v_i.id ORDER BY l.fecha_vencimiento,l.id FOR UPDATE OF d LOOP
     IF v_d.cantidad_recibida+v_d.cantidad_devuelta+v_d.cantidad_perdida<>0 THEN RAISE EXCEPTION 'El lote ya fue conciliado.'; END IF;
     v_aceptado:=LEAST(v_restante,v_d.cantidad); v_diferencia:=v_d.cantidad-v_aceptado;
     IF v_aceptado>0 THEN
      INSERT INTO public.inventario_stock(lote_id,area_codigo,cantidad) VALUES(v_d.lote_id,'FARMACIA',v_aceptado)
       ON CONFLICT(lote_id,area_codigo) DO UPDATE SET cantidad=public.inventario_stock.cantidad+EXCLUDED.cantidad,updated_at=now();
     END IF;
     IF v_diferencia>0 AND v_destino='ALMACEN' THEN
      INSERT INTO public.inventario_stock(lote_id,area_codigo,cantidad) VALUES(v_d.lote_id,'ALMACEN',v_diferencia)
       ON CONFLICT(lote_id,area_codigo) DO UPDATE SET cantidad=public.inventario_stock.cantidad+EXCLUDED.cantidad,updated_at=now();
     END IF;
     UPDATE public.pedido_abastecimiento_despachos SET cantidad_recibida=v_aceptado,
      cantidad_devuelta=CASE WHEN v_destino='ALMACEN' THEN v_diferencia ELSE 0 END,
      cantidad_perdida=CASE WHEN v_destino='PERDIDA' THEN v_diferencia ELSE 0 END WHERE id=v_d.id;
     INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,
      medicamento_id,lote_id,cantidad,descripcion,detalles_extra)
      VALUES('CONCILIACION_LOTE',v_r.id,'diferencias_abastecimiento',v_actor,v_i.medicamento_id,v_d.lote_id,v_d.cantidad,
       btrim(p_motivo),jsonb_build_object('pedido_id',p_pedido_id,'recibido_farmacia',v_aceptado,
       'reintegrado_almacen',CASE WHEN v_destino='ALMACEN' THEN v_diferencia ELSE 0 END,
       'perdida',CASE WHEN v_destino='PERDIDA' THEN v_diferencia ELSE 0 END,'justificacion_almacen',v_r.justificacion));
     v_restante:=v_restante-v_aceptado;
    END LOOP;
    UPDATE public.pedidos_abastecimiento_items SET cantidad_recibida=v_n WHERE id=v_i.id;
   END LOOP;
   UPDATE public.pedidos_abastecimiento SET estado='COMPLETADO',confirmado_farmacia=true,
    responsable_farmacia_id=CASE WHEN p_accion='CONFIRMAR' THEN v_actor ELSE v_r.reportado_por END,
    fecha_confirmacion_farmacia=now(),fecha_recepcion=now(),fecha_completado=now(),
    observacion_recepcion='Conciliado mediante reporte '||v_r.id WHERE id=p_pedido_id;
   UPDATE public.diferencias_abastecimiento SET estado='RESUELTO',version=version+1,updated_at=now() WHERE id=v_r.id RETURNING * INTO v_r;
  END IF;
 END IF;
 v_resultado:=to_jsonb(v_r);
 INSERT INTO public.diferencias_abastecimiento_historial(reporte_id,usuario_id,operacion_id,accion,motivo,datos,resultado)
 VALUES(v_r.id,v_actor,p_operacion_id,p_accion,btrim(p_motivo),v_datos,v_resultado);
 v_evento:='DIFERENCIA_'||p_accion;
 INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,
 estado_anterior,estado_nuevo,descripcion,detalles_extra) VALUES(v_evento,v_r.id,'diferencias_abastecimiento',v_actor,
 v_antes,v_resultado,btrim(p_motivo),v_datos);
 RETURN v_resultado;
END $$;
REVOKE ALL ON FUNCTION public.gestionar_diferencia_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,INTEGER,UUID,TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gestionar_diferencia_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,INTEGER,UUID,TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.consultar_diferencias_abastecimiento() RETURNS SETOF JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_rol TEXT; BEGIN
 SELECT rol INTO v_rol FROM public.profiles WHERE id=auth.uid() AND activo;
 IF v_rol IS NULL OR v_rol NOT IN ('FARMACIA','ALMACEN','JEFATURA_FARMACIA','ADMINISTRADOR') THEN
 RAISE EXCEPTION 'Su usuario no puede consultar reportes.'; END IF;
 RETURN QUERY SELECT to_jsonb(r)||jsonb_build_object('codigo',p.codigo,'reportante',u.nombre,
 'saldo_version',public.huella_stock_diferencia(p.id),
 'items',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',i.id,'nombre',m.nombre_comercial,
 'despachado',i.cantidad_despachada,'contado',(r.conteo->>i.id::text)::integer,
 'almacen',COALESCE((SELECT sum(s.cantidad) FROM public.inventario_stock s JOIN public.lotes l ON l.id=s.lote_id
 WHERE l.medicamento_id=i.medicamento_id AND s.area_codigo='ALMACEN'),0),
 'farmacia',COALESCE((SELECT sum(s.cantidad) FROM public.inventario_stock s JOIN public.lotes l ON l.id=s.lote_id
 WHERE l.medicamento_id=i.medicamento_id AND s.area_codigo='FARMACIA'),0)) ORDER BY i.id)
 FROM public.pedidos_abastecimiento_items i JOIN public.medicamentos m ON m.id=i.medicamento_id WHERE i.pedido_id=p.id),'[]'),
 'historial',COALESCE((SELECT jsonb_agg(jsonb_build_object('accion',h.accion,'motivo',h.motivo,'fecha',h.created_at,
 'usuario',pr.nombre,'datos',h.datos,'resultado',h.resultado) ORDER BY h.created_at,h.id)
 FROM public.diferencias_abastecimiento_historial h JOIN public.profiles pr ON pr.id=h.usuario_id WHERE h.reporte_id=r.id),'[]'))
 FROM public.diferencias_abastecimiento r JOIN public.pedidos_abastecimiento p ON p.id=r.pedido_id
 JOIN public.profiles u ON u.id=r.reportado_por
 WHERE v_rol<>'FARMACIA' OR r.reportado_por=auth.uid() ORDER BY r.updated_at DESC;
END $$;
REVOKE ALL ON FUNCTION public.consultar_diferencias_abastecimiento() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.consultar_diferencias_abastecimiento() TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
