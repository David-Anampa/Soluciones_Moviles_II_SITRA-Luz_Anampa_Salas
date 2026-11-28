begin;
create or replace function public.eliminar_registro_gestion_admin(p_entidad text,p_id uuid,p_version text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare tabla text; antes jsonb; estado jsonb; actor jsonb; nombre_actor text;
 nombre_registro text; tipo text; areas jsonb:='[]'; configuracion jsonb:='[]';
 resumen text; detalle jsonb; total_operativo bigint;
begin
 if public.sitra_rol_actual() is distinct from 'ADMINISTRADOR' then raise exception 'Solo Administración puede eliminar registros' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(12012,1);
 tabla:=case p_entidad when 'AREA' then 'areas' when 'FINANCIAMIENTO' then 'financiamientos' when 'PROFESIONAL' then 'doctores' when 'USUARIO' then 'profiles' end;
 if tabla is null then raise exception 'Tipo de registro inválido'; end if;
 if p_entidad='AREA' then lock table public.kits,public.dispensaciones in share mode; end if;
 if p_entidad='USUARIO' then perform 1 from auth.users where id=p_id for update; end if;
 execute format('select to_jsonb(t) from public.%I t where id=$1 for update',tabla) into antes using p_id;
 if antes is null then raise exception 'El registro ya no existe. Actualiza la lista'; end if;
 if (antes->>'updated_at')::timestamptz is distinct from p_version::timestamptz then raise exception 'El registro cambió. Actualiza y revisa los datos antes de eliminar'; end if;
 estado:=public.referencias_gestion_admin(p_entidad,p_id);
 if not (estado->>'puede_eliminar')::boolean then raise exception '%',estado->>'motivo'; end if;
 -- Auditar antes de borrar: se conserva identidad, instantánea y actor.
 select to_jsonb(p) into actor from public.profiles p where id=auth.uid();
 nombre_actor:=coalesce(nullif(btrim(actor->>'nombre'),''),nullif(btrim(concat_ws(' ',actor->>'nombres',actor->>'apellidos')),''),actor->>'email','Administrador');
 nombre_registro:=coalesce(nullif(btrim(antes->>'nombre'),''),nullif(btrim(concat_ws(' ',antes->>'nombres',antes->>'apellidos')),''),antes->>'email',p_id::text);
 tipo:=case p_entidad when 'USUARIO' then 'al usuario' when 'PROFESIONAL' then 'al profesional' when 'AREA' then 'el área' else case when antes->>'tipo'='SEGURO' then 'el seguro' else 'el convenio' end end;
 if p_entidad='PROFESIONAL' then
  select coalesce(jsonb_agg(jsonb_build_object('codigo',a.codigo,'nombre',a.nombre,'cantidad',1) order by a.nombre),'[]'::jsonb) into areas from public.doctor_areas da join public.areas a on a.codigo=da.area_codigo where da.doctor_id=p_id;
 elsif p_entidad='USUARIO' then
  select coalesce(jsonb_agg(jsonb_build_object('codigo',a.codigo,'nombre',a.nombre,'cantidad',1) order by a.nombre),'[]'::jsonb) into areas from public.areas a where exists(select 1 from public.profile_areas pa where pa.area_id=a.id and pa.profile_id=p_id)
   or exists(select 1 from jsonb_array_elements_text(case when jsonb_typeof(antes->'areas_asignadas')='array' then antes->'areas_asignadas' else '[]'::jsonb end) x where lower(btrim(x)) in(lower(a.codigo),lower(a.codigo_interno),lower(a.nombre)));
 elsif p_entidad='AREA' then
  areas:=jsonb_build_array(jsonb_build_object('codigo',antes->>'codigo','nombre',nombre_registro,'cantidad',0));
 elsif p_entidad='FINANCIAMIENTO' then
  configuracion:=jsonb_build_array(jsonb_build_object('tipo','Medicamentos de cobertura','cantidad',(select count(*) from public.financiamiento_medicamentos where financiamiento_id=p_id)));
 end if;
 if p_entidad in ('PROFESIONAL','USUARIO') then configuracion:=configuracion||jsonb_build_array(jsonb_build_object('tipo','Asignaciones de áreas','cantidad',jsonb_array_length(areas))); end if;
 select coalesce(sum((r->>'cantidad')::bigint),0) into total_operativo from jsonb_array_elements(estado->'relaciones') r;
 detalle:=jsonb_build_object(
  'accion','ELIMINAR','entidad',p_entidad,
  'administrador',jsonb_build_object('id',auth.uid(),'nombre',nombre_actor,'usuario',actor->>'usuario','correo',actor->>'email'),
  'registro',jsonb_build_object('id',p_id,'nombre',nombre_registro,'codigo',coalesce(antes->>'codigo_interno',antes->>'codigo'),'colegiatura',antes->>'numero_colegiatura'),
  'total_registros_operativos',total_operativo,'registros_por_tipo_y_area',estado->'relaciones',
  'areas_asignadas',areas,'configuracion_relacionada',configuracion,
  'auditoria_previa_conservada',estado->'auditoria_conservada');
 resumen:=format('%s eliminó %s «%s» (ID: %s). Registros operativos relacionados: %s. Áreas: %s. Configuración: %s. Auditoría previa conservada: %s registros.',
  nombre_actor,tipo,nombre_registro,p_id,total_operativo,
  coalesce((select string_agg(a->>'nombre',', ' order by a->>'nombre') from jsonb_array_elements(areas) a),'sin áreas asignadas'),
  coalesce((select string_agg((c->>'tipo')||': '||(c->>'cantidad'),'; ') from jsonb_array_elements(configuracion) c),'0 registros de configuración'),estado->>'auditoria_conservada');
 insert into public.auditoria_trazabilidad(tipo_evento,entidad_referencia_id,tabla_referencia,usuario_id,estado_anterior,estado_nuevo,descripcion,detalles_extra)
 values('GESTION_ELIMINAR',p_id,tabla,auth.uid(),antes,estado,resumen,detalle);
 if p_entidad='USUARIO' then
  delete from auth.users where id=p_id;
  if exists(select 1 from public.profiles where id=p_id) then raise exception 'No se confirmó la eliminación de la cuenta y su perfil'; end if;
 elsif p_entidad='PROFESIONAL' then
  delete from public.doctor_areas where doctor_id=p_id;
  delete from public.doctores where id=p_id;
 elsif p_entidad='AREA' or p_entidad='FINANCIAMIENTO' then
  perform public.administrar_catalogo_hu012(p_entidad,'ELIMINAR',p_id);
 end if;
end; $$;
revoke all on function public.eliminar_registro_gestion_admin(text,uuid,text) from public,anon;
grant execute on function public.eliminar_registro_gestion_admin(text,uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
