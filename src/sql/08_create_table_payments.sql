USE ETL;
GO

-- =====================================================
-- FACT_PAYMENTS
-- =====================================================

IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'fact_payments'
    AND schema_id = SCHEMA_ID('dwh')
)
BEGIN
    CREATE TABLE dwh.fact_payments
    (
        -- Surrogate Key
        payment_sk              BIGINT IDENTITY(1,1) NOT NULL,
        
        -- Business Keys
        payment_id              INT NOT NULL,
        transaction_id          VARCHAR(100) NOT NULL,
        
        -- Foreign Keys
        booking_sk              BIGINT NOT NULL,
        user_sk                 BIGINT NOT NULL,
        payment_date_sk         INT NOT NULL,
        
        -- Facts (measures)
        amount                  DECIMAL(12,2) NOT NULL,
        payment_method          VARCHAR(30) NOT NULL,   -- credit_card, debit_card, pix, paypal, bank_transfer
        installments            TINYINT NOT NULL DEFAULT 1,
        fee_amount              DECIMAL(10,2) NOT NULL DEFAULT 0,
        net_amount              DECIMAL(12,2) NOT NULL,
        
        -- Status
        payment_status          VARCHAR(20) NOT NULL,   -- pending, paid, refunded, failed
        refund_date             DATE NULL,
        refund_amount           DECIMAL(12,2) NULL,
        
        -- Audit
        created_at              DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        -- Constraints
        CONSTRAINT PK_fact_payments PRIMARY KEY CLUSTERED (payment_sk),
        CONSTRAINT UQ_fact_payments_payment_id UNIQUE (payment_id),
        CONSTRAINT UQ_fact_payments_transaction UNIQUE (transaction_id),
        CONSTRAINT FK_fact_payments_booking FOREIGN KEY (booking_sk) REFERENCES dwh.fact_bookings(booking_sk),
        CONSTRAINT FK_fact_payments_user FOREIGN KEY (user_sk) REFERENCES dwh.dim_users(user_sk),
        CONSTRAINT FK_fact_payments_date FOREIGN KEY (payment_date_sk) REFERENCES dwh.dim_dates(date_sk),
        CONSTRAINT CHK_fact_payments_amount CHECK (amount >= 0),
        CONSTRAINT CHK_fact_payments_status CHECK (payment_status IN ('pending', 'paid', 'refunded', 'failed'))
    );
END
GO

-- Índices
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_payments_booking_sk')
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_payments_booking_sk
        ON dwh.fact_payments(booking_sk);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_payments_user_sk')
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_payments_user_sk
        ON dwh.fact_payments(user_sk);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_payments_date')
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_payments_date
        ON dwh.fact_payments(payment_date_sk, payment_status)
        INCLUDE (amount);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_fact_payments_status')
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_payments_status
        ON dwh.fact_payments(payment_status);
END
GO

PRINT '✅ fact_payments created successfully!';
GO