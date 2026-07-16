-- Logs resumidos para a tela "Usuarios e Logs".
-- Mantem um registro legivel por salvamento do sistema.

create table if not exists public.logs_sistema (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  usuario_id uuid not null default auth.uid(),
  email text,
  papel text,
  resumo text not null,
  detalhes jsonb not null default '[]'::jsonb
);

create or replace function public.preencher_log_sistema()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  select coalesce(p.email, u.email), coalesce(p.papel, 'sistema')
    into new.email, new.papel
  from auth.users u
  left join public.perfis p on p.user_id = u.id
  where u.id = new.usuario_id;

  new.email := coalesce(new.email, 'Sistema');
  new.papel := coalesce(new.papel, 'sistema');
  return new;
end;
$$;

drop trigger if exists preencher_log_sistema on public.logs_sistema;
create trigger preencher_log_sistema
before insert on public.logs_sistema
for each row execute function public.preencher_log_sistema();

alter table public.logs_sistema enable row level security;

drop policy if exists "logs_sistema_select_master" on public.logs_sistema;
drop policy if exists "logs_sistema_insert_master_admin" on public.logs_sistema;

create policy "logs_sistema_select_master" on public.logs_sistema
for select to authenticated
using (public.usuario_tem_papel(array['master']));

create policy "logs_sistema_insert_master_admin" on public.logs_sistema
for insert to authenticated
with check (
  usuario_id = auth.uid()
  and public.usuario_tem_papel(array['master','administrador'])
);
