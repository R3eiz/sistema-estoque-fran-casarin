-- Sistema de Estoque Fran Casarin
-- Schema inicial para Supabase/Postgres com auth, RLS, auditoria e saldos calculados.

create extension if not exists pgcrypto;

create table if not exists public.perfis (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nome text,
  email text,
  papel text not null default 'consulta' check (papel in ('admin', 'estoque', 'consulta')),
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.categorias (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.locais (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  tipo text not null check (tipo in ('Central', 'Consumidor', 'Fracionamento')),
  responsavel text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.produtos_brutos (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  categoria_id uuid references public.categorias(id) on delete set null,
  unidade text not null default 'UN',
  estoque_minimo numeric(14,3) not null default 0 check (estoque_minimo >= 0),
  fornecedor text,
  preco_medio numeric(14,4) not null default 0 check (preco_medio >= 0),
  validade_dias integer not null default 0 check (validade_dias >= 0),
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.produtos_fracionados (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  categoria_id uuid references public.categorias(id) on delete set null,
  unidade text not null default 'UN',
  origem_bruto_id uuid references public.produtos_brutos(id) on delete restrict,
  rendimento_percent numeric(8,3) not null default 100 check (rendimento_percent > 0),
  estoque_minimo numeric(14,3) not null default 0 check (estoque_minimo >= 0),
  validade_dias integer not null default 0 check (validade_dias >= 0),
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.entradas_central (
  id uuid primary key default gen_random_uuid(),
  data date not null default current_date,
  nf text,
  produto_bruto_id uuid not null references public.produtos_brutos(id) on delete restrict,
  fornecedor text,
  quantidade numeric(14,3) not null check (quantidade > 0),
  preco_unitario numeric(14,4) not null default 0 check (preco_unitario >= 0),
  validade date,
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.saidas_central (
  id uuid primary key default gen_random_uuid(),
  data date not null default current_date,
  documento text,
  produto_bruto_id uuid not null references public.produtos_brutos(id) on delete restrict,
  destino_local_id uuid not null references public.locais(id) on delete restrict,
  quantidade numeric(14,3) not null check (quantidade > 0),
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.producoes (
  id uuid primary key default gen_random_uuid(),
  data date not null default current_date,
  produto_bruto_id uuid not null references public.produtos_brutos(id) on delete restrict,
  quantidade_utilizada numeric(14,3) not null check (quantidade_utilizada > 0),
  produto_fracionado_id uuid not null references public.produtos_fracionados(id) on delete restrict,
  quantidade_produzida numeric(14,3) not null check (quantidade_produzida > 0),
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.saidas_fracionado (
  id uuid primary key default gen_random_uuid(),
  data date not null default current_date,
  documento text,
  produto_fracionado_id uuid not null references public.produtos_fracionados(id) on delete restrict,
  destino_local_id uuid not null references public.locais(id) on delete restrict,
  quantidade numeric(14,3) not null check (quantidade > 0),
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.ajustes_estoque (
  id uuid primary key default gen_random_uuid(),
  data date not null default current_date,
  produto_bruto_id uuid not null references public.produtos_brutos(id) on delete restrict,
  saldo_anterior numeric(14,3) not null default 0,
  novo_saldo numeric(14,3) not null check (novo_saldo >= 0),
  diferenca numeric(14,3) not null,
  motivo text not null,
  responsavel text not null,
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.pedidos_compra (
  id uuid primary key default gen_random_uuid(),
  data date not null default current_date,
  produto_bruto_id uuid not null references public.produtos_brutos(id) on delete restrict,
  fornecedor text,
  quantidade_pedida numeric(14,3) not null check (quantidade_pedida > 0),
  preco_estimado numeric(14,4) not null default 0 check (preco_estimado >= 0),
  status text not null default 'pendente' check (status in ('pendente', 'recebido', 'cancelado')),
  data_recebimento date,
  quantidade_recebida numeric(14,3),
  preco_recebido numeric(14,4),
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table if not exists public.itens_manuais_compra (
  id uuid primary key default gen_random_uuid(),
  produto_bruto_id uuid not null references public.produtos_brutos(id) on delete cascade,
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  unique (produto_bruto_id)
);

create table if not exists public.auditoria (
  id bigint generated always as identity primary key,
  tabela text not null,
  registro_id uuid,
  operacao text not null check (operacao in ('INSERT', 'UPDATE', 'DELETE')),
  dados_anteriores jsonb,
  dados_novos jsonb,
  usuario_id uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now()
);

create or replace function public.set_atualizado_em()
returns trigger
language plpgsql
as $$
begin
  new.atualizado_em = now();
  return new;
end;
$$;

create or replace function public.registrar_auditoria()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  row_id uuid;
begin
  row_id := coalesce(new.id, old.id);
  insert into public.auditoria(tabela, registro_id, operacao, dados_anteriores, dados_novos, usuario_id)
  values (tg_table_name, row_id, tg_op, to_jsonb(old), to_jsonb(new), auth.uid());
  return coalesce(new, old);
end;
$$;

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
      when not exists (select 1 from public.perfis) then 'admin'
      else 'consulta'
    end
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_criar_perfil on auth.users;
create trigger on_auth_user_created_criar_perfil
after insert on auth.users
for each row execute function public.criar_perfil_usuario();

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'perfis','categorias','locais','produtos_brutos','produtos_fracionados',
    'entradas_central','saidas_central','producoes','saidas_fracionado',
    'ajustes_estoque','pedidos_compra','itens_manuais_compra'
  ]
  loop
    execute format('drop trigger if exists set_%s_atualizado_em on public.%I', tbl, tbl);
    if tbl <> 'itens_manuais_compra' then
      execute format('create trigger set_%s_atualizado_em before update on public.%I for each row execute function public.set_atualizado_em()', tbl, tbl);
    end if;
  end loop;
end $$;

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
    execute format('drop trigger if exists auditar_%s on public.%I', tbl, tbl);
    execute format('create trigger auditar_%s after insert or update or delete on public.%I for each row execute function public.registrar_auditoria()', tbl, tbl);
  end loop;
end $$;

create or replace view public.v_saldo_central_brutos as
select
  pb.id as produto_bruto_id,
  pb.nome,
  coalesce((select sum(e.quantidade) from public.entradas_central e where e.produto_bruto_id = pb.id), 0)
  - coalesce((select sum(s.quantidade) from public.saidas_central s where s.produto_bruto_id = pb.id), 0)
  + coalesce((select sum(a.diferenca) from public.ajustes_estoque a where a.produto_bruto_id = pb.id), 0) as saldo
from public.produtos_brutos pb;

create or replace view public.v_saldo_cozinha_brutos as
select
  pb.id as produto_bruto_id,
  pb.nome,
  coalesce((
    select sum(s.quantidade)
    from public.saidas_central s
    join public.locais l on l.id = s.destino_local_id
    where s.produto_bruto_id = pb.id and l.tipo = 'Fracionamento'
  ), 0)
  - coalesce((select sum(p.quantidade_utilizada) from public.producoes p where p.produto_bruto_id = pb.id), 0) as saldo
from public.produtos_brutos pb;

create or replace view public.v_saldo_cozinha_fracionados as
select
  pf.id as produto_fracionado_id,
  pf.nome,
  coalesce((select sum(p.quantidade_produzida) from public.producoes p where p.produto_fracionado_id = pf.id), 0)
  - coalesce((select sum(s.quantidade) from public.saidas_fracionado s where s.produto_fracionado_id = pf.id), 0) as saldo
from public.produtos_fracionados pf;

create index if not exists idx_produtos_brutos_nome on public.produtos_brutos(nome);
create index if not exists idx_produtos_fracionados_nome on public.produtos_fracionados(nome);
create index if not exists idx_entradas_central_data on public.entradas_central(data);
create index if not exists idx_saidas_central_data on public.saidas_central(data);
create index if not exists idx_producoes_data on public.producoes(data);
create index if not exists idx_saidas_fracionado_data on public.saidas_fracionado(data);
create index if not exists idx_ajustes_estoque_data on public.ajustes_estoque(data);
create index if not exists idx_pedidos_compra_status on public.pedidos_compra(status);

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'categorias','locais','produtos_brutos','produtos_fracionados',
    'entradas_central','saidas_central','producoes','saidas_fracionado',
    'ajustes_estoque','pedidos_compra'
  ]
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', tbl);
    exception when duplicate_object then
      null;
    end;
  end loop;
end $$;

alter table public.perfis enable row level security;
alter table public.categorias enable row level security;
alter table public.locais enable row level security;
alter table public.produtos_brutos enable row level security;
alter table public.produtos_fracionados enable row level security;
alter table public.entradas_central enable row level security;
alter table public.saidas_central enable row level security;
alter table public.producoes enable row level security;
alter table public.saidas_fracionado enable row level security;
alter table public.ajustes_estoque enable row level security;
alter table public.pedidos_compra enable row level security;
alter table public.itens_manuais_compra enable row level security;
alter table public.auditoria enable row level security;

drop policy if exists "perfis_select_proprio_ou_admin" on public.perfis;
create policy "perfis_select_proprio_ou_admin" on public.perfis
for select to authenticated
using (user_id = auth.uid() or public.usuario_tem_papel(array['admin']));

drop policy if exists "perfis_admin_write" on public.perfis;
create policy "perfis_admin_write" on public.perfis
for all to authenticated
using (public.usuario_tem_papel(array['admin']))
with check (public.usuario_tem_papel(array['admin']));

drop policy if exists "auditoria_admin_select" on public.auditoria;
create policy "auditoria_admin_select" on public.auditoria
for select to authenticated
using (public.usuario_tem_papel(array['admin']));

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
    execute format('create policy "%s_select_auth" on public.%I for select to authenticated using (public.usuario_tem_papel(array[''admin'',''estoque'',''consulta'']))', tbl, tbl);
    execute format('create policy "%s_write_admin_estoque" on public.%I for all to authenticated using (public.usuario_tem_papel(array[''admin'',''estoque''])) with check (public.usuario_tem_papel(array[''admin'',''estoque'']))', tbl, tbl);
  end loop;
end $$;
