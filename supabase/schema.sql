-- ============================================================
-- CondoGest — Schema Supabase
-- ProIntegra Serviços · CNPJ 31.495.586/0001-36
-- ============================================================

-- Enable UUID
create extension if not exists "uuid-ossp";

-- ── TABELAS BASE ──────────────────────────────────────────

-- Empresas (ProIntegra e seus clientes)
create table public.empresas (
  id          uuid primary key default uuid_generate_v4(),
  nome        text not null,
  cnpj        text,
  criado_em   timestamptz default now()
);

-- Condomínios (cada empresa pode ter vários)
create table public.condominios (
  id          uuid primary key default uuid_generate_v4(),
  empresa_id  uuid references public.empresas(id) on delete cascade,
  nome        text not null,
  endereco    text,
  ativo       boolean default true,
  criado_em   timestamptz default now()
);

-- Perfis de usuário (extensão do auth.users do Supabase)
create table public.perfis (
  id              uuid primary key references auth.users(id) on delete cascade,
  condominio_id   uuid references public.condominios(id),
  empresa_id      uuid references public.empresas(id),
  nome            text not null,
  cargo           text,
  perfil          text check (perfil in ('fiscal','admin','superadmin')) default 'fiscal',
  foto_url        text,
  ativo           boolean default true,
  criado_em       timestamptz default now()
);

-- Áreas dinâmicas por condomínio
create table public.areas (
  id              uuid primary key default uuid_generate_v4(),
  condominio_id   uuid references public.condominios(id) on delete cascade,
  categoria       text check (categoria in ('corredores','estacionamento','lojas','limpeza')) not null,
  nome            text not null,
  ativo           boolean default true,
  ordem           int default 0,
  criado_em       timestamptz default now()
);

-- Rondas (sessão de verificação)
create table public.rondas (
  id              uuid primary key default uuid_generate_v4(),
  condominio_id   uuid references public.condominios(id) on delete cascade,
  fiscal_id       uuid references public.perfis(id),
  tipo            text check (tipo in ('HORARIA','DIARIA','SEMANAL','MENSAL')) not null,
  iniciada_em     timestamptz default now(),
  finalizada_em   timestamptz,
  status          text check (status in ('em_andamento','concluida','incompleta')) default 'em_andamento'
);

-- Registros de checklist (OK/NOK por item)
create table public.registros (
  id              uuid primary key default uuid_generate_v4(),
  ronda_id        uuid references public.rondas(id) on delete cascade,
  condominio_id   uuid references public.condominios(id),
  fiscal_id       uuid references public.perfis(id),
  categoria       text not null,
  area_id         uuid references public.areas(id),
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
create table public.pontos (
  id              uuid primary key default uuid_generate_v4(),
  condominio_id   uuid references public.condominios(id),
  fiscal_id       uuid references public.perfis(id),
  tipo            text check (tipo in ('ENTRADA','SAIDA','INICIO_INTERVALO','FIM_INTERVALO')) not null,
  selfie_url      text,
  lat             double precision,
  lng             double precision,
  precisao        double precision,
  endereco        text,
  link_mapa       text,
  registrado_em   timestamptz default now()
);

-- Inconformidades avulsas
create table public.inconformidades (
  id              uuid primary key default uuid_generate_v4(),
  condominio_id   uuid references public.condominios(id),
  fiscal_id       uuid references public.perfis(id),
  descricao       text,
  foto_url        text,
  audio_url       text,
  lat             double precision,
  lng             double precision,
  endereco        text,
  resolvida       boolean default false,
  criado_em       timestamptz default now()
);

-- ── ROW LEVEL SECURITY ────────────────────────────────────

alter table public.empresas        enable row level security;
alter table public.condominios     enable row level security;
alter table public.perfis          enable row level security;
alter table public.areas           enable row level security;
alter table public.rondas          enable row level security;
alter table public.registros       enable row level security;
alter table public.pontos          enable row level security;
alter table public.inconformidades enable row level security;

-- Função auxiliar: retorna condominio_id do usuário logado
create or replace function public.meu_condominio_id()
returns uuid language sql security definer stable as $$
  select condominio_id from public.perfis where id = auth.uid()
$$;

-- Função auxiliar: retorna perfil do usuário logado
create or replace function public.meu_perfil()
returns text language sql security definer stable as $$
  select perfil from public.perfis where id = auth.uid()
$$;

-- Policies: usuário vê apenas dados do seu condomínio
create policy "fiscal_ve_proprio_condominio" on public.registros
  for all using (condominio_id = meu_condominio_id());

create policy "fiscal_ve_proprios_pontos" on public.pontos
  for all using (condominio_id = meu_condominio_id());

create policy "fiscal_ve_areas_condominio" on public.areas
  for all using (condominio_id = meu_condominio_id());

create policy "fiscal_ve_rondas_condominio" on public.rondas
  for all using (condominio_id = meu_condominio_id());

create policy "fiscal_ve_inconformidades" on public.inconformidades
  for all using (condominio_id = meu_condominio_id());

create policy "usuario_ve_proprio_perfil" on public.perfis
  for select using (id = auth.uid() or meu_perfil() in ('admin','superadmin'));

create policy "usuario_atualiza_proprio_perfil" on public.perfis
  for update using (id = auth.uid());

create policy "admin_ve_condominios" on public.condominios
  for select using (id = meu_condominio_id() or meu_perfil() in ('admin','superadmin'));

-- Superadmin vê tudo (empresas)
create policy "superadmin_ve_empresas" on public.empresas
  for all using (meu_perfil() = 'superadmin');

-- ── STORAGE BUCKETS ───────────────────────────────────────
-- (Executar no dashboard do Supabase → Storage)
-- Bucket: fotos-ronda    (private, max 5MB por arquivo)
-- Bucket: selfies-ponto  (private, max 3MB por arquivo)
-- Bucket: audios-ronda   (private, max 10MB por arquivo)

-- ── DADOS INICIAIS ────────────────────────────────────────

-- Empresa ProIntegra
insert into public.empresas (id, nome, cnpj) values
  ('00000000-0000-0000-0000-000000000001', 'ProIntegra Serviços', '31.495.586/0001-36');

-- Condomínio padrão de demonstração
insert into public.condominios (id, empresa_id, nome, endereco) values
  ('00000000-0000-0000-0000-000000000010',
   '00000000-0000-0000-0000-000000000001',
   'Condomínio Centro Comercial', 'Rua das Flores, 100 — Centro');

-- Áreas padrão para o condomínio demo
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
  ('00000000-0000-0000-0000-000000000010','limpeza','Área Interna',2);

-- NOTA: Usuários são criados via Supabase Auth (Dashboard → Authentication → Users)
-- Após criar, execute o INSERT abaixo substituindo <uuid-do-auth-user>:
/*
insert into public.perfis (id, condominio_id, empresa_id, nome, cargo, perfil) values
  ('<uuid>', '00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001',
   'Iran Feliciano', 'Super Administrador', 'superadmin');
*/
