-- ============================================================
-- CondoGest — Sistema de Gestão de Rondas e Checklists
-- Implantação: ronda.prointegraserv.com.br
-- Banco de Dados: PostgreSQL 15+
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- CREATE EXTENSION IF NOT EXISTS "postgis"; -- Habilitar para GPS avançado

-- ============================================================
-- PERFIS DE ACESSO (RBAC)
-- ============================================================
CREATE TABLE perfis_acesso (
    id          SERIAL PRIMARY KEY,
    nome        VARCHAR(50)  NOT NULL UNIQUE,
    descricao   TEXT,
    permissoes  JSONB        NOT NULL DEFAULT '{}',
    criado_em   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO perfis_acesso (nome, descricao, permissoes) VALUES
('fiscal',        'Fiscal de Piso — coleta de dados em campo',
    '{"mobile":true,"admin":false,"relatorios":false,"configuracoes":false}'),
('vigilante',     'Vigilante — rondas de segurança',
    '{"mobile":true,"admin":false,"relatorios":false,"configuracoes":false}'),
('supervisor',    'Supervisor — acompanhamento operacional',
    '{"mobile":true,"admin":true,"relatorios":true,"configuracoes":false}'),
('administrador', 'Administrador — acesso total',
    '{"mobile":true,"admin":true,"relatorios":true,"configuracoes":true}'),
('sindico',       'Síndico — visualização e relatórios executivos',
    '{"mobile":false,"admin":true,"relatorios":true,"configuracoes":false}');

-- ============================================================
-- USUÁRIOS
-- ============================================================
CREATE TABLE usuarios (
    id             UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome           VARCHAR(100) NOT NULL,
    cpf            VARCHAR(11)  UNIQUE,
    matricula      VARCHAR(20)  UNIQUE,
    email          VARCHAR(150) UNIQUE,
    telefone       VARCHAR(20),
    foto_url       TEXT,                   -- Caminho relativo: /uploads/fotos/{id}.jpg
    perfil_id      INTEGER      NOT NULL REFERENCES perfis_acesso(id),
    senha_hash     TEXT         NOT NULL,
    ativo          BOOLEAN      NOT NULL DEFAULT TRUE,
    ultimo_acesso  TIMESTAMPTZ,
    criado_em      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    atualizado_em  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_usuarios_perfil ON usuarios(perfil_id);
CREATE INDEX idx_usuarios_ativo  ON usuarios(ativo);

-- ============================================================
-- SETORES / LOCAIS DO CONDOMÍNIO
-- ============================================================
CREATE TABLE setores (
    id                     SERIAL       PRIMARY KEY,
    codigo                 VARCHAR(20)  NOT NULL UNIQUE,
    nome                   VARCHAR(100) NOT NULL,
    descricao              TEXT,
    andar                  SMALLINT,
    bloco                  VARCHAR(10),
    foto_referencia_url    TEXT,       -- Foto real para reconhecimento visual no app: /uploads/setores/{id}.jpg
    latitude               DECIMAL(10,8),
    longitude              DECIMAL(11,8),
    raio_validacao_metros  INTEGER      NOT NULL DEFAULT 50,
    ativo                  BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_setores_ativo ON setores(ativo);

INSERT INTO setores (codigo, nome, andar, bloco, foto_referencia_url) VALUES
('GAR_B1',  'Garagem — Bloco A',       -1, 'A', '/uploads/setores/garagem_bloco_a.jpg'),
('RECEPCAO', 'Recepção Principal',       0, '-', '/uploads/setores/recepcao.jpg'),
('PORTARIA', 'Portaria',                 0, '-', '/uploads/setores/portaria.jpg'),
('HALL_T01', 'Hall — Térreo Bloco 1',   0, '1', '/uploads/setores/hall_terreo.jpg'),
('BANHM_T',  'Banheiro Masc. Térreo',   0, '-', '/uploads/setores/banheiro_masc.jpg'),
('BANHF_T',  'Banheiro Fem. Térreo',    0, '-', '/uploads/setores/banheiro_fem.jpg'),
('ELEV_1',   'Elevador Social 1',        0, '1', '/uploads/setores/elevador1.jpg'),
('ELEV_2',   'Elevador Social 2',        0, '2', '/uploads/setores/elevador2.jpg'),
('ESCAD_B1', 'Escada Corta-Fogo Bloco 1',1,'1', '/uploads/setores/escada_cortafogo.jpg'),
('COBERT',   'Cobertura / Casa de Máquinas', 20,'-', '/uploads/setores/cobertura.jpg');

-- ============================================================
-- CATEGORIAS DE CHECKLIST
-- ============================================================
CREATE TABLE categorias_checklist (
    id      SERIAL      PRIMARY KEY,
    codigo  VARCHAR(20) NOT NULL UNIQUE,
    nome    VARCHAR(50) NOT NULL,
    cor_hex CHAR(7)     NOT NULL,
    icone   VARCHAR(10),
    ordem   SMALLINT    NOT NULL DEFAULT 0
);

INSERT INTO categorias_checklist (codigo, nome, cor_hex, icone, ordem) VALUES
('LIMPEZA',   'Limpeza',              '#16a34a', '🧹', 1),
('SEGURANCA', 'Segurança e Rondas',   '#1d4ed8', '🛡️', 2),
('ESTRUTURA', 'Estrutura e Manutenção','#d97706', '🔧', 3),
('INCENDIO',  'Brigada de Incêndio',  '#dc2626', '🔥', 4);

-- ============================================================
-- FREQUÊNCIAS DE CHECKLIST (tabela de referência)
-- ============================================================
CREATE TABLE frequencias_checklist (
    codigo       VARCHAR(10) PRIMARY KEY,
    nome         VARCHAR(40) NOT NULL,
    descricao    TEXT,
    cor_hex      CHAR(7)     NOT NULL,
    intervalo_h  DECIMAL(6,2)            -- Intervalo em horas (ex: 1, 24, 168, 720)
);

INSERT INTO frequencias_checklist (codigo, nome, descricao, cor_hex, intervalo_h) VALUES
('HORARIA',  'Ronda Horária',    'Verificações a cada hora durante o turno', '#7c3aed', 1),
('DIARIA',   'Check Diário',     'Inspeção realizada uma vez por turno/dia',  '#1d4ed8', 24),
('SEMANAL',  'Check Semanal',    'Inspeção realizada uma vez por semana',     '#d97706', 168),
('MENSAL',   'Inspeção Mensal',  'Inspeção completa mensal com registro formal','#dc2626',720);

-- ============================================================
-- ITENS DE CHECKLIST
-- ============================================================
CREATE TABLE itens_checklist (
    id                    SERIAL       PRIMARY KEY,
    categoria_id          INTEGER      NOT NULL REFERENCES categorias_checklist(id),
    frequencia            VARCHAR(10)  NOT NULL DEFAULT 'DIARIA' REFERENCES frequencias_checklist(codigo),
    codigo                VARCHAR(30)  NOT NULL UNIQUE,
    descricao             VARCHAR(200) NOT NULL,
    icone_ok              VARCHAR(10)  NOT NULL DEFAULT '👍',
    icone_nok             VARCHAR(10)  NOT NULL DEFAULT '👎',
    label_ok              VARCHAR(50)  NOT NULL DEFAULT 'OK',
    label_nok             VARCHAR(50)  NOT NULL DEFAULT 'PROBLEMA',
    instrucao_campo       TEXT,                  -- Instrução visual detalhada para o fiscal
    requer_foto_nok       BOOLEAN      NOT NULL DEFAULT TRUE,
    requer_audio_nok      BOOLEAN      NOT NULL DEFAULT TRUE,
    requer_foto_ok        BOOLEAN      NOT NULL DEFAULT FALSE,
    criticidade           VARCHAR(10)  NOT NULL DEFAULT 'MEDIA'
                              CHECK (criticidade IN ('BAIXA','MEDIA','ALTA','CRITICA')),
    ativo                 BOOLEAN      NOT NULL DEFAULT TRUE,
    ordem                 SMALLINT     NOT NULL DEFAULT 0
);

-- ─── LIMPEZA ──────────────────────────────────────────────────────────────────
-- Ronda Horária: corredor/hall deve ser verificado a cada ronda
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, ordem, instrucao_campo) VALUES
(1,'HORARIA', 'LIMP_CHAO_HORA', 'Piso dos Corredores (Ronda)',      '👍','👎','LIMPO',  'SUJO',  'MEDIA',1,'Verifique o piso dos corredores de circulação principal'),
(1,'HORARIA', 'LIMP_HALL_HORA', 'Hall de Entrada/Recepção (Ronda)', '👍','👎','LIMPO',  'SUJO',  'MEDIA',2,'Verifique o hall de entrada e área da recepção');

-- Check Diário: varredura completa de limpeza
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, ordem, instrucao_campo) VALUES
(1,'DIARIA','LIMP_CHAO',     'Condição Geral do Piso',       '👍','👎','LIMPO',  'SUJO',   'MEDIA',1,'Verifique todos os pisos do pavimento'),
(1,'DIARIA','LIMP_LIXEIRA',  'Status das Lixeiras',          '👍','👎','VAZIAS', 'CHEIAS', 'MEDIA',2,'Verifique se as lixeiras estão cheias ou transbordando'),
(1,'DIARIA','LIMP_BANHEIRO', 'Condição dos Banheiros',       '👍','👎','LIMPOS', 'PROBLEMA','ALTA',3,'Verifique papel, sabonete, privadas e piso do banheiro');

-- ─── SEGURANÇA ────────────────────────────────────────────────────────────────
-- Ronda Horária: o ponto mais crítico de segurança
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, ordem, instrucao_campo) VALUES
(2,'HORARIA','SEG_PORTA_HORA',  'Portas e Portões (Ronda)',    '🔒','🔓','TRANCADO','ABERTO/DANIF.','ALTA',  1,'Teste todas as portas e portões do percurso da ronda'),
(2,'HORARIA','SEG_GARAGEM_HORA','Garagem — Acesso e Circulação','✅','⚠️','LIVRE',  'PROBLEMA',   'ALTA',  2,'Verifique barreiras, cancelas e acesso à garagem'),
(2,'HORARIA','SEG_PORTARIA_HORA','Portaria — Posto de Guarda', '✅','⚠️','OCUPADO','PROBLEMA',   'CRITICA',3,'Confirme que o posto de portaria está guarnecido');

