USE ETL;
GO

-- =====================================================
-- STAGING TABLES (para carga de dados)
-- =====================================================

-- Staging: Usuários
IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'tb_user'
    AND schema_id = SCHEMA_ID('staging')
)
BEGIN
    CREATE TABLE staging.tb_user
    (
        user_id             INT NOT NULL,
        user_uuid           UNIQUEIDENTIFIER NOT NULL,
        full_name           NVARCHAR(150) NOT NULL,
        email               NVARCHAR(320) NOT NULL,
        phone               VARCHAR(20) NULL,
        country             NVARCHAR(100) NULL,
        city                NVARCHAR(100) NULL,
        user_type           VARCHAR(20) NOT NULL,
        is_verified         BIT NOT NULL DEFAULT 0,
        total_spent         DECIMAL(18,2) NOT NULL DEFAULT 0,
        total_bookings      INT NOT NULL DEFAULT 0,
        last_login          DATETIME2(0) NULL,
        loaded_at           DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        CONSTRAINT PK_staging_tb_user PRIMARY KEY (user_id)
    );
    PRINT '✅ staging.tb_user created successfully!';
END
GO

-- Staging: Propriedades
IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'tb_property'
    AND schema_id = SCHEMA_ID('staging')
)
BEGIN
    CREATE TABLE staging.tb_property
    (
        property_id         INT NOT NULL,
        property_uuid       UNIQUEIDENTIFIER NOT NULL,
        host_id             INT NOT NULL,
        title               NVARCHAR(200) NOT NULL,
        description         NVARCHAR(MAX) NULL,
        property_type       VARCHAR(50) NOT NULL,
        room_type           VARCHAR(30) NOT NULL,
        accommodates        TINYINT NOT NULL,
        bedrooms            TINYINT NULL,
        bathrooms           TINYINT NULL,
        city                NVARCHAR(100) NOT NULL,
        state               CHAR(2) NULL,
        country             NVARCHAR(100) NOT NULL,
        latitude            DECIMAL(10,8) NULL,
        longitude           DECIMAL(11,8) NULL,
        price_per_night     DECIMAL(10,2) NOT NULL,
        cleaning_fee        DECIMAL(10,2) NOT NULL DEFAULT 0,
        loaded_at           DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        CONSTRAINT PK_staging_tb_property PRIMARY KEY (property_id)
    );
    PRINT '✅ staging.tb_property created successfully!';
END
GO

-- Staging: Reservas
IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'tb_booking'
    AND schema_id = SCHEMA_ID('staging')
)
BEGIN
    CREATE TABLE staging.tb_booking
    (
        booking_id          BIGINT NOT NULL,
        booking_uuid        UNIQUEIDENTIFIER NOT NULL,
        user_id             INT NOT NULL,
        property_id         INT NOT NULL,
        checkin_date        DATE NOT NULL,
        checkout_date       DATE NOT NULL,
        number_of_nights    SMALLINT NOT NULL,
        number_of_guests    TINYINT NOT NULL,
        subtotal            DECIMAL(12,2) NOT NULL,
        cleaning_fee        DECIMAL(12,2) NOT NULL,
        service_fee         DECIMAL(12,2) NOT NULL DEFAULT 0,
        total_price         DECIMAL(12,2) NOT NULL,
        booking_status      VARCHAR(20) NOT NULL,
        cancellation_date   DATE NULL,
        created_date        DATE NOT NULL,
        loaded_at           DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        CONSTRAINT PK_staging_tb_booking PRIMARY KEY (booking_id)
    );
    PRINT '✅ staging.tb_booking created successfully!';
END
GO

-- Staging: Pagamentos
IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'tb_payment'
    AND schema_id = SCHEMA_ID('staging')
)
BEGIN
    CREATE TABLE staging.tb_payment
    (
        payment_id          INT NOT NULL,
        transaction_id      VARCHAR(100) NOT NULL,
        booking_id          BIGINT NOT NULL,
        user_id             INT NOT NULL,
        amount              DECIMAL(12,2) NOT NULL,
        payment_method      VARCHAR(30) NOT NULL,
        installments        TINYINT NOT NULL DEFAULT 1,
        payment_status      VARCHAR(20) NOT NULL,
        payment_date        DATE NOT NULL,
        loaded_at           DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        CONSTRAINT PK_staging_tb_payment PRIMARY KEY (payment_id),
        CONSTRAINT UQ_staging_tb_payment_transaction UNIQUE (transaction_id)
    );
    PRINT '✅ staging.tb_payment created successfully!';
END
GO

PRINT '✅ All staging tables created successfully!';
GO