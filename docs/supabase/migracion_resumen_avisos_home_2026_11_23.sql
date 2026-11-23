BEGIN;
-- Resumen completo: no depende de la paginación ni devuelve datos de pacientes.
CREATE OR REPLACE FUNCTION public.resumen_avisos_home(p_ambito TEXT)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_rol TEXT; v_resultado JSONB;
BEGIN
  SELECT rol INTO v_rol FROM public.profiles WHERE id=auth.uid() AND activo;
  IF v_rol IS NULL OR p_ambito NOT IN ('ALMACEN','FARMACIA','ENFERMERIA') OR p_ambito IS NULL
     OR (v_rol<>'ADMINISTRADOR' AND v_rol<>p_ambito) THEN
    RAISE EXCEPTION 'Sin permiso para consultar estos pendientes.' USING ERRCODE='42501';
  END IF;
  WITH pendientes AS (
    SELECT 'ABASTECIMIENTO'::TEXT AS tipo,p.area_origen AS area_codigo,
      COALESCE(a.nombre,p.area_origen) AS area_nombre,''::TEXT AS destino_nombre,
      false AS urgente,p.fecha_solicitud AS fecha
    FROM public.pedidos_abastecimiento p LEFT JOIN public.areas a ON a.codigo=p.area_origen
    WHERE p_ambito='ALMACEN' AND p.estado='PENDIENTE' AND p.area_destino='ALMACEN'
      AND p.iniciativa='SOLICITUD_FARMACIA'
    UNION ALL
    SELECT 'PEDIDO_CLINICO',d.area_origen,COALESCE(a.nombre,d.area_origen),'',d.prioridad='URGENTE',d.fecha_creacion
    FROM public.dispensaciones d LEFT JOIN public.areas a ON a.codigo=d.area_origen
    WHERE p_ambito='FARMACIA' AND d.estado='SOLICITADO'
    UNION ALL
    SELECT 'RECEPCION_ALMACEN','ALMACEN',COALESCE(a.nombre,'Almacén General'),'',false,p.fecha_listo
    FROM public.pedidos_abastecimiento p LEFT JOIN public.areas a ON a.codigo='ALMACEN'
    WHERE p_ambito='FARMACIA' AND p.estado='LISTO' AND NOT COALESCE(p.confirmado_farmacia,false)
      AND (p.area_origen='FARMACIA' OR p.area_destino='FARMACIA')
    UNION ALL
    SELECT 'RECOJO',d.area_origen,COALESCE(f.nombre,'Farmacia Central'),COALESCE(a.nombre,d.area_origen),d.prioridad='URGENTE',d.fecha_listo_recojo
    FROM public.dispensaciones d LEFT JOIN public.areas a ON a.codigo=d.area_origen
    LEFT JOIN public.areas f ON f.codigo='FARMACIA'
    WHERE p_ambito='ENFERMERIA' AND d.estado='LISTO_PARA_RECOJO'
      AND (public.sitra_usuario_tiene_area(d.area_origen) OR d.solicitado_por=auth.uid() OR v_rol='ADMINISTRADOR')
  ), grupos AS (
    SELECT tipo,area_codigo,area_nombre,destino_nombre,count(*) AS cantidad,
      count(*) FILTER(WHERE urgente) AS urgentes,max(fecha) AS ultima_fecha
    FROM pendientes GROUP BY tipo,area_codigo,area_nombre,destino_nombre
  )
  SELECT jsonb_build_object('total',COALESCE(sum(cantidad),0),
    'grupos',COALESCE(jsonb_agg(to_jsonb(grupos) ORDER BY urgentes DESC,cantidad DESC,area_nombre),'[]'::JSONB),
    'consultado_en',now()) INTO v_resultado FROM grupos;
  RETURN v_resultado;
END;
$$;
REVOKE ALL ON FUNCTION public.resumen_avisos_home(TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.resumen_avisos_home(TEXT) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
