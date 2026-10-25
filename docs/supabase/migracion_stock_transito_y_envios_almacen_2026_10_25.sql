-- Stock disponible solo después del conteo y recepción física en Farmacia.
-- Requiere abastecimiento atómico 25/10/2026. No reescribe movimientos históricos.
BEGIN;
ALTER TABLE public.pedidos_abastecimiento
  ADD COLUMN IF NOT EXISTS despacho_en_transito BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS iniciativa TEXT NOT NULL DEFAULT 'SOLICITUD_FARMACIA'
    CHECK(iniciativa IN ('SOLICITUD_FARMACIA','TRASLADO_ALMACEN'));
ALTER TABLE public.pedido_abastecimiento_despachos
  ADD COLUMN IF NOT EXISTS cantidad_recibida INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.pedido_abastecimiento_despachos DROP CONSTRAINT IF EXISTS despacho_conteo_check;
ALTER TABLE public.pedido_abastecimiento_despachos ADD CONSTRAINT despacho_conteo_check
  CHECK(cantidad_recibida>=0 AND cantidad_recibida+cantidad_devuelta<=cantidad);

CREATE OR REPLACE FUNCTION public.procesar_pedido_abastecimiento(
  p_pedido_id UUID,
  p_accion TEXT,
  p_motivo TEXT DEFAULT NULL,
  p_cantidades JSONB DEFAULT '{}'::jsonb,
  p_modalidad TEXT DEFAULT NULL,
  p_notas TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_usuario UUID := auth.uid();
  v_rol TEXT;
  v_pedido public.pedidos_abastecimiento%ROWTYPE;
  v_item RECORD;
  v_stock RECORD;
  v_despacho RECORD;
  v_cantidad INTEGER;
  v_restante INTEGER;
  v_movimiento INTEGER;
  v_total INTEGER := 0;
  v_devolucion INTEGER;
  v_aceptada_lote INTEGER;
  v_evento TEXT;
  v_nuevo TEXT;
BEGIN
  SELECT rol INTO v_rol FROM public.profiles WHERE id = v_usuario AND activo;
  IF v_usuario IS NULL OR v_rol IS NULL THEN
    RAISE EXCEPTION 'Inicie sesión con un usuario activo para realizar esta acción.';
  END IF;
  IF p_accion IS NULL OR p_accion NOT IN ('TOMAR', 'CANCELAR', 'RECHAZAR', 'DESPACHAR', 'RECIBIR') THEN
    RAISE EXCEPTION 'Acción de pedido no válida.';
  END IF;
  IF v_rol <> 'ADMINISTRADOR' AND (
     p_accion IN ('CANCELAR', 'RECIBIR') AND v_rol <> 'FARMACIA'
     OR p_accion IN ('TOMAR', 'RECHAZAR', 'DESPACHAR') AND v_rol <> 'ALMACEN') THEN
    RAISE EXCEPTION 'Su rol no puede realizar esta acción.';
  END IF;

  SELECT * INTO v_pedido FROM public.pedidos_abastecimiento WHERE id = p_pedido_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El pedido no existe.'; END IF;
  IF v_pedido.area_origen <> 'FARMACIA' OR v_pedido.area_destino <> 'ALMACEN' THEN
    RAISE EXCEPTION 'Esta operación solo admite pedidos de Farmacia a Almacén.';
  END IF;
  -- Validar el contenido también en un reintento de una transición completada.
  IF p_accion IN ('DESPACHAR','RECIBIR') THEN
    IF p_cantidades IS NULL OR jsonb_typeof(p_cantidades)<>'object' THEN
      RAISE EXCEPTION 'Las cantidades no son válidas.';
    END IF;
    IF EXISTS (SELECT 1 FROM jsonb_each(p_cantidades) x
      WHERE jsonb_typeof(x.value)<>'number' OR x.value::TEXT !~ '^[0-9]+$'
      OR NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i
        WHERE i.pedido_id=p_pedido_id AND i.id::TEXT=x.key)) THEN
      RAISE EXCEPTION 'Indique cantidades enteras de los ítems de este pedido.';
    END IF;
  END IF;

  -- Un reintento idéntico del mismo actor devuelve éxito sin stock ni eventos nuevos.
  IF p_accion='CANCELAR' AND v_rol<>'ADMINISTRADOR'
     AND v_pedido.solicitante_id IS DISTINCT FROM v_usuario THEN
    RAISE EXCEPTION 'Solo el solicitante o Administración pueden cancelar este pedido.' USING ERRCODE='42501';
  END IF;
  IF p_accion='TOMAR' AND v_pedido.estado IN ('EN_PREPARACION','LISTO','COMPLETADO')
     AND v_pedido.responsable_almacen_id=v_usuario THEN RETURN; END IF;
  IF p_accion='CANCELAR' AND v_pedido.estado='CANCELADO' AND v_pedido.cancelado_por=v_usuario
     AND v_pedido.motivo_cancelacion IS NOT DISTINCT FROM NULLIF(btrim(p_motivo),'') THEN RETURN; END IF;
  IF p_accion='RECHAZAR' AND v_pedido.estado='RECHAZADO' AND v_pedido.rechazado_por=v_usuario
     AND v_pedido.motivo_rechazo IS NOT DISTINCT FROM NULLIF(btrim(p_motivo),'') THEN RETURN; END IF;
  IF p_accion='DESPACHAR' AND v_pedido.estado IN ('LISTO','COMPLETADO')
     AND v_pedido.responsable_almacen_id=v_usuario AND v_pedido.modalidad_entrega=p_modalidad
     AND v_pedido.notas_almacen IS NOT DISTINCT FROM NULLIF(btrim(p_notas),'')
     AND NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=p_pedido_id
       AND i.cantidad_despachada IS DISTINCT FROM COALESCE((p_cantidades->>i.id::TEXT)::INTEGER,0))
     THEN RETURN; END IF;
  IF p_accion='RECIBIR' AND v_pedido.estado='COMPLETADO'
     AND v_pedido.responsable_farmacia_id=v_usuario
     AND NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=p_pedido_id
       AND i.cantidad_recibida IS DISTINCT FROM COALESCE((p_cantidades->>i.id::TEXT)::INTEGER,i.cantidad_despachada))
     AND v_pedido.observacion_recepcion IS NOT DISTINCT FROM (
       CASE WHEN EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i
         WHERE i.pedido_id=p_pedido_id AND i.cantidad_recibida<i.cantidad_despachada)
       THEN NULLIF(btrim(p_motivo),'') ELSE NULL END)
     THEN RETURN; END IF;

  IF p_accion = 'CANCELAR' AND v_pedido.estado <> 'PENDIENTE' THEN
    RAISE EXCEPTION 'El pedido ya no está pendiente. Comuníquese físicamente con Almacén si requiere cancelarlo.';
  END IF;
  IF p_accion = 'TOMAR' AND v_pedido.estado <> 'PENDIENTE'
     OR p_accion = 'RECHAZAR' AND v_pedido.estado NOT IN ('PENDIENTE', 'EN_PREPARACION')
     OR p_accion = 'DESPACHAR' AND v_pedido.estado <> 'EN_PREPARACION'
     OR p_accion = 'RECIBIR' AND (v_pedido.estado <> 'LISTO' OR NOT COALESCE(v_pedido.confirmado_almacen, false)) THEN
    RAISE EXCEPTION 'El pedido cambió de estado. Actualice la lista antes de continuar.';
  END IF;
  IF p_accion IN ('CANCELAR', 'RECHAZAR') AND NULLIF(btrim(p_motivo), '') IS NULL THEN
    RAISE EXCEPTION 'Debe indicar un motivo.';
  END IF;

  IF p_accion IN ('DESPACHAR', 'RECIBIR') THEN
    IF p_cantidades IS NULL OR jsonb_typeof(p_cantidades) <> 'object' THEN
      RAISE EXCEPTION 'Las cantidades no son válidas.';
    END IF;
    IF EXISTS (
      SELECT 1 FROM jsonb_each(p_cantidades) x
      WHERE jsonb_typeof(x.value) <> 'number' OR x.value::TEXT !~ '^[0-9]+$'
        OR NOT EXISTS (SELECT 1 FROM public.pedidos_abastecimiento_items i
                       WHERE i.pedido_id = p_pedido_id AND i.id::TEXT = x.key)
    ) THEN RAISE EXCEPTION 'Indique cantidades enteras de los ítems de este pedido.'; END IF;
    PERFORM id FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'El pedido no contiene ítems.'; END IF;
    -- Orden fijo de bloqueo para evitar pérdidas por movimientos concurrentes.
    PERFORM s.id FROM public.inventario_stock s JOIN public.lotes l ON l.id = s.lote_id
      WHERE s.area_codigo IN ('ALMACEN', 'FARMACIA') AND l.medicamento_id IN (
        SELECT medicamento_id FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id
      ) ORDER BY s.id FOR UPDATE OF s;
  END IF;

  CASE p_accion
  WHEN 'TOMAR' THEN
    v_nuevo := 'EN_PREPARACION'; v_evento := 'TOMA_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      responsable_almacen_id = v_usuario, fecha_toma = now() WHERE id = p_pedido_id;
  WHEN 'CANCELAR' THEN
    v_nuevo := 'CANCELADO'; v_evento := 'CANCELACION_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      motivo_cancelacion = btrim(p_motivo), fecha_cancelacion = now(), cancelado_por = v_usuario
      WHERE id = p_pedido_id;
  WHEN 'RECHAZAR' THEN
    v_nuevo := 'RECHAZADO'; v_evento := 'RECHAZO_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo,
      motivo_rechazo = btrim(p_motivo), fecha_rechazo = now(), rechazado_por = v_usuario
      WHERE id = p_pedido_id;
  WHEN 'DESPACHAR' THEN
    IF p_modalidad IS NULL OR p_modalidad NOT IN ('ENTREGA', 'RECOJO') THEN
      RAISE EXCEPTION 'Seleccione si Almacén entrega o Farmacia recoge.';
    END IF;
    FOR v_item IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id LOOP
      v_cantidad := COALESCE((p_cantidades->>v_item.id::TEXT)::INTEGER, 0);
      IF v_cantidad > v_item.cantidad_solicitada THEN
        RAISE EXCEPTION 'El despacho no puede superar la cantidad solicitada.';
      END IF;
      v_restante := v_cantidad;
      FOR v_stock IN
        SELECT s.*, l.fecha_vencimiento FROM public.inventario_stock s
        JOIN public.lotes l ON l.id = s.lote_id
        WHERE s.area_codigo = 'ALMACEN' AND l.medicamento_id = v_item.medicamento_id
          AND l.activo AND l.fecha_vencimiento > CURRENT_DATE AND s.cantidad > 0
        ORDER BY l.fecha_vencimiento, l.id
      LOOP
        EXIT WHEN v_restante = 0;
        v_movimiento := LEAST(v_restante, v_stock.cantidad);
        UPDATE public.inventario_stock SET cantidad = cantidad - v_movimiento, updated_at = now() WHERE id = v_stock.id;
        -- Estas unidades están en tránsito: no son stock disponible en Farmacia.
        INSERT INTO public.pedido_abastecimiento_despachos(item_id, lote_id, cantidad)
          VALUES(v_item.id, v_stock.lote_id, v_movimiento);
        INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
          usuario_id, medicamento_id, lote_id, area_origen, area_destino, cantidad, descripcion)
          VALUES('SALIDA_A_TRANSITO', p_pedido_id, 'pedidos_abastecimiento', v_usuario,
            v_item.medicamento_id, v_stock.lote_id, 'ALMACEN', 'FARMACIA', v_movimiento, 'Salida a tránsito del pedido ' || v_pedido.codigo);
        v_restante := v_restante - v_movimiento;
      END LOOP;
      IF v_restante > 0 THEN RAISE EXCEPTION 'Stock disponible insuficiente. Actualice las cantidades antes de despachar.'; END IF;
      UPDATE public.pedidos_abastecimiento_items SET cantidad_despachada = v_cantidad WHERE id = v_item.id;
      v_total := v_total + v_cantidad;
    END LOOP;
    IF v_total = 0 THEN RAISE EXCEPTION 'No se puede despachar un pedido vacío. Utilice Rechazar Solicitud.'; END IF;
    v_nuevo := 'LISTO'; v_evento := 'DESPACHO_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo, modalidad_entrega = p_modalidad,
      confirmado_almacen = true, responsable_almacen_id = v_usuario, despacho_en_transito = true,
      fecha_listo = now(), fecha_despacho = now(), fecha_confirmacion_almacen = now(),
      notas_almacen = NULLIF(btrim(p_notas), '') WHERE id = p_pedido_id;
  WHEN 'RECIBIR' THEN
    IF v_pedido.despacho_en_transito THEN
      FOR v_item IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id=p_pedido_id ORDER BY id LOOP
        v_cantidad:=COALESCE((p_cantidades->>v_item.id::TEXT)::INTEGER,v_item.cantidad_despachada);
        IF v_cantidad<0 OR v_cantidad>v_item.cantidad_despachada THEN
          RAISE EXCEPTION 'La cantidad contada debe estar entre cero y lo despachado.';
        END IF;
        v_devolucion:=v_item.cantidad_despachada-v_cantidad;
        IF v_devolucion>0 AND NULLIF(btrim(p_motivo),'') IS NULL THEN
          RAISE EXCEPTION 'Indique el motivo de la diferencia o devolución.';
        END IF;
        IF (SELECT COALESCE(sum(cantidad),0) FROM public.pedido_abastecimiento_despachos WHERE item_id=v_item.id)
           <>v_item.cantidad_despachada THEN
          RAISE EXCEPTION 'El detalle de lotes no coincide con el despacho.';
        END IF;
        v_restante:=v_cantidad;
        -- Se aceptan primero los lotes con vencimiento más próximo.
        FOR v_despacho IN SELECT d.* FROM public.pedido_abastecimiento_despachos d
          JOIN public.lotes l ON l.id=d.lote_id WHERE d.item_id=v_item.id
          ORDER BY l.fecha_vencimiento,l.id FOR UPDATE OF d
        LOOP
          v_aceptada_lote:=LEAST(v_restante,v_despacho.cantidad);
          v_movimiento:=v_despacho.cantidad-v_aceptada_lote;
          IF v_aceptada_lote>0 THEN
            INSERT INTO public.inventario_stock(lote_id,area_codigo,cantidad)
              VALUES(v_despacho.lote_id,'FARMACIA',v_aceptada_lote)
              ON CONFLICT(lote_id,area_codigo) DO UPDATE
              SET cantidad=public.inventario_stock.cantidad+EXCLUDED.cantidad,updated_at=now();
            INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,
              usuario_id,medicamento_id,lote_id,area_origen,area_destino,cantidad,descripcion,detalles_extra)
            VALUES('RECEPCION_LOTE_FARMACIA',p_pedido_id,'pedidos_abastecimiento',v_usuario,
              v_item.medicamento_id,v_despacho.lote_id,'ALMACEN','FARMACIA',v_aceptada_lote,
              'Cantidad física contada y aceptada en Farmacia',
              jsonb_build_object('item_id',v_item.id,'desde_transito',true,'motivo',p_motivo));
          END IF;
          IF v_movimiento>0 THEN
            INSERT INTO public.inventario_stock(lote_id,area_codigo,cantidad)
              VALUES(v_despacho.lote_id,'ALMACEN',v_movimiento)
              ON CONFLICT(lote_id,area_codigo) DO UPDATE
              SET cantidad=public.inventario_stock.cantidad+EXCLUDED.cantidad,updated_at=now();
            INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,
              usuario_id,medicamento_id,lote_id,area_origen,area_destino,cantidad,descripcion,detalles_extra)
            VALUES('DEVOLUCION_EN_RECEPCION',p_pedido_id,'pedidos_abastecimiento',v_usuario,
              v_item.medicamento_id,v_despacho.lote_id,'FARMACIA','ALMACEN',v_movimiento,btrim(p_motivo),
              jsonb_build_object('item_id',v_item.id,'desde_transito',true,
                'despachado',v_item.cantidad_despachada,'aceptado',v_cantidad));
          END IF;
          UPDATE public.pedido_abastecimiento_despachos
            SET cantidad_recibida=v_aceptada_lote,cantidad_devuelta=v_movimiento WHERE id=v_despacho.id;
          v_restante:=v_restante-v_aceptada_lote;
        END LOOP;
        UPDATE public.pedidos_abastecimiento_items SET cantidad_recibida=v_cantidad WHERE id=v_item.id;
        v_total:=v_total+v_devolucion;
      END LOOP;
    ELSE
      -- Los despachos previos conservan su tratamiento y auditoría originales.
    FOR v_item IN SELECT * FROM public.pedidos_abastecimiento_items WHERE pedido_id = p_pedido_id ORDER BY id LOOP
      v_cantidad := COALESCE((p_cantidades->>v_item.id::TEXT)::INTEGER, v_item.cantidad_despachada);
      IF v_cantidad < 0 OR v_cantidad > v_item.cantidad_despachada THEN
        RAISE EXCEPTION 'La cantidad aceptada debe estar entre cero y lo despachado.';
      END IF;
      v_devolucion := v_item.cantidad_despachada - v_cantidad;
      IF v_devolucion > 0 THEN
        IF NULLIF(btrim(p_motivo), '') IS NULL THEN RAISE EXCEPTION 'Indique el motivo de la devolución.'; END IF;
        -- Compatibilidad con despachos anteriores que guardaban un único lote.
        IF NOT EXISTS (SELECT 1 FROM public.pedido_abastecimiento_despachos WHERE item_id = v_item.id) THEN
          IF v_item.lote_id IS NULL THEN
            RAISE EXCEPTION 'El despacho anterior no tiene lote trazable. Revise el movimiento antes de devolver.';
          END IF;
          INSERT INTO public.pedido_abastecimiento_despachos(item_id, lote_id, cantidad)
            VALUES(v_item.id, v_item.lote_id, v_item.cantidad_despachada);
        END IF;
        v_restante := v_devolucion;
        -- Retorna primero los lotes con vencimiento posterior; conserva FEFO en lo aceptado.
        FOR v_despacho IN SELECT d.* FROM public.pedido_abastecimiento_despachos d
          JOIN public.lotes l ON l.id = d.lote_id WHERE d.item_id = v_item.id
          ORDER BY l.fecha_vencimiento DESC, l.id DESC FOR UPDATE OF d
        LOOP
          EXIT WHEN v_restante = 0;
          v_movimiento := LEAST(v_restante, v_despacho.cantidad - v_despacho.cantidad_devuelta);
          IF v_movimiento = 0 THEN CONTINUE; END IF;
          UPDATE public.inventario_stock SET cantidad = cantidad - v_movimiento, updated_at = now()
            WHERE lote_id = v_despacho.lote_id AND area_codigo = 'FARMACIA' AND cantidad >= v_movimiento;
          IF NOT FOUND THEN RAISE EXCEPTION 'Stock de Farmacia insuficiente para devolver el lote. Revise el inventario.'; END IF;
          INSERT INTO public.inventario_stock(lote_id, area_codigo, cantidad)
            VALUES(v_despacho.lote_id, 'ALMACEN', v_movimiento)
            ON CONFLICT (lote_id, area_codigo) DO UPDATE
            SET cantidad = public.inventario_stock.cantidad + EXCLUDED.cantidad, updated_at = now();
          UPDATE public.pedido_abastecimiento_despachos SET cantidad_devuelta = cantidad_devuelta + v_movimiento WHERE id = v_despacho.id;
          INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
            usuario_id, medicamento_id, lote_id, area_origen, area_destino, cantidad, descripcion, detalles_extra)
            VALUES('DEVOLUCION_EN_RECEPCION', p_pedido_id, 'pedidos_abastecimiento', v_usuario,
              v_item.medicamento_id, v_despacho.lote_id, 'FARMACIA', 'ALMACEN', v_movimiento,
              btrim(p_motivo), jsonb_build_object('item_id', v_item.id, 'despachado', v_item.cantidad_despachada, 'aceptado', v_cantidad));
          v_restante := v_restante - v_movimiento;
        END LOOP;
        IF v_restante > 0 THEN RAISE EXCEPTION 'El detalle de lotes no cubre la devolución. Revise el despacho.'; END IF;
      END IF;
      UPDATE public.pedidos_abastecimiento_items SET cantidad_recibida = v_cantidad WHERE id = v_item.id;
      v_total := v_total + v_devolucion;
    END LOOP;
    END IF;
    v_nuevo := 'COMPLETADO'; v_evento := 'RECEPCION_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo, confirmado_farmacia = true,
      responsable_farmacia_id = v_usuario, fecha_confirmacion_farmacia = now(), fecha_recepcion = now(), fecha_completado = now(),
      observacion_recepcion = CASE WHEN v_total > 0 THEN btrim(p_motivo) ELSE NULL END WHERE id = p_pedido_id;
  END CASE;

  INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
    usuario_id, estado_anterior, estado_nuevo, descripcion, detalles_extra)
    VALUES(v_evento, p_pedido_id, 'pedidos_abastecimiento', v_usuario,
      jsonb_build_object('estado', v_pedido.estado), jsonb_build_object('estado', v_nuevo),
      p_accion || ' pedido ' || v_pedido.codigo,
      jsonb_build_object('motivo', p_motivo, 'modalidad', p_modalidad, 'cantidades', p_cantidades));