-- Check Diário
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, ordem, instrucao_campo) VALUES
(2,'DIARIA','SEG_CAMERA',   'Câmeras de Segurança (CFTV)',  '✅','❌','FUNCIONANDO','COM PROBLEMA','CRITICA',1,'Verifique o monitor do CFTV — todas as câmeras operacionais'),
(2,'DIARIA','SEG_ILUM_EXT', 'Iluminação Área Externa',      '💡','🔦','ACESAS',    'APAGADAS',   'MEDIA',  2,'Verifique lâmpadas externas ao anoitecer ou de manhã');

-- Check Semanal
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, ordem, instrucao_campo) VALUES
(2,'SEMANAL','SEG_INTERFONE','Sistema de Interfone/Rádio',   '✅','❌','FUNCIONANDO','COM PROBLEMA','MEDIA',1,'Teste o interfone de cada andar e o rádio da portaria'),
(2,'SEMANAL','SEG_ALARME',  'Central de Alarme',             '✅','❌','ARMADO/OK', 'COM PROBLEMA','CRITICA',2,'Verifique painel da central de alarme — sem zonas em fault');

-- ─── ESTRUTURA ────────────────────────────────────────────────────────────────
-- Ronda Horária
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, ordem, instrucao_campo) VALUES
(3,'HORARIA','EST_ELEVADOR_HORA','Elevadores — Operação (Ronda)','✅','🛑','FUNCIONANDO','PARADO','ALTA',1,'Verifique os displays e chame os elevadores — devem responder normalmente');

