-- Canal FCM inicial. No modifica pedidos, fichas ni existencias.
begin;
create table public.dispositivos_push (
  instalacion_id uuid primary key,
  usuario_id uuid not null references public.profiles(id) on delete cascade,
  token text not null check (length(token) between 20 and 4096),
  activo boolean not null default true,
  actualizado_en timestamptz not null default now()
);
create unique index dispositivos_push_token on public.dispositivos_push(token);
alter table public.dispositivos_push enable row level security;
revoke all on public.dispositivos_push from anon, authenticated;
grant all on public.dispositivos_push to service_role;

create table public.notificaciones (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.profiles(id) on delete cascade,
  solicitud_id uuid not null,
  instalacion_id uuid not null,
  tipo text not null default 'PRUEBA' check(tipo = 'PRUEBA'),
  titulo text not null,
  mensaje text not null,
  origen text not null default 'SITRA-Luz · Comprobación',
  creado_en timestamptz not null default now(),
  leido_en timestamptz,
  envio_estado text not null default 'pendiente'
    check (envio_estado in ('pendiente','enviando','enviado','error')),
  intento_en timestamptz,
  unique(usuario_id, solicitud_id)
);
create index notificaciones_destinatario_fecha on public.notificaciones(usuario_id, creado_en desc, id desc);
alter table public.notificaciones enable row level security;
revoke all on public.notificaciones from anon, authenticated;
grant select on public.notificaciones to authenticated;
grant all on public.notificaciones to service_role;
create policy notificaciones_propias on public.notificaciones for select to authenticated
  using(usuario_id = auth.uid() and exists(select 1 from public.profiles p where p.id = auth.uid() and p.activo));

create function public.registrar_dispositivo_push(p_instalacion uuid, p_token text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not exists(select 1 from public.profiles where id=auth.uid() and activo) then
    raise exception 'Sesión activa requerida';
  end if;
  if p_instalacion is null or p_token is null or length(p_token) not between 20 and 4096 then
    raise exception 'Dispositivo no válido';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_token, 0));
  delete from public.dispositivos_push where token=p_token and instalacion_id<>p_instalacion;
  insert into public.dispositivos_push(instalacion_id,usuario_id,token)
    values(p_instalacion,auth.uid(),p_token)
    on conflict(instalacion_id) do update set usuario_id=auth.uid(),token=excluded.token,
      activo=true,actualizado_en=now();
end; $$;

create function public.desvincular_dispositivo_push(p_instalacion uuid)
returns void language sql security definer set search_path = public, pg_temp as $$
  delete from public.dispositivos_push where instalacion_id=p_instalacion and usuario_id=auth.uid();
$$;

create function public.leer_notificacion(p_id uuid)
returns void language sql security definer set search_path = public, pg_temp as $$
  update public.notificaciones set leido_en=coalesce(leido_en,now())
  where id=p_id and usuario_id=auth.uid()
    and exists(select 1 from public.profiles where id=auth.uid() and activo);
$$;

-- Solo Edge Function: serializa pruebas propias y limita a una por 30 segundos.
create function public.preparar_prueba_push(p_usuario uuid,p_instalacion uuid,p_solicitud uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare n public.notificaciones; t text;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_usuario::text,0));
  if not exists(select 1 from public.profiles where id=p_usuario and activo) then
    return jsonb_build_object('error','Usuario no disponible');
  end if;
  select token into t from public.dispositivos_push where instalacion_id=p_instalacion
    and usuario_id=p_usuario and activo;
  if t is null then return jsonb_build_object('error','Activa las notificaciones en este dispositivo'); end if;
  select * into n from public.notificaciones where usuario_id=p_usuario and solicitud_id=p_solicitud for update;
  if n.id is not null then
    if n.instalacion_id<>p_instalacion then return jsonb_build_object('error','Solicitud no válida'); end if;
    if n.envio_estado='enviado' then return jsonb_build_object('id',n.id,'estado','enviado'); end if;
    if n.envio_estado='enviando' and n.intento_en>now()-interval '90 seconds' then
      return jsonb_build_object('error','El envío sigue en proceso. Espera antes de reintentar');
    end if;
  end if;
  if exists(select 1 from public.notificaciones where usuario_id=p_usuario
    and intento_en>now()-interval '30 seconds') then
    return jsonb_build_object('error','Espera 30 segundos entre comprobaciones');
  end if;
  if n.id is null then
    insert into public.notificaciones(usuario_id,solicitud_id,instalacion_id,titulo,mensaje)
      values(p_usuario,p_solicitud,p_instalacion,'Tu conexión está lista',
      'Esta es una notificación de prueba de SITRA-Luz. No modifica pedidos ni existencias.') returning * into n;
  end if;
  update public.notificaciones set envio_estado='enviando',intento_en=now() where id=n.id;
  return jsonb_build_object('id',n.id,'token',t,'titulo',n.titulo,'mensaje',n.mensaje,'estado','enviando');
end; $$;

revoke all on function public.registrar_dispositivo_push(uuid,text) from public,anon;
revoke all on function public.desvincular_dispositivo_push(uuid) from public,anon;
revoke all on function public.leer_notificacion(uuid) from public,anon;
grant execute on function public.registrar_dispositivo_push(uuid,text) to authenticated;
grant execute on function public.desvincular_dispositivo_push(uuid) to authenticated;
grant execute on function public.leer_notificacion(uuid) to authenticated;
revoke all on function public.preparar_prueba_push(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.preparar_prueba_push(uuid,uuid,uuid) to service_role;
commit;