END;
$$;

REVOKE ALL ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.procesar_pedido_abastecimiento(UUID,TEXT,TEXT,JSONB,TEXT,TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.registrar_abastecimiento_interno(
  p_solicitud_id UUID, p_area_destino TEXT, p_turno TEXT, p_justificacion TEXT,
  p_notas TEXT, p_items JSONB, p_iniciativa TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_usuario UUID := auth.uid();
  v_rol TEXT := public.sitra_rol_actual();
  v_pedido public.pedidos_abastecimiento%ROWTYPE;
  v_datos JSONB;
  v_items JSONB;
  v_numero BIGINT;
BEGIN
  IF v_usuario IS NULL OR v_rol IS NULL OR p_iniciativa IS NULL OR
     (p_iniciativa='SOLICITUD_FARMACIA' AND v_rol NOT IN ('FARMACIA','ADMINISTRADOR')) OR
     (p_iniciativa='TRASLADO_ALMACEN' AND v_rol NOT IN ('ALMACEN','ADMINISTRADOR')) OR
     p_iniciativa NOT IN ('SOLICITUD_FARMACIA','TRASLADO_ALMACEN') THEN
    RAISE EXCEPTION 'Su rol no puede iniciar esta operación de abastecimiento.' USING ERRCODE='42501';
  END IF;
  IF p_iniciativa='TRASLADO_ALMACEN' AND NULLIF(btrim(p_notas),'') IS NULL THEN
    RAISE EXCEPTION 'Indique el motivo del envío iniciado por Almacén.';
  END IF;
  IF p_solicitud_id IS NULL OR p_area_destino IS DISTINCT FROM 'ALMACEN'
     OR p_turno IS NULL OR p_turno NOT IN ('DIA','TARDE','NOCHE')
     OR p_justificacion IS NULL OR p_justificacion NOT IN ('STOCK_CERO','RELLENAR_STOCK') THEN
    RAISE EXCEPTION 'Solicitud, destino, turno o justificación inválidos.';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items)<>'object' OR p_items='{}'::JSONB THEN
    RAISE EXCEPTION 'Agrega al menos un medicamento con cantidad mayor que cero.';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_each(p_items) x
    WHERE x.key !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      OR jsonb_typeof(x.value)<>'number' OR x.value::TEXT !~ '^[1-9][0-9]*$') THEN
    RAISE EXCEPTION 'Los medicamentos y cantidades enteras deben ser válidos.';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_each(p_items) x WHERE (x.value::TEXT)::NUMERIC>2147483647) THEN
    RAISE EXCEPTION 'La cantidad solicitada supera el límite permitido.';
  END IF;
  v_datos:=jsonb_build_object('destino',p_area_destino,'turno',p_turno,
    'justificacion',p_justificacion,'notas',NULLIF(btrim(p_notas),''),'items',p_items,'iniciativa',p_iniciativa);

  -- Serializa dos envíos simultáneos con la misma clave antes de buscar el pedido.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_usuario::TEXT||':'||p_solicitud_id::TEXT,29));
  SELECT * INTO v_pedido FROM public.pedidos_abastecimiento
    WHERE solicitante_id=v_usuario AND solicitud_id=p_solicitud_id;
  IF FOUND THEN
    IF (v_pedido.solicitud_datos||jsonb_build_object('iniciativa',v_pedido.iniciativa)) IS DISTINCT FROM v_datos THEN
      RAISE EXCEPTION 'La clave de envío ya corresponde a otra solicitud.';
    END IF;
    SELECT COALESCE(jsonb_agg(to_jsonb(i) ORDER BY i.id),'[]'::JSONB) INTO v_items
      FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=v_pedido.id;
    RETURN to_jsonb(v_pedido)||jsonb_build_object('items',v_items);
  END IF;

  -- Comparte bloqueos con la deshabilitación del catálogo y de las áreas.
  PERFORM id FROM public.areas WHERE codigo IN ('FARMACIA','ALMACEN') ORDER BY id FOR SHARE;
  IF (SELECT count(*) FROM public.areas WHERE codigo IN ('FARMACIA','ALMACEN') AND activo)<>2 THEN
    RAISE EXCEPTION 'Farmacia y Almacén deben estar habilitados para nuevas solicitudes.';
  END IF;
  PERFORM m.id FROM public.medicamentos m JOIN jsonb_object_keys(p_items) x(id)
    ON m.id=x.id::UUID ORDER BY m.id FOR SHARE OF m;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_items) x(id) WHERE NOT EXISTS (
    SELECT 1 FROM public.medicamentos m WHERE m.id=x.id::UUID AND m.activo)) THEN
    RAISE EXCEPTION 'Un medicamento no existe o está deshabilitado.';
  END IF;

  v_numero:=nextval('public.pedido_abastecimiento_codigo_seq');
  INSERT INTO public.pedidos_abastecimiento(codigo,solicitante_id,area_origen,area_destino,
    turno,justificacion,notas,estado,solicitud_id,solicitud_datos,iniciativa)
  VALUES('REQ-'||to_char(CURRENT_DATE,'YYYYMMDD')||'-'||lpad(v_numero::TEXT,GREATEST(6,length(v_numero::TEXT)),'0'),
    v_usuario,'FARMACIA','ALMACEN',p_turno,p_justificacion,NULLIF(btrim(p_notas),''),
    'PENDIENTE',p_solicitud_id,v_datos,p_iniciativa) RETURNING * INTO v_pedido;
  INSERT INTO public.pedidos_abastecimiento_items(pedido_id,medicamento_id,cantidad_solicitada)
    SELECT v_pedido.id,x.key::UUID,(x.value::TEXT)::INTEGER FROM jsonb_each(p_items) x ORDER BY x.key;
  SELECT jsonb_agg(to_jsonb(i) ORDER BY i.id) INTO v_items
    FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=v_pedido.id;
  INSERT INTO public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,
    usuario_id,area_origen,area_destino,estado_nuevo,descripcion,detalles_extra)
  VALUES(CASE WHEN p_iniciativa='TRASLADO_ALMACEN' THEN 'INICIO_TRASLADO_ALMACEN' ELSE 'CREACION_PEDIDO' END,v_pedido.id,'pedidos_abastecimiento',v_usuario,'FARMACIA','ALMACEN',
    to_jsonb(v_pedido)||jsonb_build_object('items',v_items),'Creación de solicitud '||v_pedido.codigo,
    jsonb_build_object('solicitud_id',p_solicitud_id,'turno',p_turno,'justificacion',p_justificacion,'items',p_items));
  RETURN to_jsonb(v_pedido)||jsonb_build_object('items',v_items);