-- Check Diário
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, ordem, instrucao_campo) VALUES
(3,'DIARIA','EST_LAMPADA',  'Lâmpadas — Corredores e Halls', '💡','🔦','ACESAS',    'QUEIMADAS',  'MEDIA',1,'Verifique todas as luminárias dos corredores e halls'),
(3,'DIARIA','EST_ELEVADOR', 'Elevadores — Inspeção Diária',  '✅','🛑','FUNCIONANDO','PARADO',     'ALTA', 2,'Verifique operação, alarme sonoro e iluminação interna da cabine');

-- Check Semanal
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, ordem, instrucao_campo) VALUES
(3,'SEMANAL','EST_VIDRO',    'Vidros, Janelas e Fachada',    '✅','💢','INTEIROS',  'QUEBRADOS',  'ALTA',1,'Inspecione vidros, esquadrias e fachada em toda a extensão'),
(3,'SEMANAL','EST_VAZAMENTO','Vazamentos e Infiltrações',    '✅','🌊','SECO',      'VAZANDO',    'ALTA',2,'Verifique tetos, paredes e casa de bombas por sinais de umidade'),
(3,'SEMANAL','EST_ESCADAS',  'Corrimãos e Escadas',          '✅','⚠️','OK',        'COM PROBLEMA','MEDIA',3,'Teste firmeza dos corrimãos e condição dos degraus');

