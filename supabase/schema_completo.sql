-- ================================================================
-- CondoGest — Schema Completo Supabase
-- ProIntegra Serviços · CNPJ 31.495.586/0001-36
-- Execute este arquivo inteiro no SQL Editor do Supabase
-- ================================================================

-- 1. EXTENSÕES
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ================================================================
-- 2. TABELAS
-- ================================================================

-- Empresas
create table if not exists public.empresas (
  id         uuid primary key default uuid_generate_v4(),
  nome       text not null,
  cnpj       text unique,
  ativo      boolean default true,
  criado_em  timestamptz default now()
);

-- Condomínios
create table if not exists public.condominios (
  id          uuid primary key default uuid_generate_v4(),
  empresa_id  uuid references public.empresas(id) on delete cascade,
  nome        text not null,
  endereco    text,
  cidade      text,
  estado      text default 'SP',
  ativo       boolean default true,
  criado_em   timestamptz default now()
);

-- Perfis de usuário (espelho do auth.users)
create table if not exists public.perfis (
  id              uuid primary key references auth.users(id) on delete cascade,
  condominio_id   uuid references public.condominios(id),
  empresa_id      uuid references public.empresas(id),
  nome            text not null,
  cargo           text,
  perfil          text check (perfil in ('fiscal','admin','superadmin')) default 'fiscal',
  foto_url        text,
  lgpd_aceito     boolean default false,
  lgpd_aceito_em  timestamptz,
  ativo           boolean default true,
  criado_em       timestamptz default now(),
  atualizado_em   timestamptz default now()
);

-- Áreas dinâmicas por condomínio
create table if not exists public.areas (
  id              uuid primary key default uuid_generate_v4(),
  condominio_id   uuid references public.condominios(id) on delete cascade,
  categoria       text check (categoria in ('corredores','estacionamento','lojas','limpeza')) not null,
  nome            text not null,
  ativo           boolean default true,
  ordem           int default 0,
  criado_em       timestamptz default now()
);

-- Rondas (sessão de verificação)
create table if not exists public.rondas (
  id              uuid primary key default uuid_generate_v4(),
  condominio_id   uuid references public.condominios(id) on delete cascade,
  fiscal_id       uuid references public.perfis(id),
  tipo            text check (tipo in ('HORARIA','DIARIA','SEMANAL','MENSAL')) not null,
  iniciada_em     timestamptz default now(),
  finalizada_em   timestamptz,
  status          text check (status in ('em_andamento','concluida','incompleta')) default 'em_andamento',
  total_itens     int default 0,
  itens_ok        int default 0,
  itens_nok       int default 0
);

-- Registros de checklist (OK/NOK por item)
create table if not exists public.registros (
  id              uuid primary key default uuid_generate_v4(),
  ronda_id        uuid references public.rondas(id) on delete set null,
  condominio_id   uuid references public.condominios(id) on delete cascade,
  fiscal_id       uuid references public.perfis(id),
  categoria       text not null,
  area_id         uuid references public.areas(id) on delete set null,
  item_id         text not null,
  item_label      text,
  status          text check (status in ('ok','nok')) not null,
  foto_url        text,
  audio_url       text,
  lat             double precision,
  lng             double precision,
  precisao        double precision,
  endereco        text,
  link_mapa       text,
  token           text,
  observacao      text,
  criado_em       timestamptz default now()
);

-- Ponto eletrônico
create table if not exists public.pontos (
  id              uuid primary key default uuid_generate_v4(),
  condominio_id   uuid references public.condominios(id) on delete cascade,
  fiscal_id       uuid references public.perfis(id),
  tipo            text check (tipo in ('ENTRADA','SAIDA','INICIO_INTERVALO','FIM_INTERVALO')) not null,
  selfie_url      text,
  lat             double precision,
  lng             double precision,
  precisao        double precision,
  endereco        text,
  link_mapa       text,
  sincronizado    boolean default true,
  registrado_em   timestamptz default now()
);

