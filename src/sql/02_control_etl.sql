USE ETL;
GO

-- ETL CONTROL
IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'etl_control'
    AND schema_id = SCHEMA_ID('dwh')
)
BEGIN
    CREATE TABLE dwh.etl_control
    (
        control_id          BIGINT IDENTITY(1,1),
        process_name        VARCHAR(150) NOT NULL,
        last_execution      DATETIME2(0) NULL,
        last_success        DATETIME2(0) NULL,
        execution_status    VARCHAR(20) NULL,
        rows_processed      BIGINT NULL,
        created_at          DATETIME2(0) NOT NULL
            CONSTRAINT DF_etl_control_created_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_etl_control
            PRIMARY KEY CLUSTERED (control_id)
    );
END
GO

-- ETL BATCH LOG
IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'etl_batch_log'
    AND schema_id = SCHEMA_ID('dwh')
)
BEGIN
    CREATE TABLE dwh.etl_batch_log
    (
        log_id              BIGINT IDENTITY(1,1),
        batch_id            BIGINT NOT NULL,
        table_name          VARCHAR(150) NOT NULL,
        operation_type      VARCHAR(30) NOT NULL,
        rows_affected       BIGINT NULL,
        start_time          DATETIME2(0) NOT NULL,
        end_time            DATETIME2(0) NULL,
        created_by          VARCHAR(100) NOT NULL
            CONSTRAINT DF_etl_batch_log_created_by DEFAULT SYSTEM_USER,
        created_at          DATETIME2(0) NOT NULL
            CONSTRAINT DF_etl_batch_log_created_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_etl_batch_log
            PRIMARY KEY CLUSTERED (log_id)
    );
END
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_etl_batch_log_batch_id'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_etl_batch_log_batch_id
        ON dwh.etl_batch_log(batch_id);
END
GO

-- ETL ERROR LOG
IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'etl_error_log'
    AND schema_id = SCHEMA_ID('dwh')
)
BEGIN
    CREATE TABLE dwh.etl_error_log
    (
        error_id            BIGINT IDENTITY(1,1),
        batch_id            BIGINT NULL,
        error_number        INT NOT NULL,
        error_severity      INT NULL,
        error_state         INT NULL,
        error_line          INT NULL,
        error_procedure     VARCHAR(200) NULL,
        error_message       NVARCHAR(4000) NOT NULL,
        error_timestamp     DATETIME2(0) NOT NULL
            CONSTRAINT DF_etl_error_timestamp DEFAULT SYSDATETIME(),
        created_by          VARCHAR(100) NOT NULL
            CONSTRAINT DF_etl_error_created_by DEFAULT SYSTEM_USER,

        CONSTRAINT PK_etl_error_log
            PRIMARY KEY CLUSTERED (error_id)
    );
END
GO