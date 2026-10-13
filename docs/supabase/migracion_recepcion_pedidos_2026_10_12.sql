-- SITRA-Luz: ejecutar en SQL Editor ANTES de usar la app actualizada.
-- Migración para una base existente. No incluye usuarios, semillas ni borrados.
-- Si algún estado antiguo no es compatible, BEGIN/COMMIT revierte la migración.
BEGIN;

ALTER TABLE public.pedidos_abastecimiento
  ADD COLUMN IF NOT EXISTS motivo_cancelacion TEXT,
  ADD COLUMN IF NOT EXISTS fecha_cancelacion TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS motivo_rechazo TEXT,
  ADD COLUMN IF NOT EXISTS fecha_rechazo TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancelado_por UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS rechazado_por UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS observacion_recepcion TEXT,
  ADD COLUMN IF NOT EXISTS modalidad_entrega TEXT CHECK (modalidad_entrega IN ('ENTREGA', 'RECOJO')),
  ADD COLUMN IF NOT EXISTS confirmado_almacen BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS confirmado_farmacia BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS responsable_almacen_id UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS responsable_farmacia_id UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS fecha_toma TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_listo TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_despacho TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_confirmacion_almacen TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_confirmacion_farmacia TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_completado TIMESTAMPTZ;

ALTER TABLE public.pedidos_abastecimiento
  DROP CONSTRAINT IF EXISTS pedidos_abastecimiento_estado_check;
ALTER TABLE public.pedidos_abastecimiento
  ADD CONSTRAINT pedidos_abastecimiento_estado_check CHECK (estado IN (
    'PENDIENTE', 'EN_PREPARACION', 'LISTO', 'COMPLETADO', 'CANCELADO', 'RECHAZADO'
  ));

ALTER TABLE public.pedidos_abastecimiento_items
  ADD COLUMN IF NOT EXISTS cantidad_despachada INTEGER NOT NULL DEFAULT 0 CHECK (cantidad_despachada >= 0),
  ADD COLUMN IF NOT EXISTS lote_id UUID REFERENCES public.lotes(id),
  ADD COLUMN IF NOT EXISTS cantidad_recibida INTEGER;

ALTER TABLE public.pedidos_abastecimiento_items
  DROP CONSTRAINT IF EXISTS pedido_cantidad_recibida_check;
ALTER TABLE public.pedidos_abastecimiento_items
  ADD CONSTRAINT pedido_cantidad_recibida_check CHECK (
    cantidad_recibida IS NULL OR
    (cantidad_recibida >= 0 AND cantidad_recibida <= cantidad_despachada)
  );

-- Un medicamento puede salir de varios lotes FEFO. Conserva cada despacho
-- original y su devolución sin reemplazar las cantidades emitidas.
CREATE TABLE IF NOT EXISTS public.pedido_abastecimiento_despachos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id UUID NOT NULL REFERENCES public.pedidos_abastecimiento_items(id),
  lote_id UUID NOT NULL REFERENCES public.lotes(id),
  cantidad INTEGER NOT NULL CHECK (cantidad > 0),
  cantidad_devuelta INTEGER NOT NULL DEFAULT 0 CHECK (cantidad_devuelta >= 0 AND cantidad_devuelta <= cantidad),
  UNIQUE (item_id, lote_id)
);
ALTER TABLE public.pedido_abastecimiento_despachos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lectura de despachos autenticados" ON public.pedido_abastecimiento_despachos;
CREATE POLICY "Lectura de despachos autenticados"
  ON public.pedido_abastecimiento_despachos FOR SELECT TO authenticated USING (true);
GRANT SELECT ON public.pedido_abastecimiento_despachos TO authenticated;

-- SECURITY DEFINER con search_path fijo: solo esta función escribe el detalle
-- por lotes; exige identidad real, perfil activo, rol y transición permitida.
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
  IF p_accion IN ('CANCELAR', 'RECIBIR') AND v_rol <> 'FARMACIA'
     OR p_accion IN ('TOMAR', 'RECHAZAR', 'DESPACHAR') AND v_rol <> 'ALMACEN' THEN
    RAISE EXCEPTION 'Su rol no puede realizar esta acción.';
  END IF;

  SELECT * INTO v_pedido FROM public.pedidos_abastecimiento WHERE id = p_pedido_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El pedido no existe.'; END IF;
  IF v_pedido.area_origen <> 'FARMACIA' OR v_pedido.area_destino <> 'ALMACEN' THEN
    RAISE EXCEPTION 'Esta operación solo admite pedidos de Farmacia a Almacén.';
  END IF;
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
        INSERT INTO public.inventario_stock(lote_id, area_codigo, cantidad)
          VALUES(v_stock.lote_id, 'FARMACIA', v_movimiento)
          ON CONFLICT (lote_id, area_codigo) DO UPDATE
          SET cantidad = public.inventario_stock.cantidad + EXCLUDED.cantidad, updated_at = now();
        INSERT INTO public.pedido_abastecimiento_despachos(item_id, lote_id, cantidad)
          VALUES(v_item.id, v_stock.lote_id, v_movimiento);
        INSERT INTO public.auditoria_trazabilidad(tipo_evento, entidad_referencia_id, tabla_referencia,
          usuario_id, medicamento_id, lote_id, area_origen, area_destino, cantidad, descripcion)
          VALUES('TRANSFERENCIA_FARMACIA', p_pedido_id, 'pedidos_abastecimiento', v_usuario,
            v_item.medicamento_id, v_stock.lote_id, 'ALMACEN', 'FARMACIA', v_movimiento, 'Despacho de pedido ' || v_pedido.codigo);
        v_restante := v_restante - v_movimiento;
      END LOOP;
      IF v_restante > 0 THEN RAISE EXCEPTION 'Stock disponible insuficiente. Actualice las cantidades antes de despachar.'; END IF;
      UPDATE public.pedidos_abastecimiento_items SET cantidad_despachada = v_cantidad WHERE id = v_item.id;
      v_total := v_total + v_cantidad;
    END LOOP;
    IF v_total = 0 THEN RAISE EXCEPTION 'No se puede despachar un pedido vacío. Utilice Rechazar Solicitud.'; END IF;
    v_nuevo := 'LISTO'; v_evento := 'DESPACHO_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo, modalidad_entrega = p_modalidad,
      confirmado_almacen = true, responsable_almacen_id = v_usuario,
      fecha_listo = now(), fecha_despacho = now(), fecha_confirmacion_almacen = now(),
      notas_almacen = NULLIF(btrim(p_notas), '') WHERE id = p_pedido_id;
  WHEN 'RECIBIR' THEN
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
    v_nuevo := 'COMPLETADO'; v_evento := 'RECEPCION_PEDIDO';
    UPDATE public.pedidos_abastecimiento SET estado = v_nuevo, confirmado_farmacia = true,
      responsable_farmacia_id = v_usuario, fecha_confirmacion_farmacia = now(), fecha_completado = now(),
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
NOTIFY pgrst, 'reload schema';
COMMIT;