-- Inconformidades avulsas
create table if not exists public.inconformidades (
  id              uuid primary key default uuid_generate_v4(),
  condominio_id   uuid references public.condominios(id) on delete cascade,
  fiscal_id       uuid references public.perfis(id),
  descricao       text,
  foto_url        text,
  audio_url       text,
  lat             double precision,
  lng             double precision,
  precisao        double precision,
  endereco        text,
  link_mapa       text,
  resolvida       boolean default false,
  resolvida_em    timestamptz,
  resolvida_por   uuid references public.perfis(id),
  criado_em       timestamptz default now()
);

-- Log LGPD (auditoria de consentimentos)
create table if not exists public.lgpd_log (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid references auth.users(id),
  email       text,
  acao        text check (acao in ('aceite','revogacao','acesso','exclusao')) not null,
  ip          text,
  user_agent  text,
  detalhes    jsonb,
  criado_em   timestamptz default now()
);

-- ================================================================
-- 3. ÍNDICES
-- ================================================================

create index if not exists idx_registros_condominio   on public.registros(condominio_id);
create index if not exists idx_registros_ronda        on public.registros(ronda_id);
create index if not exists idx_registros_fiscal       on public.registros(fiscal_id);
create index if not exists idx_registros_criado_em    on public.registros(criado_em desc);
create index if not exists idx_pontos_condominio      on public.pontos(condominio_id);
create index if not exists idx_pontos_fiscal          on public.pontos(fiscal_id);
create index if not exists idx_pontos_registrado_em   on public.pontos(registrado_em desc);
create index if not exists idx_rondas_condominio      on public.rondas(condominio_id);
create index if not exists idx_areas_condominio       on public.areas(condominio_id);
create index if not exists idx_lgpd_user              on public.lgpd_log(user_id);

-- ================================================================
-- 4. ROW LEVEL SECURITY
-- ================================================================

alter table public.empresas        enable row level security;
alter table public.condominios     enable row level security;
alter table public.perfis          enable row level security;
alter table public.areas           enable row level security;
alter table public.rondas          enable row level security;
alter table public.registros       enable row level security;
alter table public.pontos          enable row level security;
alter table public.inconformidades enable row level security;
alter table public.lgpd_log        enable row level security;

-- ── Funções auxiliares de RLS ────────────────────────────────────

create or replace function public.meu_condominio_id()
returns uuid language sql security definer stable as $$
  select condominio_id from public.perfis where id = auth.uid()
$$;

create or replace function public.meu_perfil()
returns text language sql security definer stable as $$
  select perfil from public.perfis where id = auth.uid()
$$;

-- ── Policies ─────────────────────────────────────────────────────

-- Registros: fiscal vê só seu condomínio
create policy "registros_por_condominio" on public.registros
  for all using (condominio_id = meu_condominio_id());

-- Pontos: fiscal vê só seu condomínio
create policy "pontos_por_condominio" on public.pontos
  for all using (condominio_id = meu_condominio_id());

-- Áreas: qualquer usuário do condomínio pode ler/escrever
create policy "areas_por_condominio" on public.areas
  for all using (condominio_id = meu_condominio_id());

-- Rondas: condomínio
create policy "rondas_por_condominio" on public.rondas
  for all using (condominio_id = meu_condominio_id());

-- Inconformidades: condomínio
create policy "inconformidades_por_condominio" on public.inconformidades
  for all using (condominio_id = meu_condominio_id());

-- Perfis: usuário vê o próprio; admin vê todos do condomínio
create policy "perfil_proprio" on public.perfis
  for select using (
    id = auth.uid()
    or (meu_perfil() in ('admin','superadmin') and condominio_id = meu_condominio_id())
  );

create policy "perfil_update_proprio" on public.perfis
  for update using (id = auth.uid());

-- Condomínios: usuário vê o próprio
create policy "condominio_proprio" on public.condominios
  for select using (id = meu_condominio_id());

-- Empresas: superadmin vê tudo
create policy "empresas_superadmin" on public.empresas
  for all using (meu_perfil() = 'superadmin');

-- LGPD log: usuário vê o próprio; admin vê todos
create policy "lgpd_log_proprio" on public.lgpd_log
  for select using (
    user_id = auth.uid()
    or meu_perfil() in ('admin','superadmin')
  );
create policy "lgpd_log_insert" on public.lgpd_log
  for insert with check (user_id = auth.uid() or user_id is null);

-- ================================================================
-- 5. TRIGGER: atualiza perfil.atualizado_em
-- ================================================================

