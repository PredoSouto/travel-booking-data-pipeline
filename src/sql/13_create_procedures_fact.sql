USE ETL;
GO

-- =====================================================
-- STORED PROCEDURE: sp_load_fact_bookings (CORRIGIDA)
-- =====================================================
CREATE OR ALTER PROCEDURE dwh.sp_load_fact_bookings
    @dry_run BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @batch_id BIGINT = NEXT VALUE FOR dwh.seq_etl_batch;
    DECLARE @start_time DATETIME2(0) = SYSDATETIME();
    DECLARE @rows_affected BIGINT = 0;
    
    BEGIN TRY
        IF @dry_run = 1
        BEGIN
            SELECT 
                'would_insert' AS action,
                s.booking_id,
                s.booking_uuid,
                s.user_id,
                s.property_id,
                s.checkin_date,
                s.checkout_date,
                s.total_price,
                s.booking_status
            FROM staging.tb_booking s
            WHERE NOT EXISTS (
                SELECT 1 FROM dwh.fact_bookings f 
                WHERE f.booking_id = s.booking_id
            );
            RETURN;
        END
        
        BEGIN TRANSACTION;
        
        INSERT INTO dwh.fact_bookings (
            booking_id,
            booking_uuid,
            user_sk,
            property_sk,
            checkin_date_sk,
            checkout_date_sk,
            created_date_sk,
            number_of_nights,
            number_of_guests,
            subtotal,
            cleaning_fee,
            service_fee,
            total_price,
            booking_status,
            cancellation_date,
            cancellation_reason,
            created_at,
            updated_at
        )
        SELECT 
            s.booking_id,
            s.booking_uuid,
            u.user_sk,
            p.property_sk,
            d_checkin.date_sk,
            d_checkout.date_sk,
            d_created.date_sk,
            s.number_of_nights,
            s.number_of_guests,
            s.subtotal,
            s.cleaning_fee,
            s.service_fee,
            s.total_price,
            s.booking_status,
            s.cancellation_date,
            NULL AS cancellation_reason,  -- staging não tem, usar NULL
            SYSDATETIME() AS created_at,  -- data atual
            NULL AS updated_at            -- NULL inicial
        FROM staging.tb_booking s
        INNER JOIN dwh.dim_users u 
            ON s.user_id = u.user_id AND u.is_current = 1
        INNER JOIN dwh.dim_properties p 
            ON s.property_id = p.property_id AND p.is_current = 1
        INNER JOIN dwh.dim_dates d_checkin 
            ON CAST(s.checkin_date AS DATE) = d_checkin.full_date
        INNER JOIN dwh.dim_dates d_checkout 
            ON CAST(s.checkout_date AS DATE) = d_checkout.full_date
        INNER JOIN dwh.dim_dates d_created 
            ON CAST(s.created_date AS DATE) = d_created.full_date
        WHERE NOT EXISTS (
            SELECT 1 FROM dwh.fact_bookings f 
            WHERE f.booking_id = s.booking_id
        );
        
        SET @rows_affected = @@ROWCOUNT;
        
        INSERT INTO dwh.etl_batch_log (
            batch_id, table_name, operation_type, rows_affected,
            start_time, end_time, created_by
        )
        VALUES (
            @batch_id, 'fact_bookings', 'LOAD', @rows_affected,
            @start_time, SYSDATETIME(), SYSTEM_USER
        );
        
        COMMIT TRANSACTION;
        
        SELECT @batch_id AS batch_id, @rows_affected AS rows_loaded, 'SUCCESS' AS status;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        INSERT INTO dwh.etl_error_log (
            batch_id, error_number, error_severity, error_state,
            error_line, error_procedure, error_message
        )
        VALUES (
            @batch_id, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(),
            ERROR_LINE(), ERROR_PROCEDURE(), ERROR_MESSAGE()
        );
        
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_load_fact_bookings criada com sucesso!';
GO

-- =====================================================
-- STORED PROCEDURE: sp_load_fact_payments (CORRIGIDA)
-- =====================================================
CREATE OR ALTER PROCEDURE dwh.sp_load_fact_payments
    @dry_run BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @batch_id BIGINT = NEXT VALUE FOR dwh.seq_etl_batch;
    DECLARE @start_time DATETIME2(0) = SYSDATETIME();
    DECLARE @rows_affected BIGINT = 0;
    
    BEGIN TRY
        IF @dry_run = 1
        BEGIN
            SELECT 
                'would_insert' AS action,
                s.payment_id,
                s.transaction_id,
                s.booking_id,
                s.user_id,
                s.amount,
                s.payment_status,
                s.payment_date
            FROM staging.tb_payment s
            WHERE NOT EXISTS (
                SELECT 1 FROM dwh.fact_payments f 
                WHERE f.transaction_id = s.transaction_id
            );
            RETURN;
        END
        
        BEGIN TRANSACTION;
        
        INSERT INTO dwh.fact_payments (
            payment_id,
            transaction_id,
            booking_sk,
            user_sk,
            payment_date_sk,
            amount,
            payment_method,
            installments,
            fee_amount,
            net_amount,
            payment_status,
            refund_date,
            refund_amount,
            created_at
        )
        SELECT 
            s.payment_id,
            s.transaction_id,
            b.booking_sk,
            u.user_sk,
            d.date_sk,
            s.amount,
            s.payment_method,
            s.installments,
            ROUND(s.amount * 0.03, 2) AS fee_amount,
            ROUND(s.amount * 0.97, 2) AS net_amount,
            s.payment_status,
            NULL AS refund_date,
            NULL AS refund_amount,
            SYSDATETIME() AS created_at
        FROM staging.tb_payment s
        INNER JOIN dwh.fact_bookings b 
            ON s.booking_id = b.booking_id
        INNER JOIN dwh.dim_users u 
            ON s.user_id = u.user_id AND u.is_current = 1
        INNER JOIN dwh.dim_dates d 
            ON CAST(s.payment_date AS DATE) = d.full_date
        WHERE NOT EXISTS (
            SELECT 1 FROM dwh.fact_payments f 
            WHERE f.transaction_id = s.transaction_id
        );
        
        SET @rows_affected = @@ROWCOUNT;
        
        INSERT INTO dwh.etl_batch_log (
            batch_id, table_name, operation_type, rows_affected,
            start_time, end_time, created_by
        )
        VALUES (
            @batch_id, 'fact_payments', 'LOAD', @rows_affected,
            @start_time, SYSDATETIME(), SYSTEM_USER
        );
        
        COMMIT TRANSACTION;
        
        SELECT @batch_id AS batch_id, @rows_affected AS rows_loaded, 'SUCCESS' AS status;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        INSERT INTO dwh.etl_error_log (
            batch_id, error_number, error_severity, error_state,
            error_line, error_procedure, error_message
        )
        VALUES (
            @batch_id, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(),
            ERROR_LINE(), ERROR_PROCEDURE(), ERROR_MESSAGE()
        );
        
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_load_fact_payments criada com sucesso!';
GO