-- Usar o banco de dados já existente
USE fabrica;
USE fabrica;


-- ============================================================
-- 1. TABELA DE TURNOS DE PRODUÇÃO
-- ============================================================
--
-- Cada execução completa da célula corresponde a uma linha.
-- Exemplo:
-- TURNO_2026_05_31_001
--
-- A tabela também permitirá filtrar relatórios por período.
-- ============================================================

CREATE TABLE IF NOT EXISTS turnos_producao (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    turno_codigo VARCHAR(60) NOT NULL,
    celula VARCHAR(30) NOT NULL DEFAULT 'CELULA_01',

    data_inicio DATETIME NOT NULL,
    data_fim DATETIME DEFAULT NULL,

    status ENUM('ABERTO', 'FINALIZADO') NOT NULL DEFAULT 'ABERTO',

    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uk_turno_codigo_celula (
        turno_codigo,
        celula
    ),

    KEY idx_turnos_periodo (
        data_inicio,
        data_fim
    )
);


-- ============================================================
-- 2. RESUMO DE CADA MÁQUINA POR TURNO
-- ============================================================
--
-- Ao finalizar um turno, o Ignition gravará 12 linhas:
-- uma para cada máquina da célula.
--
-- Os índices de OEE serão calculados pela view.
-- Dessa forma, não armazenamos resultados duplicados.
-- ============================================================

