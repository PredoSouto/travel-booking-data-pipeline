USE ETL;
GO

-- =====================================================
-- DIM_PROPERTIES (executar antes de fact_bookings)
-- =====================================================

IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'dim_properties'
    AND schema_id = SCHEMA_ID('dwh')
)
BEGIN
    CREATE TABLE dwh.dim_properties
    (
        -- Surrogate Key
        property_sk             BIGINT IDENTITY(1,1) NOT NULL,
        
        -- Business Keys
        property_id             INT NOT NULL,
        property_uuid           UNIQUEIDENTIFIER NOT NULL,
        
        -- Foreign Key para host (se tiver)
        host_sk                 BIGINT NULL,
        
        -- Attributes
        title                   NVARCHAR(200) NOT NULL,
        description             NVARCHAR(MAX) NULL,
        property_type           VARCHAR(50) NOT NULL,
        room_type               VARCHAR(30) NOT NULL,
        accommodates            TINYINT NOT NULL,
        bedrooms                TINYINT NULL,
        bathrooms               TINYINT NULL,
        
        -- Location
        city                    NVARCHAR(100) NOT NULL,
        state                   CHAR(2) NULL,
        country                 NVARCHAR(100) NOT NULL,
        latitude                DECIMAL(10,8) NULL,
        longitude               DECIMAL(11,8) NULL,
        
        -- Pricing
        price_per_night         DECIMAL(10,2) NOT NULL,
        cleaning_fee            DECIMAL(10,2) NOT NULL DEFAULT 0,
        
        -- SCD Control (Tipo 2)
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
        CONSTRAINT PK_dim_properties PRIMARY KEY CLUSTERED (property_sk),
        CONSTRAINT UQ_dim_properties_natural_key UNIQUE (property_id, valid_from),
        CONSTRAINT UQ_dim_properties_uuid UNIQUE (property_uuid),
        CONSTRAINT CHK_dim_properties_price CHECK (price_per_night > 0)
    );
END
GO

-- Índices
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_dim_properties_current')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_dim_properties_current
        ON dwh.dim_properties(property_id)
        WHERE is_current = 1;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_dim_properties_city')
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_properties_city
        ON dwh.dim_properties(city, country)
        WHERE is_current = 1;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_dim_properties_type')
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_properties_type
        ON dwh.dim_properties(property_type, accommodates)
        INCLUDE (price_per_night);
END
GO

PRINT '✅ dim_properties created successfully!';
GO