-- Check Mensal
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, requer_foto_ok, ordem, instrucao_campo) VALUES
(3,'MENSAL','EST_COBERTURA', 'Cobertura e Casa de Máquinas', '✅','⚠️','OK',        'COM PROBLEMA','ALTA',TRUE,1,'Inspecione a cobertura, calhas, caixa d''água e casa de máquinas'),
(3,'MENSAL','EST_SUBESTACAO','Subestação Elétrica',          '✅','⚠️','OK',        'COM PROBLEMA','CRITICA',TRUE,2,'Verifique quadros elétricos — sinais de aquecimento, odor ou ruído'),
(3,'MENSAL','EST_BOMBA',     'Bombas Hidráulicas',           '✅','⚠️','FUNCIONANDO','COM PROBLEMA','ALTA',TRUE,3,'Acione manualmente as bombas de pressurização e verifique operação');

-- ─── INCÊNDIO ─────────────────────────────────────────────────────────────────
-- Check Diário
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, ordem, instrucao_campo) VALUES
(4,'DIARIA','INC_PORTA_CF',  'Portas Corta-Fogo',                  '🚪','🚨','FECHADAS',       'TRAVADAS/ABERTAS','CRITICA',1,'Verifique se todas as PCF estão livres, fechando normalmente sem calços'),
(4,'DIARIA','INC_SAIDA_EMER','Sinalização de Saída de Emergência', '✅','❌','ILUMINADA/OK',   'APAGADA/DANIF.', 'CRITICA',2,'Verifique se todas as placas de saída de emergência estão iluminadas');

-- Check Semanal
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, ordem, instrucao_campo) VALUES
(4,'SEMANAL','INC_EXTINTOR_VIS','Extintores — Verificação Visual',    '✅','❌','NO LUGAR/LACRADO','SUMIU/DANIF.',   'CRITICA',1,'Confirme: extintor no suporte, lacre intacto, manômetro na faixa verde'),
(4,'SEMANAL','INC_MANGUEIRA_VIS','Mangueiras — Verificação Visual',   '✅','⚠️','CAIXA FECHADA',  'ABERTA/DANIF.', 'CRITICA',2,'Confirme que a caixa de mangueira está fechada, mangueira e esguicho presentes');

-- Check Mensal: Inspeção detalhada exige foto mesmo se OK
INSERT INTO itens_checklist (categoria_id, frequencia, codigo, descricao, icone_ok, icone_nok, label_ok, label_nok, criticidade, requer_foto_ok, ordem, instrucao_campo) VALUES
(4,'MENSAL','INC_EXTINTOR_MNS','Extintores — Inspeção Mensal Completa','✅','❌','CONFORME',      'NÃO CONFORME',  'CRITICA',TRUE,1,
 'Verifique: (1) Lacre presente, (2) Pino de segurança, (3) Manômetro na faixa verde, (4) Peso/carga (sacuda), (5) Validade da recarga, (6) Suporte fixo. FOTOGRAFE sempre.'),