END;
$$;

REVOKE ALL ON FUNCTION public.registrar_abastecimiento_interno(UUID,TEXT,TEXT,TEXT,TEXT,JSONB,TEXT) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.crear_pedido_abastecimiento(
  p_solicitud_id UUID,p_area_destino TEXT,p_turno TEXT,p_justificacion TEXT,
  p_notas TEXT DEFAULT NULL,p_items JSONB DEFAULT '{}'::JSONB
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  RETURN public.registrar_abastecimiento_interno(p_solicitud_id,p_area_destino,p_turno,
    p_justificacion,p_notas,p_items,'SOLICITUD_FARMACIA');
END;
$$;
REVOKE ALL ON FUNCTION public.crear_pedido_abastecimiento(UUID,TEXT,TEXT,TEXT,TEXT,JSONB) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.crear_pedido_abastecimiento(UUID,TEXT,TEXT,TEXT,TEXT,JSONB) TO authenticated;

-- El envío iniciado por Almacén crea y despacha en una transacción.
-- La cantidad que no se selecciona permanece en Almacén; Farmacia aún debe contar.
CREATE OR REPLACE FUNCTION public.iniciar_traslado_almacen(
  p_solicitud_id UUID,p_area_destino TEXT,p_turno TEXT,p_justificacion TEXT,
  p_notas TEXT,p_items JSONB,p_modalidad TEXT DEFAULT 'ENTREGA'
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_respuesta JSONB;v_cantidades JSONB;v_pedido public.pedidos_abastecimiento%ROWTYPE;
BEGIN
  v_respuesta:=public.registrar_abastecimiento_interno(p_solicitud_id,p_area_destino,p_turno,
    p_justificacion,p_notas,p_items,'TRASLADO_ALMACEN');
  SELECT jsonb_object_agg(i.id::TEXT,i.cantidad_solicitada) INTO v_cantidades
    FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=(v_respuesta->>'id')::UUID;
  PERFORM public.procesar_pedido_abastecimiento((v_respuesta->>'id')::UUID,'TOMAR');
  PERFORM public.procesar_pedido_abastecimiento((v_respuesta->>'id')::UUID,'DESPACHAR',NULL,v_cantidades,p_modalidad,p_notas);
  SELECT * INTO v_pedido FROM public.pedidos_abastecimiento WHERE id=(v_respuesta->>'id')::UUID;
  RETURN to_jsonb(v_pedido)||jsonb_build_object('items',(
    SELECT jsonb_agg(to_jsonb(i) ORDER BY i.id) FROM public.pedidos_abastecimiento_items i WHERE i.pedido_id=v_pedido.id));
END;
$$;
REVOKE ALL ON FUNCTION public.iniciar_traslado_almacen(UUID,TEXT,TEXT,TEXT,TEXT,JSONB,TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.iniciar_traslado_almacen(UUID,TEXT,TEXT,TEXT,TEXT,JSONB,TEXT) TO authenticated;

-- Consulta consolidada: el tránsito nunca se suma a disponible en Farmacia.
-- Las reservas de despachos antiguos se restan para no publicar stock sin recibir.
CREATE OR REPLACE FUNCTION public.consultar_stock_ubicaciones(
  p_busqueda TEXT DEFAULT '',p_desde INTEGER DEFAULT 0,p_limite INTEGER DEFAULT 200
) RETURNS TABLE(medicamento_id UUID,nombre TEXT,principio_activo TEXT,gtin TEXT,
  presentacion TEXT,unidad TEXT,activo BOOLEAN,almacen_disponible BIGINT,
  farmacia_disponible BIGINT,en_transito BIGINT,almacen_fisico BIGINT,
  farmacia_fisico BIGINT,pendiente_conciliacion BOOLEAN)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF public.sitra_rol_actual() IS NULL THEN
    RAISE EXCEPTION 'Inicia sesión con un perfil activo.' USING ERRCODE='42501';
  END IF;
  IF p_desde IS NULL OR p_desde<0 OR p_limite IS NULL OR p_limite<1 OR p_limite>500 THEN
    RAISE EXCEPTION 'Paginación inválida.';
  END IF;
  RETURN QUERY
  WITH mov AS (
    SELECT d.lote_id,
      COALESCE(sum(CASE WHEN p.despacho_en_transito
        THEN d.cantidad-d.cantidad_recibida-d.cantidad_devuelta ELSE 0 END),0)::BIGINT nuevo,
      COALESCE(sum(CASE WHEN NOT p.despacho_en_transito
        THEN d.cantidad-d.cantidad_devuelta ELSE 0 END),0)::BIGINT legado
    FROM public.pedido_abastecimiento_despachos d
    JOIN public.pedidos_abastecimiento_items i ON i.id=d.item_id
    JOIN public.pedidos_abastecimiento p ON p.id=i.pedido_id
    WHERE p.estado='LISTO' AND NOT p.confirmado_farmacia GROUP BY d.lote_id
  ), saldos AS (
    SELECT s.lote_id,
      COALESCE(sum(s.cantidad) FILTER(WHERE s.area_codigo='ALMACEN'),0)::BIGINT almacen,
      COALESCE(sum(s.cantidad) FILTER(WHERE s.area_codigo='FARMACIA'),0)::BIGINT farmacia
    FROM public.inventario_stock s WHERE s.area_codigo IN ('ALMACEN','FARMACIA') GROUP BY s.lote_id
  ), por_producto AS (
    SELECT l.medicamento_id,
      COALESCE(sum(CASE WHEN l.activo AND l.fecha_vencimiento>CURRENT_DATE THEN COALESCE(s.almacen,0) ELSE 0 END),0)::BIGINT ad,
      COALESCE(sum(CASE WHEN l.activo AND l.fecha_vencimiento>CURRENT_DATE
        THEN GREATEST(COALESCE(s.farmacia,0)-COALESCE(mv.legado,0),0) ELSE 0 END),0)::BIGINT fd,
      COALESCE(sum(COALESCE(mv.nuevo,0)+COALESCE(mv.legado,0)),0)::BIGINT tr,
      COALESCE(sum(COALESCE(s.almacen,0)),0)::BIGINT af,
      COALESCE(sum(GREATEST(COALESCE(s.farmacia,0)-COALESCE(mv.legado,0),0)),0)::BIGINT ff,
      COALESCE(bool_or(COALESCE(mv.legado,0)>COALESCE(s.farmacia,0)),false) conciliar
    FROM public.lotes l LEFT JOIN saldos s ON s.lote_id=l.id LEFT JOIN mov mv ON mv.lote_id=l.id
    GROUP BY l.medicamento_id
  )
  SELECT m.id,m.nombre_comercial,m.principio_activo,m.gtin,m.presentacion,m.unidad_presentacion,m.activo,
    CASE WHEN m.activo THEN COALESCE(pp.ad,0) ELSE 0 END,
    CASE WHEN m.activo THEN COALESCE(pp.fd,0) ELSE 0 END,
    COALESCE(pp.tr,0),COALESCE(pp.af,0),COALESCE(pp.ff,0),COALESCE(pp.conciliar,false)
  FROM public.medicamentos m LEFT JOIN por_producto pp ON pp.medicamento_id=m.id
  WHERE COALESCE(p_busqueda,'')='' OR m.nombre_comercial ILIKE '%'||p_busqueda||'%'
    OR m.principio_activo ILIKE '%'||p_busqueda||'%' OR m.gtin ILIKE '%'||p_busqueda||'%'
  ORDER BY lower(m.nombre_comercial),m.id OFFSET p_desde LIMIT p_limite;
END;
$$;
REVOKE ALL ON FUNCTION public.consultar_stock_ubicaciones(TEXT,INTEGER,INTEGER) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.consultar_stock_ubicaciones(TEXT,INTEGER,INTEGER) TO authenticated;

NOTIFY pgrst,'reload schema';
COMMIT;