create or replace function public.fn_atualizado_em()
returns trigger language plpgsql as $$
begin
  new.atualizado_em = now();
  return new;
end;
$$;

create trigger tg_perfis_atualizado_em
  before update on public.perfis
  for each row execute function public.fn_atualizado_em();

-- ================================================================
-- 6. DADOS INICIAIS
-- ================================================================

-- Empresa ProIntegra
insert into public.empresas (id, nome, cnpj) values
  ('00000000-0000-0000-0000-000000000001', 'ProIntegra Serviços', '31.495.586/0001-36')
on conflict (cnpj) do nothing;

-- Condomínio padrão de demonstração
insert into public.condominios (id, empresa_id, nome, endereco, cidade) values
  ('00000000-0000-0000-0000-000000000010',
   '00000000-0000-0000-0000-000000000001',
   'Centro Comercial ProIntegra',
   'Rua das Flores, 100 — Centro',
   'São Paulo')
on conflict (id) do nothing;

-- Áreas padrão
insert into public.areas (condominio_id, categoria, nome, ordem) values
  ('00000000-0000-0000-0000-000000000010','corredores','Corredor Térreo',1),
  ('00000000-0000-0000-0000-000000000010','corredores','Corredor 1º Andar',2),
  ('00000000-0000-0000-0000-000000000010','corredores','Corredor 2º Andar',3),
  ('00000000-0000-0000-0000-000000000010','estacionamento','Setor A',1),
  ('00000000-0000-0000-0000-000000000010','estacionamento','Setor B',2),
  ('00000000-0000-0000-0000-000000000010','lojas','Loja 01',1),
  ('00000000-0000-0000-0000-000000000010','lojas','Loja 02',2),
  ('00000000-0000-0000-0000-000000000010','lojas','Loja 03',3),
  ('00000000-0000-0000-0000-000000000010','limpeza','Área Externa',1),
  ('00000000-0000-0000-0000-000000000010','limpeza','Área Interna',2)
on conflict do nothing;

-- ================================================================
-- 7. STORAGE BUCKETS (execute via Dashboard → Storage)
-- ================================================================
-- Criar manualmente no dashboard do Supabase:
-- 1. Bucket: "fotos-ronda"   → Private, max 5MB
-- 2. Bucket: "selfies-ponto" → Private, max 3MB
-- 3. Bucket: "audios-ronda"  → Private, max 10MB
--
-- Policy para cada bucket (no SQL Editor):
/*
create policy "bucket_fotos_autenticado"
  on storage.objects for all
  using (bucket_id = 'fotos-ronda' and auth.role() = 'authenticated');

create policy "bucket_selfies_autenticado"
  on storage.objects for all
  using (bucket_id = 'selfies-ponto' and auth.role() = 'authenticated');

create policy "bucket_audios_autenticado"
  on storage.objects for all
  using (bucket_id = 'audios-ronda' and auth.role() = 'authenticated');
*/

-- ================================================================
-- 8. CRIAR USUÁRIOS (após executar este schema)
-- ================================================================
-- Passo 1: No Dashboard → Authentication → Users → Invite user
--   iran@prointegraserv.com.br     (senha: iran2025)
--   ronda@prointegraserv.com.br    (senha: ronda2025)
--   limpeza@prointegraserv.com.br  (senha: limpeza2025)
--   sindico@prointegraserv.com.br  (senha: sindico2025)
--   administradora@prointegraserv.com.br (senha: admin2025)
--
-- Passo 2: Após criação, rode o INSERT abaixo substituindo os UUIDs:
/*
insert into public.perfis (id, condominio_id, empresa_id, nome, cargo, perfil) values
  ('<uuid-iran>',           '00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', 'Iran Feliciano',  'Gestor de Segurança',  'superadmin'),
  ('<uuid-ronda>',          '00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', 'Fiscal de Piso',  'Fiscal de Piso',        'fiscal'),
  ('<uuid-limpeza>',        '00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', 'ASG Limpeza',     'Agente de Limpeza',     'fiscal'),
  ('<uuid-sindico>',        '00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', 'Síndico',         'Síndico',               'admin'),
  ('<uuid-administradora>', '00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', 'Administradora',  'Administradora',        'admin');
*/

-- FIM DO SCHEMA ===================================================
