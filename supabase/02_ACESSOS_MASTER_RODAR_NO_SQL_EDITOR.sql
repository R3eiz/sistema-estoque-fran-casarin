-- Acessos do sistema: Master, Administrador e Visualizador.
-- Rode este arquivo no SQL Editor do Supabase.

create extension if not exists pgcrypto;

alter table public.perfis drop constraint if exists perfis_papel_check;

update public.perfis
set papel = case
  when email = 'buffet@master.com' then 'master'
  when papel in ('admin', 'estoque') then 'administrador'
  when papel = 'consulta' then 'visualizador'
  else papel
end;

alter table public.perfis
  alter column papel set default 'visualizador',
  add constraint perfis_papel_check check (papel in ('master', 'administrador', 'visualizador'));

create or replace function public.usuario_tem_papel(papeis text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.perfis p
    where p.user_id = auth.uid()
      and p.ativo = true
      and p.papel = any(papeis)
  );
$$;

create or replace function public.criar_perfil_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfis(user_id, email, nome, papel)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', new.email),
    case
      when not exists (select 1 from public.perfis) then 'master'
      else 'visualizador'
    end
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create or replace function public.criar_usuario_sistema(
  p_email text,
  p_senha text,
  p_nome text default null,
  p_papel text default 'visualizador'
)
returns public.perfis
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text := lower(trim(p_email));
  v_user_id uuid;
  v_perfil public.perfis;
  v_identity_id_type text;
begin
  if not public.usuario_tem_papel(array['master']) then
    raise exception 'Somente Master pode criar acessos.';
  end if;

  if p_papel not in ('administrador', 'visualizador') then
    raise exception 'Papel inválido.';
  end if;

  if length(coalesce(p_senha, '')) < 6 then
    raise exception 'A senha precisa ter ao menos 6 caracteres.';
  end if;

  select id into v_user_id from auth.users where lower(email) = v_email limit 1;

  if v_user_id is null then
    v_user_id := gen_random_uuid();

    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, email_change,
      email_change_token_new, recovery_token
    )
    values (
      v_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      v_email, crypt(p_senha, gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('name', coalesce(nullif(trim(p_nome), ''), v_email)),
      now(), now(), '', '', '', ''
    );

    select data_type into v_identity_id_type
    from information_schema.columns
    where table_schema = 'auth' and table_name = 'identities' and column_name = 'id';

    if v_identity_id_type = 'uuid' then
      insert into auth.identities (
        id, user_id, provider_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      )
      values (
        v_user_id, v_user_id, v_email,
        jsonb_build_object('sub', v_user_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
        'email', now(), now(), now()
      );
    else
      insert into auth.identities (
        id, user_id, provider_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      )
      values (
        v_user_id::text, v_user_id, v_email,
        jsonb_build_object('sub', v_user_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
        'email', now(), now(), now()
      );
    end if;
  else
    update auth.users
    set encrypted_password = crypt(p_senha, gen_salt('bf')),
        email_confirmed_at = coalesce(email_confirmed_at, now()),
        raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('name', coalesce(nullif(trim(p_nome), ''), v_email)),
        updated_at = now()
    where id = v_user_id;
  end if;

  insert into public.perfis(user_id, email, nome, papel, ativo)
  values (v_user_id, v_email, coalesce(nullif(trim(p_nome), ''), v_email), p_papel, true)
  on conflict (user_id) do update
    set email = excluded.email,
        nome = excluded.nome,
        papel = excluded.papel,
        ativo = true,
        atualizado_em = now()
  returning * into v_perfil;

  return v_perfil;
end;
$$;

grant execute on function public.criar_usuario_sistema(text, text, text, text) to authenticated;

create or replace view public.v_auditoria_detalhada as
select
  a.id,
  a.criado_em,
  a.tabela,
  a.registro_id,
  a.operacao,
  a.usuario_id,
  coalesce(p.email, u.email, 'Sistema') as email,
  coalesce(p.papel, 'sistema') as papel
from public.auditoria a
left join public.perfis p on p.user_id = a.usuario_id
left join auth.users u on u.id = a.usuario_id;

drop policy if exists "perfis_select_proprio_ou_admin" on public.perfis;
drop policy if exists "perfis_admin_write" on public.perfis;
drop policy if exists "perfis_select_master_ou_proprio" on public.perfis;
drop policy if exists "perfis_master_write" on public.perfis;

create policy "perfis_select_master_ou_proprio" on public.perfis
for select to authenticated
using (user_id = auth.uid() or public.usuario_tem_papel(array['master']));

create policy "perfis_master_write" on public.perfis
for all to authenticated
using (public.usuario_tem_papel(array['master']))
with check (public.usuario_tem_papel(array['master']));

drop policy if exists "auditoria_admin_select" on public.auditoria;
drop policy if exists "auditoria_master_select" on public.auditoria;

create policy "auditoria_master_select" on public.auditoria
for select to authenticated
using (public.usuario_tem_papel(array['master']));

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'categorias','locais','produtos_brutos','produtos_fracionados',
    'entradas_central','saidas_central','producoes','saidas_fracionado',
    'ajustes_estoque','pedidos_compra','itens_manuais_compra'
  ]
  loop
    execute format('drop policy if exists "%s_select_auth" on public.%I', tbl, tbl);
    execute format('drop policy if exists "%s_write_admin_estoque" on public.%I', tbl, tbl);
    execute format('drop policy if exists "%s_select_roles" on public.%I', tbl, tbl);
    execute format('drop policy if exists "%s_write_master_admin" on public.%I', tbl, tbl);
    execute format('create policy "%s_select_roles" on public.%I for select to authenticated using (public.usuario_tem_papel(array[''master'',''administrador'',''visualizador'']))', tbl, tbl);
    execute format('create policy "%s_write_master_admin" on public.%I for all to authenticated using (public.usuario_tem_papel(array[''master'',''administrador''])) with check (public.usuario_tem_papel(array[''master'',''administrador'']))', tbl, tbl);
  end loop;
end $$;

select email, papel, ativo from public.perfis order by criado_em;
