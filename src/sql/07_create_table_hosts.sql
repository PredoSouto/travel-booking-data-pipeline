USE ETL;
GO

-- =====================================================
-- DIM_HOSTS (SCD Tipo 2)
-- =====================================================

IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'dim_hosts'
    AND schema_id = SCHEMA_ID('dwh')
)
BEGIN
    CREATE TABLE dwh.dim_hosts
    (
        -- Surrogate Key
        host_sk                 BIGINT IDENTITY(1,1) NOT NULL,
        
        -- Business Key
        host_id                 INT NOT NULL,
        host_uuid               UNIQUEIDENTIFIER NOT NULL,
        
        -- Attributes
        full_name               NVARCHAR(150) NOT NULL,
        email                   NVARCHAR(320) NOT NULL,
        phone                   VARCHAR(20) NULL,
        host_since              DATE NOT NULL,
        host_location           NVARCHAR(200) NULL,
        response_rate           TINYINT NULL,        -- 0-100
        response_time           VARCHAR(30) NULL,    -- within_an_hour, within_a_day, etc.
        is_superhost            BIT NOT NULL DEFAULT 0,
        
        -- Metrics
        total_listings          INT NOT NULL DEFAULT 0,
        total_reviews_received  INT NOT NULL DEFAULT 0,
        average_rating          DECIMAL(3,2) NULL,
        
        -- SCD Type 2 Control
        valid_from              DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        valid_to                DATETIME2(0) NOT NULL DEFAULT '9999-12-31 23:59:59',
        is_current              BIT NOT NULL DEFAULT 1,
        version_number          INT NOT NULL DEFAULT 1,
        
        -- Audit
        created_at              DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        created_by              VARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
        updated_at              DATETIME2(0) NULL,
        updated_by              VARCHAR(100) NULL,
        
        -- Constraints
        CONSTRAINT PK_dim_hosts PRIMARY KEY CLUSTERED (host_sk),
        CONSTRAINT UQ_dim_hosts_natural_key UNIQUE (host_id, valid_from),
        CONSTRAINT UQ_dim_hosts_uuid UNIQUE (host_uuid),
        CONSTRAINT CHK_dim_hosts_response_rate CHECK (response_rate BETWEEN 0 AND 100),
        CONSTRAINT CHK_dim_hosts_response_time CHECK (response_time IN ('within_an_hour', 'within_a_few_hours', 'within_a_day', 'within_a_week'))
    );
END
GO

-- Índices
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_dim_hosts_current')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_dim_hosts_current
        ON dwh.dim_hosts(host_id)
        WHERE is_current = 1;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_dim_hosts_email')
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_hosts_email
        ON dwh.dim_hosts(email);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_dim_hosts_superhost')
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_hosts_superhost
        ON dwh.dim_hosts(is_superhost)
        INCLUDE (total_listings, average_rating);
END
GO

PRINT '✅ dim_hosts created successfully!';
GO