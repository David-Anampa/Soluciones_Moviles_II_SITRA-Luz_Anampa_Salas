-- HU-024: ingreso completo o rollback; correcciones sin reescribir el original.
BEGIN;
CREATE TABLE IF NOT EXISTS public.ingresos_lote(
 lote_id UUID PRIMARY KEY REFERENCES public.lotes(id),
 cantidad_original INTEGER NOT NULL CHECK(cantidad_original>0),
 cantidad_registrada INTEGER NOT NULL CHECK(cantidad_registrada>=0),
 datos_originales JSONB NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.operaciones_ingreso_lote(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 usuario_id UUID NOT NULL REFERENCES public.profiles(id),operacion_id UUID NOT NULL,
 lote_id UUID NOT NULL REFERENCES public.lotes(id),accion TEXT NOT NULL,
 datos JSONB NOT NULL,resultado JSONB NOT NULL,created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(usuario_id,operacion_id)
);
ALTER TABLE public.ingresos_lote ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operaciones_ingreso_lote ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ingresos_lote,public.operaciones_ingreso_lote FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.registrar_ingreso_lote_hu024(
 p_operacion_id UUID,p_datos JSONB,p_medicamento JSONB DEFAULT NULL) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_actor UUID:=auth.uid();v_rol TEXT;v_med UUID;v_lote public.lotes%ROWTYPE;
 v_op RECORD;v_cantidad INTEGER;v_datos JSONB;v_numero TEXT;v_frio BOOLEAN;
BEGIN
 SELECT rol INTO v_rol FROM public.profiles WHERE id=v_actor AND activo;
 IF v_actor IS NULL OR v_rol IS NULL OR v_rol NOT IN ('ALMACEN','ADMINISTRADOR') THEN
  RAISE EXCEPTION 'Solo Almacén puede registrar ingresos.'; END IF;
 IF p_operacion_id IS NULL OR p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' THEN RAISE EXCEPTION 'Ingreso no válido.'; END IF;
 v_datos:=jsonb_build_object('ingreso',p_datos,'medicamento',p_medicamento);
 PERFORM pg_advisory_xact_lock(hashtextextended(v_actor::text||p_operacion_id::text,0));
 SELECT * INTO v_op FROM public.operaciones_ingreso_lote WHERE usuario_id=v_actor AND operacion_id=p_operacion_id;
 IF FOUND THEN
  IF v_op.datos<>v_datos OR v_op.accion<>'INGRESO' THEN RAISE EXCEPTION 'La clave de envío corresponde a otro contenido.'; END IF;
  RETURN v_op.resultado;
 END IF;
 IF COALESCE(p_datos->>'cantidad','') !~ '^[0-9]+$' OR (p_datos->>'cantidad')::numeric NOT BETWEEN 1 AND 2147483647 THEN
  RAISE EXCEPTION 'La cantidad debe ser un entero positivo.'; END IF;
 v_cantidad:=(p_datos->>'cantidad')::integer;v_numero:=upper(btrim(p_datos->>'numero_lote'));
 IF v_numero IS NULL OR length(v_numero) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Ingrese un número de lote válido.'; END IF;
 IF p_datos->>'fecha_vencimiento' IS NULL OR (p_datos->>'fecha_vencimiento')::date<=CURRENT_DATE THEN
  RAISE EXCEPTION 'El vencimiento debe ser posterior a hoy.'; END IF;
 IF NULLIF(p_datos->>'fecha_fabricacion','')::date>(p_datos->>'fecha_vencimiento')::date THEN RAISE EXCEPTION 'Fabricación posterior al vencimiento.'; END IF;
 IF p_datos->>'justificacion' IS NULL OR p_datos->>'justificacion' NOT IN ('Compra','Donacion') THEN RAISE EXCEPTION 'Seleccione Compra o Donación.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_each(p_datos) e WHERE e.key IN ('precio_compra','precio_venta') AND e.value<>'null'
  AND (jsonb_typeof(e.value)<>'number' OR e.value::numeric<0 OR e.value::numeric>99999999.99)) THEN
  RAISE EXCEPTION 'El precio debe ser un número entre cero y 99999999.99.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.areas WHERE codigo='ALMACEN' AND activo) THEN RAISE EXCEPTION 'Almacén no está habilitado.'; END IF;
 IF p_medicamento IS NOT NULL THEN
  IF jsonb_typeof(p_medicamento)<>'object' OR NULLIF(btrim(p_medicamento->>'gtin'),'') IS NULL
   OR NULLIF(btrim(p_medicamento->>'nombre_comercial'),'') IS NULL OR NULLIF(btrim(p_medicamento->>'principio_activo'),'') IS NULL
   OR NULLIF(btrim(p_medicamento->>'presentacion'),'') IS NULL THEN RAISE EXCEPTION 'Complete los datos del medicamento nuevo.'; END IF;
  IF COALESCE((p_medicamento->>'cantidad_por_presentacion')::integer,1)<=0
   OR COALESCE((p_medicamento->>'precio_kairos')::numeric,0)<0
   OR COALESCE((p_medicamento->>'temperatura_min')::numeric,2)>COALESCE((p_medicamento->>'temperatura_max')::numeric,8) THEN
   RAISE EXCEPTION 'Revise presentación, precio y rango de temperatura del medicamento.'; END IF;
  INSERT INTO public.medicamentos(gtin,nombre_comercial,principio_activo,presentacion,laboratorio,cod_art,
   registro_sanitario,unidad_presentacion,cantidad_por_presentacion,requiere_cadena_frio,temperatura_min,temperatura_max,precio_kairos)
  VALUES(btrim(p_medicamento->>'gtin'),btrim(p_medicamento->>'nombre_comercial'),btrim(p_medicamento->>'principio_activo'),
   btrim(p_medicamento->>'presentacion'),NULLIF(btrim(p_medicamento->>'laboratorio'),''),NULLIF(btrim(p_medicamento->>'cod_art'),''),
   NULLIF(btrim(p_medicamento->>'registro_sanitario'),''),COALESCE(NULLIF(btrim(p_medicamento->>'unidad_presentacion'),''),'unidad'),
   COALESCE((p_medicamento->>'cantidad_por_presentacion')::integer,1),COALESCE((p_medicamento->>'requiere_cadena_frio')::boolean,false),
   COALESCE((p_medicamento->>'temperatura_min')::numeric,2),COALESCE((p_medicamento->>'temperatura_max')::numeric,8),
   (p_medicamento->>'precio_kairos')::numeric) RETURNING id INTO v_med;
 ELSE v_med:=(p_datos->>'medicamento_id')::uuid;
 END IF;
 SELECT requiere_cadena_frio INTO v_frio FROM public.medicamentos WHERE id=v_med AND activo FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'El medicamento no existe o está inhabilitado.'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(v_med::text||':'||v_numero,0));
 IF EXISTS(SELECT 1 FROM public.lotes WHERE medicamento_id=v_med AND upper(btrim(numero_lote))=v_numero) THEN
  RAISE EXCEPTION 'Este lote ya existe para el producto. Consulte Ingresos y correcciones; no registre otro ingreso.'; END IF;
 INSERT INTO public.lotes(medicamento_id,numero_lote,fecha_fabricacion,fecha_vencimiento,laboratorio,proveedor,
  precio_compra,precio_venta,num_boleta,justificacion,temperatura_recepcion,observaciones)
 VALUES(v_med,v_numero,NULLIF(p_datos->>'fecha_fabricacion','')::date,(p_datos->>'fecha_vencimiento')::date,
  NULLIF(btrim(p_datos->>'laboratorio'),''),NULLIF(btrim(p_datos->>'proveedor'),''),
  (p_datos->>'precio_compra')::numeric,(p_datos->>'precio_venta')::numeric,NULLIF(btrim(p_datos->>'num_boleta'),''),
  p_datos->>'justificacion',(p_datos->>'temperatura_recepcion')::numeric,NULLIF(btrim(p_datos->>'observaciones'),'')) RETURNING * INTO v_lote;
 INSERT INTO public.inventario_stock(lote_id,area_codigo,cantidad) VALUES(v_lote.id,'ALMACEN',v_cantidad);
 INSERT INTO public.ingresos_lote(lote_id,cantidad_original,cantidad_registrada,datos_originales)
  VALUES(v_lote.id,v_cantidad,v_cantidad,to_jsonb(v_lote));
 INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,
  medicamento_id,lote_id,area_destino,cantidad,descripcion,estado_nuevo,detalles_extra)
 VALUES('INGRESO_ALMACEN',v_lote.id,'lotes',v_actor,v_med,v_lote.id,'ALMACEN',v_cantidad,
  'Ingreso completo de lote y stock en Almacén',to_jsonb(v_lote),jsonb_build_object('cantidad',v_cantidad,
  'documento',v_lote.num_boleta,'precio_compra',v_lote.precio_compra,'justificacion',v_lote.justificacion));
 INSERT INTO public.operaciones_ingreso_lote(usuario_id,operacion_id,lote_id,accion,datos,resultado)
 VALUES(v_actor,p_operacion_id,v_lote.id,'INGRESO',v_datos,to_jsonb(v_lote));
 RETURN to_jsonb(v_lote);