(4,'MENSAL','INC_MANGUEIRA_MNS','Suportes de Mangueiras e Hidrantes', '✅','⚠️','CONFORME',      'NÃO CONFORME',  'CRITICA',TRUE,2,
 'Verifique: (1) Mangueira presente e enrolada, (2) Esguicho presente, (3) Registro de hidrante opera, (4) Caixa sem dano, (5) Vedação da tampa. FOTOGRAFE sempre.'),
(4,'MENSAL','INC_HIDRANTE',     'Hidrantes Internos e Externos',      '✅','⚠️','CONFORME',      'NÃO CONFORME',  'CRITICA',TRUE,3,
 'Abra o registro do hidrante brevemente para verificar fluxo de água e vedação. Verifique conexões. FOTOGRAFE sempre.'),
(4,'MENSAL','INC_DETECTORES',   'Detectores de Fumaça e Calor',       '✅','❌','OPERACIONAIS',  'COM PROBLEMA',  'CRITICA',TRUE,4,
 'Pressione o botão de teste de cada detector de fumaça — o alarme deve soar. Registre os que não responderam.');

-- ============================================================
-- RONDAS
-- ============================================================
CREATE TABLE rondas (
    id                       UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    fiscal_id                UUID        NOT NULL REFERENCES usuarios(id),
    frequencia               VARCHAR(10) NOT NULL DEFAULT 'HORARIA' REFERENCES frequencias_checklist(codigo),
    data_inicio              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    data_fim                 TIMESTAMPTZ,
    status                   VARCHAR(20) NOT NULL DEFAULT 'EM_ANDAMENTO'
                                 CHECK (status IN ('EM_ANDAMENTO','CONCLUIDA','INCOMPLETA','CANCELADA')),
    turno                    VARCHAR(10) CHECK (turno IN ('MANHA','TARDE','NOITE')),
    total_itens              SMALLINT    NOT NULL DEFAULT 0,
    itens_ok                 SMALLINT    NOT NULL DEFAULT 0,
    itens_nok                SMALLINT    NOT NULL DEFAULT 0,
    percentual_conformidade  DECIMAL(5,2),
    observacoes              TEXT,
    criado_em                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rondas_fiscal ON rondas(fiscal_id);
CREATE INDEX idx_rondas_status ON rondas(status);
CREATE INDEX idx_rondas_data   ON rondas(data_inicio DESC);

-- ============================================================
-- REGISTROS DE CHECKLIST
-- ============================================================
CREATE TABLE registros_checklist (
    id                    UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    ronda_id              UUID        NOT NULL REFERENCES rondas(id) ON DELETE CASCADE,
    item_id               INTEGER     NOT NULL REFERENCES itens_checklist(id),
    setor_id              INTEGER     NOT NULL REFERENCES setores(id),
    fiscal_id             UUID        NOT NULL REFERENCES usuarios(id),
    status                CHAR(3)     NOT NULL CHECK (status IN ('OK','NOK')),
    latitude              DECIMAL(10,8),
    longitude             DECIMAL(11,8),
    precisao_gps_metros   DECIMAL(8,2),
    registrado_em         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sincronizado_em       TIMESTAMPTZ            -- Controle de sync offline→online
);

CREATE INDEX idx_reg_ronda    ON registros_checklist(ronda_id);
CREATE INDEX idx_reg_item     ON registros_checklist(item_id);
CREATE INDEX idx_reg_setor    ON registros_checklist(setor_id);
CREATE INDEX idx_reg_fiscal   ON registros_checklist(fiscal_id);
CREATE INDEX idx_reg_status   ON registros_checklist(status);
CREATE INDEX idx_reg_data     ON registros_checklist(registrado_em DESC);

-- ============================================================
-- OCORRÊNCIAS
-- ============================================================
CREATE TABLE ocorrencias (
    id                      UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    registro_id             UUID        REFERENCES registros_checklist(id),
    ronda_id                UUID        REFERENCES rondas(id),
    fiscal_id               UUID        NOT NULL REFERENCES usuarios(id),
    setor_id                INTEGER     NOT NULL REFERENCES setores(id),
    item_id                 INTEGER     REFERENCES itens_checklist(id),
    tipo                    VARCHAR(20) NOT NULL DEFAULT 'CHECKLIST'
                                CHECK (tipo IN ('CHECKLIST','PANICO','AVULSA')),
    descricao_automatica    TEXT,
    transcricao_audio       TEXT,       -- Resultado de STT (Speech-To-Text) se configurado
    status                  VARCHAR(20) NOT NULL DEFAULT 'ABERTA'
                                CHECK (status IN ('ABERTA','EM_ATENDIMENTO','RESOLVIDA','DESCARTADA')),
    prioridade              VARCHAR(10) NOT NULL DEFAULT 'MEDIA'
                                CHECK (prioridade IN ('BAIXA','MEDIA','ALTA','CRITICA')),
    atribuido_para          UUID        REFERENCES usuarios(id),
    data_limite_resolucao   TIMESTAMPTZ,
    resolvida_em            TIMESTAMPTZ,
    observacoes_resolucao   TEXT,
    criado_em               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_oc_fiscal    ON ocorrencias(fiscal_id);
CREATE INDEX idx_oc_setor     ON ocorrencias(setor_id);
CREATE INDEX idx_oc_status    ON ocorrencias(status);
CREATE INDEX idx_oc_prioridade ON ocorrencias(prioridade);
CREATE INDEX idx_oc_tipo      ON ocorrencias(tipo);
CREATE INDEX idx_oc_data      ON ocorrencias(criado_em DESC);

-- ============================================================
-- MÍDIAS (FOTOS E ÁUDIOS)
-- ============================================================
CREATE TABLE midias (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    ocorrencia_id   UUID        REFERENCES ocorrencias(id) ON DELETE CASCADE,
    registro_id     UUID        REFERENCES registros_checklist(id),
    tipo            VARCHAR(10) NOT NULL CHECK (tipo IN ('FOTO','AUDIO','VIDEO')),
    -- URL pública absoluta: https://ronda.prointegraserv.com.br/uploads/midias/{id}.{ext}
    url_storage     TEXT        NOT NULL,
    nome_arquivo    VARCHAR(255),
    tamanho_bytes   BIGINT,
    duracao_seg     SMALLINT,       -- Para áudios/vídeos
    largura_px      SMALLINT,       -- Para fotos/vídeos
    altura_px       SMALLINT,
    latitude        DECIMAL(10,8),
    longitude       DECIMAL(11,8),
    capturado_em    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    uploader_id     UUID        NOT NULL REFERENCES usuarios(id)
);

CREATE INDEX idx_midias_ocorrencia ON midias(ocorrencia_id);
CREATE INDEX idx_midias_registro   ON midias(registro_id);
CREATE INDEX idx_midias_tipo       ON midias(tipo);

-- ============================================================
-- ALERTAS DE PÂNICO
-- ============================================================
CREATE TABLE alertas_panico (
    id             UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    acionado_por   UUID        NOT NULL REFERENCES usuarios(id),
    setor_id       INTEGER     REFERENCES setores(id),
    latitude       DECIMAL(10,8),
    longitude      DECIMAL(11,8),
    status         VARCHAR(20) NOT NULL DEFAULT 'ATIVO'
                       CHECK (status IN ('ATIVO','ATENDIDO','FALSO_ALARME')),
    atendido_por   UUID        REFERENCES usuarios(id),
    atendido_em    TIMESTAMPTZ,
    descricao      TEXT,
    acionado_em    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_panico_status ON alertas_panico(status);
CREATE INDEX idx_panico_data   ON alertas_panico(acionado_em DESC);

-- ============================================================
-- ORDENS DE SERVIÇO
-- ============================================================
CREATE TABLE ordens_servico (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    ocorrencia_id   UUID        REFERENCES ocorrencias(id),
    criado_por      UUID        NOT NULL REFERENCES usuarios(id),
    atribuido_para  UUID        REFERENCES usuarios(id),
    setor_id        INTEGER     NOT NULL REFERENCES setores(id),
    titulo          VARCHAR(200) NOT NULL,
    descricao       TEXT,
    prioridade      VARCHAR(10) NOT NULL DEFAULT 'MEDIA'
                        CHECK (prioridade IN ('BAIXA','MEDIA','ALTA','URGENTE')),
    status          VARCHAR(25) NOT NULL DEFAULT 'ABERTA'
                        CHECK (status IN ('ABERTA','ACEITA','EM_EXECUCAO','AGUARD_MATERIAL','CONCLUIDA','CANCELADA')),
    data_prevista   TIMESTAMPTZ,
    concluida_em    TIMESTAMPTZ,
    custo_estimado  DECIMAL(10,2),
    custo_real      DECIMAL(10,2),
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_os_ocorrencia ON ordens_servico(ocorrencia_id);
CREATE INDEX idx_os_status     ON ordens_servico(status);
CREATE INDEX idx_os_data       ON ordens_servico(criado_em DESC);

-- ============================================================
-- ESCALA DE RONDAS
-- ============================================================
CREATE TABLE escala_rondas (
    id          SERIAL      PRIMARY KEY,
    fiscal_id   UUID        NOT NULL REFERENCES usuarios(id),
    setor_id    INTEGER     NOT NULL REFERENCES setores(id),
    dia_semana  SMALLINT    CHECK (dia_semana BETWEEN 0 AND 6), -- 0=Dom, 6=Sab; NULL = todo dia
    hora_inicio TIME        NOT NULL,
    hora_fim    TIME        NOT NULL,
    turno       VARCHAR(10) CHECK (turno IN ('MANHA','TARDE','NOITE')),
    ativo       BOOLEAN     NOT NULL DEFAULT TRUE
);

-- ============================================================
-- LOG DE AUDITORIA
-- ============================================================
CREATE TABLE logs_auditoria (
    id               BIGSERIAL   PRIMARY KEY,
    usuario_id       UUID        REFERENCES usuarios(id),
    acao             VARCHAR(50) NOT NULL,
    tabela_afetada   VARCHAR(50),
    registro_id      TEXT,
    ip_address       INET,
    user_agent       TEXT,
    dados_anteriores JSONB,
    dados_novos      JSONB,
    criado_em        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_log_usuario ON logs_auditoria(usuario_id);
CREATE INDEX idx_log_data    ON logs_auditoria(criado_em DESC);

-- ============================================================
-- VIEWS PARA O PAINEL ADMINISTRATIVO
-- ============================================================

-- Conformidade por categoria nos últimos 30 dias
CREATE OR REPLACE VIEW vw_conformidade_categoria AS
SELECT
    cat.id,
    cat.nome             AS categoria,
    cat.cor_hex,
    cat.icone,
    COUNT(rc.id)         AS total_verificacoes,
    SUM(CASE WHEN rc.status = 'OK'  THEN 1 ELSE 0 END) AS total_ok,
    SUM(CASE WHEN rc.status = 'NOK' THEN 1 ELSE 0 END) AS total_nok,
    ROUND(
        SUM(CASE WHEN rc.status = 'OK' THEN 1 ELSE 0 END)::DECIMAL
        / NULLIF(COUNT(rc.id), 0) * 100, 1
    ) AS percentual_conformidade
FROM registros_checklist rc
JOIN itens_checklist     ic  ON rc.item_id     = ic.id
JOIN categorias_checklist cat ON ic.categoria_id = cat.id
WHERE rc.registrado_em >= NOW() - INTERVAL '30 days'
GROUP BY cat.id, cat.nome, cat.cor_hex, cat.icone;

-- Rondas ativas em tempo real
CREATE OR REPLACE VIEW vw_rondas_ativas AS
SELECT
    r.id,
    u.nome                                                      AS fiscal_nome,
    u.foto_url                                                  AS fiscal_foto,
    r.data_inicio,
    r.turno,
    r.status,
    ROUND(EXTRACT(EPOCH FROM (NOW() - r.data_inicio)) / 60, 0) AS minutos_em_ronda,
    r.itens_ok,
    r.itens_nok,
    r.total_itens,
    r.percentual_conformidade
FROM rondas  r
JOIN usuarios u ON r.fiscal_id = u.id
WHERE r.status = 'EM_ANDAMENTO'
ORDER BY r.data_inicio DESC;

-- Central de triagem de incidentes abertos com contagem de mídias
CREATE OR REPLACE VIEW vw_triagem_incidentes AS
SELECT
    o.id,
    o.tipo,
    o.status,
    o.prioridade,
    o.criado_em,
    u.nome          AS fiscal_nome,
    u.foto_url      AS fiscal_foto,
    s.nome          AS setor_nome,
    ic.descricao    AS item_descricao,
    cat.nome        AS categoria_nome,
    cat.cor_hex     AS categoria_cor,
    COUNT(m.id) FILTER (WHERE m.tipo = 'FOTO')  AS total_fotos,
    COUNT(m.id) FILTER (WHERE m.tipo = 'AUDIO') AS total_audios,
    -- URL da primeira foto para thumbnail: https://ronda.prointegraserv.com.br + url_storage
    MIN(m.url_storage) FILTER (WHERE m.tipo = 'FOTO') AS thumb_url
FROM ocorrencias         o
JOIN usuarios            u   ON o.fiscal_id    = u.id
JOIN setores             s   ON o.setor_id     = s.id
LEFT JOIN itens_checklist ic  ON o.item_id      = ic.id
LEFT JOIN categorias_checklist cat ON ic.categoria_id = cat.id
LEFT JOIN midias         m   ON o.id           = m.ocorrencia_id
WHERE o.status IN ('ABERTA','EM_ATENDIMENTO')
GROUP BY o.id, o.tipo, o.status, o.prioridade, o.criado_em,
         u.nome, u.foto_url, s.nome, ic.descricao, cat.nome, cat.cor_hex
ORDER BY
    CASE o.prioridade
        WHEN 'CRITICA' THEN 1 WHEN 'ALTA' THEN 2
        WHEN 'MEDIA'   THEN 3 ELSE 4
    END,
    o.criado_em ASC;

-- Heatmap: Setores com mais falhas nos últimos 30 dias
CREATE OR REPLACE VIEW vw_heatmap_setores AS
SELECT
    s.id,
    s.nome          AS setor,
    s.bloco,
    s.andar,
    COUNT(o.id)     AS total_ocorrencias,
    COUNT(o.id) FILTER (WHERE o.prioridade IN ('ALTA','CRITICA')) AS ocorrencias_criticas
FROM setores     s
LEFT JOIN ocorrencias o ON o.setor_id = s.id
    AND o.criado_em >= NOW() - INTERVAL '30 days'
    AND o.status    <> 'DESCARTADA'
GROUP BY s.id, s.nome, s.bloco, s.andar
ORDER BY total_ocorrencias DESC;

-- ============================================================
-- FUNÇÃO: Atualiza conformidade ao fechar ronda
-- ============================================================
CREATE OR REPLACE FUNCTION fn_fechar_ronda(p_ronda_id UUID)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_total    INTEGER;
    v_ok       INTEGER;
    v_nok      INTEGER;
BEGIN
    SELECT
        COUNT(*),
        SUM(CASE WHEN status = 'OK'  THEN 1 ELSE 0 END),
        SUM(CASE WHEN status = 'NOK' THEN 1 ELSE 0 END)
    INTO v_total, v_ok, v_nok
    FROM registros_checklist
    WHERE ronda_id = p_ronda_id;

    UPDATE rondas SET
        data_fim                = NOW(),
        status                  = 'CONCLUIDA',
        total_itens             = v_total,
        itens_ok                = v_ok,
        itens_nok               = v_nok,
        percentual_conformidade = ROUND(v_ok::DECIMAL / NULLIF(v_total,0) * 100, 1)
    WHERE id = p_ronda_id;
END;
$$;