CREATE TABLE IF NOT EXISTS pim_turno_maquina (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    turno_id BIGINT UNSIGNED NOT NULL,

    maquina TINYINT UNSIGNED NOT NULL,

    operador VARCHAR(40),
    numero_op VARCHAR(40),

    processo VARCHAR(80),

    tempo_ligada_s INT UNSIGNED NOT NULL DEFAULT 0,
    tempo_produzindo_s INT UNSIGNED NOT NULL DEFAULT 0,
    tempo_parada_s INT UNSIGNED NOT NULL DEFAULT 0,
    tempo_bloqueada_s INT UNSIGNED NOT NULL DEFAULT 0,

    operacoes_finalizadas INT UNSIGNED NOT NULL DEFAULT 0,
    operacoes_boas INT UNSIGNED NOT NULL DEFAULT 0,
    operacoes_reprovadas INT UNSIGNED NOT NULL DEFAULT 0,

    pecas_produzidas_ciclo INT UNSIGNED NOT NULL DEFAULT 0,
    pecas_estipuladas_ciclo INT UNSIGNED NOT NULL DEFAULT 0,

    tempo_ideal_ciclo_ms INT UNSIGNED NOT NULL DEFAULT 0,

    -- Reservado para uma etapa futura
    principal_motivo_parada VARCHAR(80) DEFAULT NULL,
    maior_parada_s INT UNSIGNED NOT NULL DEFAULT 0,

    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uk_turno_maquina (
        turno_id,
        maquina
    ),

    KEY idx_pim_maquina (
        maquina
    ),

    CONSTRAINT fk_pim_turno
        FOREIGN KEY (turno_id)
        REFERENCES turnos_producao(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


-- ============================================================
-- 3. VIEW PRONTA PARA O RELATÓRIO PIM
-- ============================================================
--
-- Fórmulas:
--
-- Disponibilidade =
-- tempo_produzindo_s / tempo_ligada_s
--
-- Performance =
-- pecas_produzidas_ciclo / pecas_estipuladas_ciclo
--
-- Qualidade =
-- operacoes_boas / operacoes_finalizadas
--
-- OEE =
-- disponibilidade × performance × qualidade
--
-- A performance utilizada no OEE é limitada a 100%.
-- ============================================================

CREATE OR REPLACE VIEW vw_relatorio_pim_turno AS
SELECT
    t.id AS turno_id,
    t.turno_codigo,
    t.celula,

    t.data_inicio,
    t.data_fim,
    t.status,

    p.maquina,
    p.operador,
    p.numero_op,
    p.processo,

    p.tempo_ligada_s,
    p.tempo_produzindo_s,
    p.tempo_parada_s,
    p.tempo_bloqueada_s,

    p.operacoes_finalizadas,
    p.operacoes_boas,
    p.operacoes_reprovadas,

    p.pecas_produzidas_ciclo,
    p.pecas_estipuladas_ciclo,

    p.tempo_ideal_ciclo_ms,

    p.principal_motivo_parada,
    p.maior_parada_s,

    ROUND(
        100.0
        * p.tempo_produzindo_s
        / NULLIF(p.tempo_ligada_s, 0),
        2
    ) AS disponibilidade_pct,

    ROUND(
        100.0
        * p.pecas_produzidas_ciclo
        / NULLIF(p.pecas_estipuladas_ciclo, 0),
        2
    ) AS performance_bruta_pct,

    ROUND(
        LEAST(
            100.0,
            100.0
            * p.pecas_produzidas_ciclo
            / NULLIF(p.pecas_estipuladas_ciclo, 0)
        ),
        2
    ) AS performance_pct,

    ROUND(
        100.0
        * p.operacoes_boas
        / NULLIF(p.operacoes_finalizadas, 0),
        2
    ) AS qualidade_pct,

    ROUND(
        100.0

        * LEAST(
            1.0,
            1.0
            * p.tempo_produzindo_s
            / NULLIF(p.tempo_ligada_s, 0)
        )

        * LEAST(
            1.0,
            1.0
            * p.pecas_produzidas_ciclo
            / NULLIF(p.pecas_estipuladas_ciclo, 0)
        )

        * LEAST(
            1.0,
            1.0
            * p.operacoes_boas
            / NULLIF(p.operacoes_finalizadas, 0)
        ),

        2
    ) AS oee_pct

FROM turnos_producao t

INNER JOIN pim_turno_maquina p
    ON p.turno_id = t.id;


-- ============================================================
-- 4. VIEW PARA LISTAR TURNOS DISPONÍVEIS
-- ============================================================
--
-- Será usada futuramente em um seletor de turnos no Ignition.
-- ============================================================

CREATE OR REPLACE VIEW vw_turnos_disponiveis AS
SELECT
    t.id AS turno_id,

    t.turno_codigo,
    t.celula,

    t.data_inicio,
    t.data_fim,

    t.status,

    COUNT(p.id) AS maquinas_registradas

FROM turnos_producao t

LEFT JOIN pim_turno_maquina p
    ON p.turno_id = t.id

GROUP BY
    t.id,
    t.turno_codigo,
    t.celula,
    t.data_inicio,
    t.data_fim,
    t.status;
    
    USE fabrica;

SHOW FULL TABLES;
DESCRIBE turnos_producao;
DESCRIBE pim_turno_maquina;
SELECT * FROM vw_relatorio_pim_turno;
SeLeCT database();

SELECT *
FROM turnos_producao
ORDER BY id DESC;

USE fabrica;
SELECT
    turno_id,
    maquina,
    operador,
    numero_op,
    processo,
    tempo_ligada_s,
    tempo_produzindo_s,
    tempo_parada_s,
    tempo_bloqueada_s,
    operacoes_finalizadas,
    operacoes_boas,
    operacoes_reprovadas,
    pecas_produzidas_ciclo,
    pecas_estipuladas_ciclo,
    tempo_ideal_ciclo_ms
FROM fabrica.pim_turno_maquina
WHERE turno_id = 10
ORDER BY maquina;
-- Tabela 'eventos_operador': adicionando as colunas para monitoramento
CREATE TABLE IF NOT EXISTS eventos_operador (
    id INT AUTO_INCREMENT PRIMARY KEY,                     -- Identificador único
    operador VARCHAR(100),                                 -- Nome do operador
    maquina VARCHAR(50),                                   -- Máquina utilizada
    processo ENUM('Costura Reta','Coluna','Pesponto','Guarnição','Finalização'), -- Tipo de processo
    login DATETIME,                                        -- Hora do login do operador
    logout DATETIME,                                       -- Hora do logout do operador
    pecas_produzidas INT,                                  -- Quantidade de peças produzidas
    tempo_medio_peca TIME GENERATED ALWAYS AS (            -- Tempo médio por peça
        SEC_TO_TIME(
            TIMESTAMPDIFF(SECOND, login, logout) / NULLIF(pecas_produzidas,0)
        )
    ) STORED,
    criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,          -- Hora de criação do registro
    -- Colunas para monitoramento
    OPC_Ligada BOOLEAN,                                    -- Status da máquina ligada
    OPC_Bloqueio BOOLEAN,                                  -- Status da máquina bloqueada
    OPC_ContagemPontos INT DEFAULT 0,                      -- Contagem de pontos de produção
    OPC_PecasFinalizadas INT DEFAULT 0                     -- Contagem de peças finalizadas
);

-- Tabela 'eventos_maquina': adicionando as colunas para monitoramento da máquina
CREATE TABLE IF NOT EXISTS eventos_maquina (
    id INT AUTO_INCREMENT PRIMARY KEY,

    -- ==================================================
    -- IDENTIFICAÇÃO DO EVENTO
    -- ==================================================

    maquina VARCHAR(50),
    evento VARCHAR(50),
    estado INT,
    pontos INT,
    data_hora DATETIME DEFAULT CURRENT_TIMESTAMP,

    -- ==================================================
    -- DADOS RECEBIDOS DO CODESYS VIA IGNITION
    -- ==================================================

    OPC_Ligada BOOLEAN,
    OPC_Bloqueio BOOLEAN,

    OPC_ContagemPontos INT DEFAULT 0,
    OPC_PecasFinalizadas INT DEFAULT 0,
    OPC_PontosOp INT DEFAULT 0,

    OPC_CodOperador VARCHAR(40) DEFAULT NULL,
    OPC_NumeroOP VARCHAR(40) DEFAULT NULL
);

-- Tabela 'operador_sessao': adicionando as colunas para monitoramento da sessão do operador
CREATE TABLE IF NOT EXISTS operador_sessao (
    id INT AUTO_INCREMENT PRIMARY KEY,                     -- Identificador único
    operador VARCHAR(100) NOT NULL,                         -- Nome do operador
    maquina VARCHAR(50) NOT NULL,                           -- Máquina utilizada
    processo ENUM('Costura reta','Coluna','Pesponto','Guarnição','Finalização') NOT NULL, -- Processo
    login_datetime DATETIME NOT NULL,                       -- Hora de login
    logout_datetime DATETIME DEFAULT NULL,                  -- Hora de logout
    pecas_produzidas INT DEFAULT 0,                         -- Quantidade de peças produzidas
    tempo_medio_por_peca DOUBLE DEFAULT 0,                  -- Tempo médio por peça (em segundos ou minutos)
    criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,           -- Carimbo automático de criação
    -- Colunas para o monitoramento
    OPC_Ligada BOOLEAN,                                     -- Status da máquina ligada
    OPC_Bloqueio BOOLEAN                                    -- Status da máquina bloqueada
);

SELECT * FROM eventos_maquina;


ALTER TABLE eventos_maquina
    ADD COLUMN OPC_Ligada BOOLEAN,
    ADD COLUMN OPC_Bloqueio BOOLEAN,
    ADD COLUMN OPC_ContagemPontos INT DEFAULT 0,
    ADD COLUMN OPC_PecasFinalizadas INT DEFAULT 0;
    
    ALTER TABLE eventos_maquina
	ADD COLUMN OPC_PontosOp INT DEFAULT 0;
    
    ALTER TABLE eventos_maquina
     ADD COLUMN OPC_CodOperador INT DEFAULT 0,
     ADD COLUMN OPC_NumeroOP INT DEFAULT 0;
    
DESCRIBE eventos_maquina;
-- ============================================================
-- CORREÇÃO DOS TIPOS DA TABELA LEGADA eventos_maquina
-- ============================================================

ALTER TABLE eventos_maquina
    MODIFY COLUMN OPC_CodOperador VARCHAR(40) DEFAULT NULL,
    MODIFY COLUMN OPC_NumeroOP VARCHAR(40) DEFAULT NULL;
    
    -- ============================================================
-- BANCO DE DADOS DO RELATÓRIO PIM
-- ============================================================
--
-- Estrutura recomendada:
--
-- turnos_producao
--     1 linha por turno da célula
--
-- pim_turno_maquina
--     12 linhas por turno:
--     uma linha consolidada para cada máquina
--
-- vw_relatorio_pim_turno
--     view pronta para o Ignition consultar
--
-- vw_turnos_disponiveis
--     view auxiliar para listar turnos na tela
--
-- ============================================================


-- ============================================================
-- 1. TABELA DE TURNOS
-- ============================================================
--
-- Guarda o início e o fim de cada turno simulado.
-- Um turno representa a execução completa da célula.
--
-- Exemplo:
-- TURNO_2026_05_31_001
-- CELULA_01
-- início: 2026-05-31 08:00:00
-- fim:    2026-05-31 08:30:00
-- ============================================================

CREATE TABLE IF NOT EXISTS turnos_producao (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    turno_codigo VARCHAR(60) NOT NULL,
    celula VARCHAR(30) NOT NULL DEFAULT 'CELULA_01',

    data_inicio DATETIME NOT NULL,
    data_fim DATETIME DEFAULT NULL,

    status ENUM('ABERTO', 'FINALIZADO') NOT NULL DEFAULT 'ABERTO',

    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uk_turno_codigo_celula (
        turno_codigo,
        celula
    ),

    KEY idx_turnos_periodo (
        data_inicio,
        data_fim
    ),

    KEY idx_turnos_status (
        status
    )
);


-- ============================================================
-- 2. RESUMO PIM POR MÁQUINA E POR TURNO
-- ============================================================
--
-- Ao terminar um turno, o Ignition gravará 12 linhas nesta
-- tabela: uma linha por máquina da célula.
--
-- Os índices de OEE não são armazenados diretamente.
-- Eles serão calculados pela view para evitar inconsistências.
--
-- Campos futuros:
-- principal_motivo_parada e maior_parada_s já ficam disponíveis
-- para a etapa posterior do projeto.
-- ============================================================

CREATE TABLE IF NOT EXISTS pim_turno_maquina (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    turno_id BIGINT UNSIGNED NOT NULL,

    maquina TINYINT UNSIGNED NOT NULL,

    operador VARCHAR(40),
    numero_op VARCHAR(40),

    processo VARCHAR(80),

    tempo_ligada_s INT UNSIGNED NOT NULL DEFAULT 0,
    tempo_produzindo_s INT UNSIGNED NOT NULL DEFAULT 0,
    tempo_parada_s INT UNSIGNED NOT NULL DEFAULT 0,
    tempo_bloqueada_s INT UNSIGNED NOT NULL DEFAULT 0,

    operacoes_finalizadas INT UNSIGNED NOT NULL DEFAULT 0,
    operacoes_boas INT UNSIGNED NOT NULL DEFAULT 0,
    operacoes_reprovadas INT UNSIGNED NOT NULL DEFAULT 0,

    pecas_produzidas_ciclo INT UNSIGNED NOT NULL DEFAULT 0,
    pecas_estipuladas_ciclo INT UNSIGNED NOT NULL DEFAULT 0,

    tempo_ideal_ciclo_ms INT UNSIGNED NOT NULL DEFAULT 0,

    principal_motivo_parada VARCHAR(80) DEFAULT NULL,
    maior_parada_s INT UNSIGNED NOT NULL DEFAULT 0,

    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY uk_turno_maquina (
        turno_id,
        maquina
    ),

    KEY idx_pim_maquina (
        maquina
    ),

    CONSTRAINT fk_pim_turno
        FOREIGN KEY (turno_id)
        REFERENCES turnos_producao(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


-- ============================================================
-- 3. VIEW PRONTA PARA O RELATÓRIO PIM
-- ============================================================
--
-- Fórmulas utilizadas:
--
-- Disponibilidade =
-- tempo_produzindo_s / tempo_ligada_s
--
-- Performance =
-- pecas_produzidas_ciclo / pecas_estipuladas_ciclo
--
-- Qualidade =
-- operacoes_boas / operacoes_finalizadas
--
-- OEE =
-- disponibilidade × performance × qualidade
--
-- A performance bruta é mantida para análise.
-- A performance usada no OEE é limitada a 100%.
-- ============================================================

CREATE OR REPLACE VIEW vw_relatorio_pim_turno AS
SELECT
    t.id AS turno_id,
    t.turno_codigo,
    t.celula,
    t.data_inicio,
    t.data_fim,
    t.status,

    p.maquina,
    p.operador,
    p.numero_op,
    p.processo,

    p.tempo_ligada_s,
    p.tempo_produzindo_s,
    p.tempo_parada_s,
    p.tempo_bloqueada_s,

    p.operacoes_finalizadas,
    p.operacoes_boas,
    p.operacoes_reprovadas,

    p.pecas_produzidas_ciclo,
    p.pecas_estipuladas_ciclo,

    p.tempo_ideal_ciclo_ms,

    p.principal_motivo_parada,
    p.maior_parada_s,

    ROUND(
        100.0
        * p.tempo_produzindo_s
        / NULLIF(p.tempo_ligada_s, 0),
        2
    ) AS disponibilidade_pct,

    ROUND(
        100.0
        * p.pecas_produzidas_ciclo
        / NULLIF(p.pecas_estipuladas_ciclo, 0),
        2
    ) AS performance_bruta_pct,

    ROUND(
        LEAST(
            100.0,
            100.0
            * p.pecas_produzidas_ciclo
            / NULLIF(p.pecas_estipuladas_ciclo, 0)
        ),
        2
    ) AS performance_pct,

    ROUND(
        100.0
        * p.operacoes_boas
        / NULLIF(p.operacoes_finalizadas, 0),
        2
    ) AS qualidade_pct,

    ROUND(
        100.0
        *
        LEAST(
            1.0,
            1.0
            * p.tempo_produzindo_s
            / NULLIF(p.tempo_ligada_s, 0)
        )
        *
        LEAST(
            1.0,
            1.0
            * p.pecas_produzidas_ciclo
            / NULLIF(p.pecas_estipuladas_ciclo, 0)
        )
        *
        LEAST(
            1.0,
            1.0
            * p.operacoes_boas
            / NULLIF(p.operacoes_finalizadas, 0)
        ),
        2
    ) AS oee_pct

FROM turnos_producao t

INNER JOIN pim_turno_maquina p
    ON p.turno_id = t.id;


-- ============================================================
-- 4. VIEW AUXILIAR PARA LISTAR OS TURNOS DISPONÍVEIS
-- ============================================================
--
-- Útil para preencher um dropdown no Ignition Designer.
-- ============================================================

CREATE OR REPLACE VIEW vw_turnos_disponiveis AS
SELECT
    t.id AS turno_id,
    t.turno_codigo,
    t.celula,
    t.data_inicio,
    t.data_fim,
    t.status,

    COUNT(p.id) AS maquinas_registradas

FROM turnos_producao t

LEFT JOIN pim_turno_maquina p
    ON p.turno_id = t.id

GROUP BY
    t.id,
    t.turno_codigo,
    t.celula,
    t.data_inicio,
    t.data_fim,
    t.status;
    
    
    SHOW tables;








