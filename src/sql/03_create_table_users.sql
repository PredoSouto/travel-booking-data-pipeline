USE ETL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'dim_users'
    AND schema_id = SCHEMA_ID('dwh')
)
BEGIN
    CREATE TABLE dwh.dim_users
    (
        -- SURROGATE KEY
        user_sk                 BIGINT IDENTITY(1,1),

        -- BUSINESS KEY
        user_id                 INT NOT NULL,
        user_uuid               UNIQUEIDENTIFIER NOT NULL,

        -- ATTRIBUTES
        full_name               NVARCHAR(150) NOT NULL,
        email                   NVARCHAR(320) NOT NULL,
        phone                   VARCHAR(20) NULL,
        country                 NVARCHAR(100) NULL,
        city                    NVARCHAR(100) NULL,
        user_type               VARCHAR(20) NOT NULL,
        is_verified             BIT NOT NULL
            CONSTRAINT DF_dim_users_is_verified DEFAULT 0,

        -- METRICS
        total_spent             DECIMAL(18,2) NOT NULL
            CONSTRAINT DF_dim_users_total_spent DEFAULT 0,
        total_bookings          INT NOT NULL
            CONSTRAINT DF_dim_users_total_bookings DEFAULT 0,
        last_login              DATETIME2(0) NULL,

        -- HASH CONTROLE SCD
        attribute_hash          VARCHAR(64) NULL,

        -- SCD TYPE 2
        valid_from              DATETIME2(0) NOT NULL
            CONSTRAINT DF_dim_users_valid_from DEFAULT SYSDATETIME(),
        valid_to                DATETIME2(0) NOT NULL
            CONSTRAINT DF_dim_users_valid_to DEFAULT ('9999-12-31 23:59:59'),
        is_current              BIT NOT NULL
            CONSTRAINT DF_dim_users_is_current DEFAULT 1,
        version_number          INT NOT NULL
            CONSTRAINT DF_dim_users_version DEFAULT 1,

        -- AUDIT
        created_at              DATETIME2(0) NOT NULL
            CONSTRAINT DF_dim_users_created_at DEFAULT SYSDATETIME(),
        created_by              VARCHAR(100) NOT NULL
            CONSTRAINT DF_dim_users_created_by DEFAULT SYSTEM_USER,
        updated_at              DATETIME2(0) NULL,
        updated_by              VARCHAR(100) NULL,

        -- CONSTRAINTS
        CONSTRAINT PK_dim_users
            PRIMARY KEY CLUSTERED (user_sk),
        CONSTRAINT UQ_dim_users_natural_key
            UNIQUE (user_id, valid_from),
        CONSTRAINT CHK_dim_users_user_type
            CHECK (user_type IN ('standard','premium','vip')),
        CONSTRAINT CHK_dim_users_valid_dates
            CHECK (valid_from < valid_to)
    );
END
GO

-- Índices dim_users
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes WHERE name = 'UQ_dim_users_current'
    AND object_id = OBJECT_ID('dwh.dim_users')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_dim_users_current
        ON dwh.dim_users(user_id)
        WHERE is_current = 1;
END
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes WHERE name = 'IX_dim_users_email'
    AND object_id = OBJECT_ID('dwh.dim_users')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_users_email
        ON dwh.dim_users(email);
END
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes WHERE name = 'IX_dim_users_location'
    AND object_id = OBJECT_ID('dwh.dim_users')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_users_location
        ON dwh.dim_users(country, city)
        WHERE is_current = 1;
END
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes WHERE name = 'IX_dim_users_validity'
    AND object_id = OBJECT_ID('dwh.dim_users')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_users_validity
        ON dwh.dim_users(user_id, valid_from, valid_to);
END
GO