-- PulsoBiz Monitor - migracao 002: multi-loja (cada cliente com a sua loja, dispositivo e login).
-- Rodar depois do 001_schema.sql. Tudo continua bloqueado ao publico (RLS sem policies):
-- so a Edge Function "data" (service role) acessa as tabelas.

create table if not exists public.lojas (
  id                uuid primary key default gen_random_uuid(),
  nome              text not null,
  device_token      text not null unique default gen_random_uuid()::text,
  dashboard_publico boolean not null default false,   -- true = loja de demonstracao (dashboard aberto)
  alert_emails      text,                              -- destinatarios dos alertas (separados por virgula)
  alert_sms         text,                              -- numeros dos SMS (separados por virgula)
  lotacao           integer not null default 0,
  meta_pendente     boolean not null default false,
  criado_em         timestamptz not null default now()
);
alter table public.lojas enable row level security;

-- Liga um login (Supabase Auth) a uma loja.
create table if not exists public.membros (
  user_id uuid not null references auth.users(id) on delete cascade,
  loja_id uuid not null references public.lojas(id) on delete cascade,
  primary key (user_id, loja_id)
);
alter table public.membros enable row level security;

-- Loja de demonstracao: herda o token do dispositivo atual (firmware e scripts continuam iguais).
insert into public.lojas (nome, device_token, dashboard_publico, lotacao, meta_pendente)
select 'Loja Demo PulsoBiz', c.value, true,
       coalesce((select value::int from public.config where key = 'lotacao'), 0),
       coalesce((select value = '1' from public.config where key = 'meta_pendente'), false)
from public.config c where c.key = 'device_token'
on conflict (device_token) do nothing;

alter table public.readings  add column if not exists loja_id uuid references public.lojas(id) on delete cascade;
alter table public.alert_log add column if not exists loja_id uuid references public.lojas(id) on delete cascade;
update public.readings  set loja_id = (select id from public.lojas where dashboard_publico limit 1) where loja_id is null;
update public.alert_log set loja_id = (select id from public.lojas where dashboard_publico limit 1) where loja_id is null;
alter table public.readings alter column loja_id set not null;
create index if not exists readings_loja_var_time_idx on public.readings (loja_id, variable, created_at desc);
create index if not exists alert_log_loja_kind_idx on public.alert_log (loja_id, kind, sent_at desc);

-- Consultas do dashboard, agora por loja.
drop function if exists public.series_avg(text, timestamptz, interval);
drop function if exists public.hourly_counts(timestamptz);
drop function if exists public.latest_values();

create or replace function public.series_avg(p_loja uuid, p_variable text, p_since timestamptz, p_bin interval)
returns table (t timestamptz, v double precision)
language sql stable set search_path = public as $$
  select date_bin(least(p_bin, interval '1 minute'), created_at, timestamptz 'epoch') as t, avg(num) as v
  from public.readings
  where loja_id = p_loja and variable = p_variable and created_at >= p_since and num is not null
  group by 1 order by 1
$$;

create or replace function public.hourly_counts(p_loja uuid, p_since timestamptz)
returns table (h timestamptz, n bigint)
language sql stable set search_path = public as $$
  select date_trunc('hour', created_at) as h, count(*) as n
  from public.readings
  where loja_id = p_loja and variable = 'movimento' and num = 1 and created_at >= p_since
  group by 1 order by 1
$$;

create or replace function public.latest_values(p_loja uuid)
returns table (variable text, num double precision, value text, unit text, created_at timestamptz)
language sql stable set search_path = public as $$
  select distinct on (variable) variable, num, value, unit, created_at
  from public.readings where loja_id = p_loja order by variable, created_at desc
$$;

revoke all on function public.series_avg(uuid, text, timestamptz, interval) from public, anon, authenticated;
revoke all on function public.hourly_counts(uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.latest_values(uuid) from public, anon, authenticated;
grant execute on function public.series_avg(uuid, text, timestamptz, interval) to service_role;
grant execute on function public.hourly_counts(uuid, timestamptz) to service_role;
grant execute on function public.latest_values(uuid) to service_role;