END $$;

CREATE OR REPLACE FUNCTION public.huella_ingreso_lote(p_lote UUID) RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT md5(to_jsonb(l)::text||COALESCE(to_jsonb(i)::text,'')||COALESCE((SELECT string_agg(to_jsonb(s)::text,'|' ORDER BY s.area_codigo)
 FROM public.inventario_stock s WHERE s.lote_id=l.id),'')) FROM public.lotes l LEFT JOIN public.ingresos_lote i ON i.lote_id=l.id WHERE l.id=p_lote
$$;

CREATE OR REPLACE FUNCTION public.corregir_ingreso_lote_hu024(p_lote_id UUID,p_total INTEGER,p_ubicacion TEXT,
 p_motivo TEXT,p_version TEXT,p_operacion_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_actor UUID:=auth.uid();v_rol TEXT;v_l public.lotes%ROWTYPE;v_i public.ingresos_lote%ROWTYPE;
 v_a RECORD;v_op RECORD;v_delta INTEGER;v_datos JSONB;v_antes JSONB;v_resultado JSONB;
BEGIN
 SELECT rol INTO v_rol FROM public.profiles WHERE id=v_actor AND activo;
 IF v_actor IS NULL OR v_rol IS NULL OR v_rol NOT IN ('ALMACEN','ADMINISTRADOR') THEN RAISE EXCEPTION 'Solo Almacén puede corregir ingresos.'; END IF;
 IF p_operacion_id IS NULL OR p_total IS NULL OR p_total<0 OR p_motivo IS NULL
  OR length(btrim(p_motivo)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Indique una cantidad válida y una justificación de hasta 1000 caracteres.'; END IF;
 v_datos:=jsonb_build_object('lote',p_lote_id,'total',p_total,'ubicacion',p_ubicacion,'motivo',btrim(p_motivo),'version',p_version);
 PERFORM pg_advisory_xact_lock(hashtextextended(v_actor::text||p_operacion_id::text,0));
 SELECT * INTO v_op FROM public.operaciones_ingreso_lote WHERE usuario_id=v_actor AND operacion_id=p_operacion_id;
 IF FOUND THEN
  IF v_op.datos<>v_datos OR v_op.accion<>'CORRECCION' THEN RAISE EXCEPTION 'La clave corresponde a otra operación.'; END IF;
  RETURN v_op.resultado;
 END IF;
 -- Serializa el ajuste frente a los despachos y recepciones, sin cambiar sus RPC.
 LOCK TABLE public.inventario_stock IN EXCLUSIVE MODE;
 SELECT * INTO v_l FROM public.lotes WHERE id=p_lote_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'El lote no existe.'; END IF;
 IF p_version IS NULL OR p_version<>public.huella_ingreso_lote(p_lote_id) THEN RAISE EXCEPTION 'El lote o stock cambió. Actualice y revise la preconfirmación.'; END IF;
 SELECT * INTO v_i FROM public.ingresos_lote WHERE lote_id=p_lote_id FOR UPDATE;
 IF NOT FOUND THEN
  -- Compatibilidad: se requiere exactamente una entrada histórica auditada.
  SELECT count(*) n,max(cantidad) cantidad INTO v_a FROM public.auditoria_trazabilidad
   WHERE lote_id=p_lote_id AND tipo_evento='INGRESO_ALMACEN';
  IF v_a.n<>1 OR v_a.cantidad IS NULL OR v_a.cantidad<=0 THEN
   RAISE EXCEPTION 'El ingreso histórico no tiene una cantidad original inequívoca. Requiere conciliación; no se inferirá del stock restante.'; END IF;
  INSERT INTO public.ingresos_lote(lote_id,cantidad_original,cantidad_registrada,datos_originales)
   VALUES(p_lote_id,v_a.cantidad,v_a.cantidad,to_jsonb(v_l)) RETURNING * INTO v_i;
 END IF;
 v_delta:=p_total-v_i.cantidad_registrada;
 IF v_delta=0 THEN RAISE EXCEPTION 'La cantidad no cambió.'; END IF;
 IF p_ubicacion IS NULL OR p_ubicacion NOT IN ('ALMACEN','FARMACIA') OR (v_delta>0 AND p_ubicacion<>'ALMACEN') THEN
  RAISE EXCEPTION 'Los aumentos se guardan en Almacén; los descuentos deben indicar la ubicación verificada.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.areas WHERE codigo=p_ubicacion) THEN RAISE EXCEPTION 'Ubicación no válida.'; END IF;
 v_antes:=to_jsonb(v_i)||jsonb_build_object('stock',COALESCE((SELECT jsonb_object_agg(area_codigo,cantidad) FROM public.inventario_stock WHERE lote_id=p_lote_id),'{}'));
 IF v_delta>0 THEN
  INSERT INTO public.inventario_stock(lote_id,area_codigo,cantidad) VALUES(p_lote_id,'ALMACEN',v_delta)
   ON CONFLICT(lote_id,area_codigo) DO UPDATE SET cantidad=public.inventario_stock.cantidad+EXCLUDED.cantidad,updated_at=now();
 ELSE
  -- No tocar tránsito, áreas, consumo ni cantidades declaradas en recepciones.
  IF p_ubicacion='FARMACIA' AND EXISTS(SELECT 1 FROM public.pedido_abastecimiento_despachos d JOIN public.pedidos_abastecimiento_items i ON i.id=d.item_id
   JOIN public.pedidos_abastecimiento p ON p.id=i.pedido_id WHERE d.lote_id=p_lote_id AND p.estado='LISTO' AND NOT p.despacho_en_transito) THEN
   RAISE EXCEPTION 'Hay una recepción histórica pendiente: concilie antes de descontar Farmacia.'; END IF;
  UPDATE public.inventario_stock SET cantidad=cantidad+v_delta,updated_at=now()
   WHERE lote_id=p_lote_id AND area_codigo=p_ubicacion AND cantidad>=-v_delta;
  IF NOT FOUND THEN RAISE EXCEPTION 'Stock insuficiente en la ubicación elegida. Verifique la diferencia; no se descontarán unidades distribuidas, consumidas o en tránsito.'; END IF;
 END IF;
 UPDATE public.ingresos_lote SET cantidad_registrada=p_total WHERE lote_id=p_lote_id;
 v_resultado:=jsonb_build_object('lote_id',p_lote_id,'cantidad_original',v_i.cantidad_original,'cantidad_registrada',p_total,
  'diferencia',v_delta,'ubicacion',p_ubicacion);
 INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,
  medicamento_id,lote_id,area_origen,area_destino,cantidad,descripcion,estado_anterior,estado_nuevo,detalles_extra)
 VALUES('AJUSTE_INGRESO_LOTE',p_lote_id,'ingresos_lote',v_actor,v_l.medicamento_id,p_lote_id,
  CASE WHEN v_delta<0 THEN p_ubicacion ELSE NULL END,CASE WHEN v_delta>0 THEN 'ALMACEN' ELSE NULL END,
  abs(v_delta),btrim(p_motivo),v_antes,v_resultado,jsonb_build_object('delta',v_delta,'documento_original',v_l.num_boleta,'precio_original',v_l.precio_compra));
 INSERT INTO public.operaciones_ingreso_lote(usuario_id,operacion_id,lote_id,accion,datos,resultado)
 VALUES(v_actor,p_operacion_id,p_lote_id,'CORRECCION',v_datos,v_resultado);
 RETURN v_resultado;
END $$;

CREATE OR REPLACE FUNCTION public.consultar_ingresos_hu024() RETURNS SETOF JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_rol TEXT;BEGIN
 SELECT rol INTO v_rol FROM public.profiles WHERE id=auth.uid() AND activo;
 IF v_rol IS NULL OR v_rol NOT IN ('ALMACEN','JEFATURA_FARMACIA','ADMINISTRADOR') THEN RAISE EXCEPTION 'No puede consultar ingresos.'; END IF;
 RETURN QUERY SELECT to_jsonb(l)||jsonb_build_object('nombre',m.nombre_comercial,'cantidad_original',
 COALESCE(i.cantidad_original,CASE WHEN a.n=1 THEN a.cantidad END),'cantidad_registrada',
 COALESCE(i.cantidad_registrada,CASE WHEN a.n=1 THEN a.cantidad END),'version',public.huella_ingreso_lote(l.id),
 'almacen',COALESCE((SELECT cantidad FROM public.inventario_stock WHERE lote_id=l.id AND area_codigo='ALMACEN'),0),
 'farmacia',COALESCE((SELECT cantidad FROM public.inventario_stock WHERE lote_id=l.id AND area_codigo='FARMACIA'),0),
 'historial',COALESCE((SELECT jsonb_agg(jsonb_build_object('evento',au.tipo_evento,'cantidad',au.cantidad,
  'motivo',au.descripcion,'fecha',au.fecha,'usuario',pr.nombre,'antes',au.estado_anterior,'despues',au.estado_nuevo,'datos',au.detalles_extra)
  ORDER BY au.fecha,au.id) FROM public.auditoria_trazabilidad au LEFT JOIN public.profiles pr ON pr.id=au.usuario_id
  WHERE au.lote_id=l.id AND au.tipo_evento IN ('INGRESO_ALMACEN','AJUSTE_INGRESO_LOTE')),'[]'))
 FROM public.lotes l JOIN public.medicamentos m ON m.id=l.medicamento_id LEFT JOIN public.ingresos_lote i ON i.lote_id=l.id
 LEFT JOIN LATERAL(SELECT count(*) n,max(cantidad) cantidad FROM public.auditoria_trazabilidad WHERE lote_id=l.id AND tipo_evento='INGRESO_ALMACEN') a ON true
 ORDER BY l.fecha_ingreso DESC,l.id;
END $$;
REVOKE ALL ON FUNCTION public.registrar_ingreso_lote_hu024(UUID,JSONB,JSONB),
 public.corregir_ingreso_lote_hu024(UUID,INTEGER,TEXT,TEXT,TEXT,UUID),public.consultar_ingresos_hu024() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.registrar_ingreso_lote_hu024(UUID,JSONB,JSONB),
 public.corregir_ingreso_lote_hu024(UUID,INTEGER,TEXT,TEXT,TEXT,UUID),public.consultar_ingresos_hu024() TO authenticated;
REVOKE ALL ON FUNCTION public.huella_ingreso_lote(UUID) FROM PUBLIC,anon,authenticated;
-- Todo ingreso/ajuste de clientes debe llevar auditoría en una transacción.
REVOKE INSERT,UPDATE,DELETE ON public.lotes FROM authenticated;
REVOKE INSERT,UPDATE,DELETE ON public.inventario_stock FROM authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
