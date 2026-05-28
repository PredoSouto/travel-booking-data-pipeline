IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'ETL')
BEGIN
    CREATE DATABASE ETL;
END
GO

USE ETL;
GO

-- =====================================================
-- DROPS (ordem: FK → TABLE → SEQUENCE → SCHEMA)
-- Obs: índices e constraints são removidos automaticamente
--      junto com o DROP TABLE, não precisam ser dropados
--      explicitamente quando a tabela será recriada.
-- =====================================================

-- 1. FKs de fact_bookings (dependem de outras tabelas)
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_fact_bookings_user')
    ALTER TABLE dwh.fact_bookings DROP CONSTRAINT FK_fact_bookings_user;

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_fact_bookings_checkin')
    ALTER TABLE dwh.fact_bookings DROP CONSTRAINT FK_fact_bookings_checkin;

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_fact_bookings_checkout')
    ALTER TABLE dwh.fact_bookings DROP CONSTRAINT FK_fact_bookings_checkout;

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_fact_bookings_created')
    ALTER TABLE dwh.fact_bookings DROP CONSTRAINT FK_fact_bookings_created;
GO

-- 2. Tabela fact_bookings
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'fact_bookings'
           AND schema_id = SCHEMA_ID('dwh'))
    DROP TABLE dwh.fact_bookings;
GO

-- 3. Tabelas dim (fact_bookings já foi dropada, FKs não bloqueiam mais)
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_users'
           AND schema_id = SCHEMA_ID('dwh'))
    DROP TABLE dwh.dim_users;

IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_dates'
           AND schema_id = SCHEMA_ID('dwh'))
    DROP TABLE dwh.dim_dates;
GO

-- 4. Tabelas de controle ETL
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'etl_batch_log'
           AND schema_id = SCHEMA_ID('dwh'))
    DROP TABLE dwh.etl_batch_log;

IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'etl_error_log'
           AND schema_id = SCHEMA_ID('dwh'))
    DROP TABLE dwh.etl_error_log;

IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'etl_control'
           AND schema_id = SCHEMA_ID('dwh'))
    DROP TABLE dwh.etl_control;
GO

-- 5. Sequence
IF EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_etl_batch'
           AND SCHEMA_NAME(schema_id) = 'dwh')
    DROP SEQUENCE dwh.seq_etl_batch;
GO

-- 6. Schemas
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    DROP SCHEMA staging;

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ods')
    DROP SCHEMA ods;

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dwh')
    DROP SCHEMA dwh;
GO

-- =====================================================
-- CREATES
-- =====================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
BEGIN
    EXEC('CREATE SCHEMA staging');
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ods')
BEGIN
    EXEC('CREATE SCHEMA ods');
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dwh')
BEGIN
    EXEC('CREATE SCHEMA dwh');
END
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.sequences
    WHERE name = 'seq_etl_batch'
    AND SCHEMA_NAME(schema_id) = 'dwh'
)
BEGIN
    CREATE SEQUENCE dwh.seq_etl_batch
        AS BIGINT
        START WITH 1
        INCREMENT BY 1
        CACHE 50;
END
GO