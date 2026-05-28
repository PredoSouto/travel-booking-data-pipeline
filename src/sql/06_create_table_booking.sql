USE ETL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'fact_bookings'
    AND schema_id = SCHEMA_ID('dwh')
)
BEGIN
    CREATE TABLE dwh.fact_bookings
    (
        booking_sk              BIGINT IDENTITY(1,1) NOT NULL,
        booking_id              BIGINT NOT NULL,
        booking_uuid            UNIQUEIDENTIFIER NOT NULL,

        user_sk                 BIGINT NOT NULL,
        property_sk             BIGINT NOT NULL,

        checkin_date_sk         INT NOT NULL,
        checkout_date_sk        INT NOT NULL,
        created_date_sk         INT NOT NULL,

        number_of_nights        SMALLINT NOT NULL,
        number_of_guests        TINYINT NOT NULL,

        subtotal                DECIMAL(12,2) NOT NULL,
        cleaning_fee            DECIMAL(12,2) NOT NULL,
        service_fee             DECIMAL(12,2) NOT NULL DEFAULT 0,
        total_price             DECIMAL(12,2) NOT NULL,

        booking_status          VARCHAR(20) NOT NULL,
        cancellation_date       DATE NULL,
        cancellation_reason     VARCHAR(200) NULL,

        created_at              DATETIME2(0) NOT NULL
            CONSTRAINT DF_fact_bookings_created_at DEFAULT SYSDATETIME(),
        updated_at              DATETIME2(0) NULL,

        -- Constraints
        CONSTRAINT PK_fact_bookings
            PRIMARY KEY NONCLUSTERED (booking_sk),

        CONSTRAINT UQ_fact_bookings_booking_id
            UNIQUE (booking_id),

        -- Foreign Keys
        CONSTRAINT FK_fact_bookings_user
            FOREIGN KEY (user_sk) REFERENCES dwh.dim_users(user_sk),

        CONSTRAINT FK_fact_bookings_property
            FOREIGN KEY (property_sk) REFERENCES dwh.dim_properties(property_sk),

        CONSTRAINT FK_fact_bookings_checkin
            FOREIGN KEY (checkin_date_sk) REFERENCES dwh.dim_dates(date_sk),

        CONSTRAINT FK_fact_bookings_checkout
            FOREIGN KEY (checkout_date_sk) REFERENCES dwh.dim_dates(date_sk),

        CONSTRAINT FK_fact_bookings_created
            FOREIGN KEY (created_date_sk) REFERENCES dwh.dim_dates(date_sk),

        CONSTRAINT CHK_fact_bookings_nights
            CHECK (number_of_nights >= 1),

        CONSTRAINT CHK_fact_bookings_total_price
            CHECK (total_price >= 0),

        CONSTRAINT CHK_fact_bookings_status
            CHECK (booking_status IN ('pending','confirmed','cancelled','completed','no_show'))
    );
END
GO

-- =====================================================
-- VERIFICA SE A TABELA EXISTE ANTES DE CRIAR ÍNDICES
-- =====================================================

IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'fact_bookings' AND schema_id = SCHEMA_ID('dwh'))
BEGIN
    -- =====================================================
    -- CLUSTERED COLUMNSTORE INDEX
    -- =====================================================
    
    -- Remove clustered index existente (se houver e não for o CCI)
    DECLARE @clustered_name NVARCHAR(200);

    SELECT @clustered_name = i.name
    FROM sys.indexes i
    WHERE i.object_id = OBJECT_ID('dwh.fact_bookings')
      AND i.type = 1
      AND i.name IS NOT NULL
      AND i.name NOT LIKE 'CCI[_]%';

    IF @clustered_name IS NOT NULL
    BEGIN
        DECLARE @drop_sql NVARCHAR(500) = 
            'DROP INDEX ' + QUOTENAME(@clustered_name) + ' ON dwh.fact_bookings;';
        EXEC sp_executesql @drop_sql;
    END

    -- Cria Columnstore Index como clustered
    CREATE CLUSTERED COLUMNSTORE INDEX CCI_fact_bookings
        ON dwh.fact_bookings;
    
    -- =====================================================
    -- NON-CLUSTERED INDEXES
    -- =====================================================
    
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_bookings_user')
    BEGIN
        CREATE NONCLUSTERED INDEX IX_fact_bookings_user
            ON dwh.fact_bookings(user_sk, checkin_date_sk)
            INCLUDE (total_price, booking_status);
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_bookings_property')
    BEGIN
        CREATE NONCLUSTERED INDEX IX_fact_bookings_property
            ON dwh.fact_bookings(property_sk, checkin_date_sk)
            INCLUDE (total_price);
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_bookings_status')
    BEGIN
        CREATE NONCLUSTERED INDEX IX_fact_bookings_status
            ON dwh.fact_bookings(booking_status, checkin_date_sk);
    END

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_bookings_checkin')
    BEGIN
        CREATE NONCLUSTERED INDEX IX_fact_bookings_checkin
            ON dwh.fact_bookings(checkin_date_sk, booking_status)
            INCLUDE (total_price);
    END

    PRINT '✅ fact_bookings created successfully!';
END
ELSE
BEGIN
    PRINT '❌ fact_bookings table was not created. Check previous errors.';
END
GO