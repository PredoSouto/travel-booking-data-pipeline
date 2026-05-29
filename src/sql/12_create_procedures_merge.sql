USE ETL;
GO

-- =====================================================
-- STORED PROCEDURE: sp_merge_dim_users (CORRIGIDA)
-- Descrição: SCD Tipo 2 para tabela de usuários
-- =====================================================

CREATE OR ALTER PROCEDURE dwh.sp_merge_dim_users
    @dry_run BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @batch_id BIGINT = NEXT VALUE FOR dwh.seq_etl_batch;
    DECLARE @start_time DATETIME2(0) = SYSDATETIME();
    DECLARE @rows_affected BIGINT = 0;
    DECLARE @rows_inserted BIGINT = 0;
    DECLARE @rows_updated BIGINT = 0;
    
    BEGIN TRY
        -- Modo Dry Run: apenas preview
        IF @dry_run = 1
        BEGIN
            -- Usuários que seriam atualizados (mudanças detectadas)
            SELECT 
                'would_update' AS action,
                s.user_id,
                s.full_name,
                s.user_type AS new_user_type,
                d.user_type AS old_user_type,
                s.city AS new_city,
                d.city AS old_city,
                'Attributes changed' AS reason
            FROM staging.tb_user s
            INNER JOIN dwh.dim_users d
                ON s.user_id = d.user_id AND d.is_current = 1
            WHERE 
                s.user_type != d.user_type
                OR ISNULL(s.country, '') != ISNULL(d.country, '')
                OR ISNULL(s.city, '') != ISNULL(d.city, '')
                OR ISNULL(s.phone, '') != ISNULL(d.phone, '');
            
            -- Usuários que seriam inseridos (novos)
            SELECT 
                'would_insert' AS action,
                s.*
            FROM staging.tb_user s
            WHERE NOT EXISTS (
                SELECT 1 FROM dwh.dim_users d
                WHERE d.user_id = s.user_id AND d.is_current = 1
            );
            
            RETURN;
        END
        
        -- Modo Produção
        BEGIN TRANSACTION;
        
        -- 1. Fechar registros alterados (atualizar is_current = 0)
        UPDATE target
        SET 
            is_current = 0,
            valid_to = SYSDATETIME(),
            updated_at = SYSDATETIME(),
            updated_by = SYSTEM_USER
        FROM dwh.dim_users target
        INNER JOIN staging.tb_user source
            ON target.user_id = source.user_id
            AND target.is_current = 1
        WHERE 
            target.user_type != source.user_type
            OR ISNULL(target.country, '') != ISNULL(source.country, '')
            OR ISNULL(target.city, '') != ISNULL(source.city, '')
            OR ISNULL(target.phone, '') != ISNULL(source.phone, '');
        
        SET @rows_updated = @@ROWCOUNT;
        
        -- 2. Inserir novas versões (registros atualizados) e novos usuários
        INSERT INTO dwh.dim_users (
            user_id,
            user_uuid,
            full_name,
            email,
            phone,
            country,
            city,
            user_type,
            is_verified,
            total_spent,
            total_bookings,
            last_login,
            attribute_hash,
            valid_from,
            valid_to,
            is_current,
            version_number,
            created_at,
            created_by,
            updated_at,
            updated_by
        )
        SELECT 
            s.user_id,
            s.user_uuid,
            s.full_name,
            s.email,
            s.phone,
            s.country,
            s.city,
            s.user_type,
            s.is_verified,
            s.total_spent,
            s.total_bookings,
            s.last_login,
            HASHBYTES('SHA2_256', 
                CONCAT(ISNULL(s.user_type,''), ISNULL(s.country,''), ISNULL(s.city,''), ISNULL(s.phone,''))
            ) AS attribute_hash,
            SYSDATETIME() AS valid_from,
            '9999-12-31 23:59:59' AS valid_to,
            1 AS is_current,
            ISNULL(prev.version_number, 0) + 1 AS version_number,
            SYSDATETIME() AS created_at,
            SYSTEM_USER AS created_by,
            NULL AS updated_at,
            NULL AS updated_by
        FROM staging.tb_user s
        LEFT JOIN dwh.dim_users prev
            ON s.user_id = prev.user_id
            AND prev.is_current = 0
            AND prev.version_number = (
                SELECT MAX(version_number)
                FROM dwh.dim_users
                WHERE user_id = s.user_id
            )
        WHERE NOT EXISTS (
            -- Novo usuário
            SELECT 1 FROM dwh.dim_users cur
            WHERE cur.user_id = s.user_id AND cur.is_current = 1
        )
        OR EXISTS (
            -- Usuário com mudança
            SELECT 1 FROM dwh.dim_users cur
            WHERE cur.user_id = s.user_id
                AND cur.is_current = 1
                AND (
                    cur.user_type != s.user_type
                    OR ISNULL(cur.country, '') != ISNULL(s.country, '')
                    OR ISNULL(cur.city, '') != ISNULL(s.city, '')
                    OR ISNULL(cur.phone, '') != ISNULL(s.phone, '')
                )
        );
        
        SET @rows_inserted = @@ROWCOUNT;
        SET @rows_affected = @rows_updated + @rows_inserted;
        
        -- Log do batch
        INSERT INTO dwh.etl_batch_log (
            batch_id,
            table_name,
            operation_type,
            rows_affected,
            start_time,
            end_time,
            created_by
        )
        VALUES (
            @batch_id,
            'dim_users',
            'MERGE_SCD2',
            @rows_affected,
            @start_time,
            SYSDATETIME(),
            SYSTEM_USER
        );
        
        COMMIT TRANSACTION;
        
        -- Retorno de sucesso
        SELECT 
            @batch_id AS batch_id,
            @rows_updated AS rows_updated,
            @rows_inserted AS rows_inserted,
            @rows_affected AS total_rows_processed,
            'SUCCESS' AS status;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Log do erro
        INSERT INTO dwh.etl_error_log (
            batch_id,
            error_number,
            error_severity,
            error_state,
            error_line,
            error_procedure,
            error_message
        )
        VALUES (
            @batch_id,
            ERROR_NUMBER(),
            ERROR_SEVERITY(),
            ERROR_STATE(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            ERROR_MESSAGE()
        );
        
        -- Relançar o erro
        THROW;
    END CATCH
END
GO

-- =====================================================
-- STORED PROCEDURE: sp_merge_dim_hosts (CORRIGIDA)
-- =====================================================

CREATE OR ALTER PROCEDURE dwh.sp_merge_dim_hosts
    @dry_run BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @batch_id BIGINT = NEXT VALUE FOR dwh.seq_etl_batch;
    DECLARE @start_time DATETIME2(0) = SYSDATETIME();
    DECLARE @rows_affected BIGINT = 0;
    DECLARE @rows_inserted BIGINT = 0;
    DECLARE @rows_updated BIGINT = 0;
    
    BEGIN TRY
        IF @dry_run = 1
        BEGIN
            SELECT 
                'would_update' AS action,
                s.host_id,
                s.full_name,
                s.is_superhost AS new_superhost,
                d.is_superhost AS old_superhost,
                s.response_rate AS new_rate,
                d.response_rate AS old_rate
            FROM staging.tb_host s
            INNER JOIN dwh.dim_hosts d
                ON s.host_id = d.host_id AND d.is_current = 1
            WHERE 
                s.is_superhost != d.is_superhost
                OR ISNULL(s.response_rate, 0) != ISNULL(d.response_rate, 0)
                OR ISNULL(s.host_location, '') != ISNULL(d.host_location, '');
            
            SELECT 
                'would_insert' AS action,
                s.*
            FROM staging.tb_host s
            WHERE NOT EXISTS (
                SELECT 1 FROM dwh.dim_hosts d
                WHERE d.host_id = s.host_id AND d.is_current = 1
            );
            
            RETURN;
        END
        
        BEGIN TRANSACTION;
        
        UPDATE target
        SET 
            is_current = 0,
            valid_to = SYSDATETIME(),
            updated_at = SYSDATETIME(),
            updated_by = SYSTEM_USER
        FROM dwh.dim_hosts target
        INNER JOIN staging.tb_host source
            ON target.host_id = source.host_id
            AND target.is_current = 1
        WHERE 
            target.is_superhost != source.is_superhost
            OR ISNULL(target.response_rate, 0) != ISNULL(source.response_rate, 0)
            OR ISNULL(target.host_location, '') != ISNULL(source.host_location, '');
        
        SET @rows_updated = @@ROWCOUNT;
        
        INSERT INTO dwh.dim_hosts (
            host_id,
            host_uuid,
            full_name,
            email,
            phone,
            host_since,
            host_location,
            response_rate,
            response_time,
            is_superhost,
            total_listings,
            total_reviews_received,
            average_rating,
            valid_from,
            valid_to,
            is_current,
            version_number,
            created_at,
            created_by
        )
        SELECT 
            s.host_id,
            s.host_uuid,
            s.full_name,
            s.email,
            s.phone,
            s.host_since,
            s.host_location,
            s.response_rate,
            s.response_time,
            s.is_superhost,
            s.total_listings,
            s.total_reviews_received,
            s.average_rating,
            SYSDATETIME(),
            '9999-12-31 23:59:59',
            1,
            ISNULL(prev.version_number, 0) + 1,
            SYSDATETIME(),
            SYSTEM_USER
        FROM staging.tb_host s
        LEFT JOIN dwh.dim_hosts prev
            ON s.host_id = prev.host_id
            AND prev.is_current = 0
            AND prev.version_number = (
                SELECT MAX(version_number)
                FROM dwh.dim_hosts
                WHERE host_id = s.host_id
            )
        WHERE NOT EXISTS (
            SELECT 1 FROM dwh.dim_hosts cur
            WHERE cur.host_id = s.host_id AND cur.is_current = 1
        )
        OR EXISTS (
            SELECT 1 FROM dwh.dim_hosts cur
            WHERE cur.host_id = s.host_id
                AND cur.is_current = 1
                AND (
                    cur.is_superhost != s.is_superhost
                    OR ISNULL(cur.response_rate, 0) != ISNULL(s.response_rate, 0)
                )
        );
        
        SET @rows_inserted = @@ROWCOUNT;
        SET @rows_affected = @rows_updated + @rows_inserted;
        
        INSERT INTO dwh.etl_batch_log (
            batch_id, table_name, operation_type, rows_affected,
            start_time, end_time, created_by
        )
        VALUES (
            @batch_id, 'dim_hosts', 'MERGE_SCD2', @rows_affected,
            @start_time, SYSDATETIME(), SYSTEM_USER
        );
        
        COMMIT TRANSACTION;
        
        SELECT 
            @batch_id AS batch_id,
            @rows_updated AS rows_updated,
            @rows_inserted AS rows_inserted,
            @rows_affected AS total_rows_processed,
            'SUCCESS' AS status;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
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

-- =====================================================
-- STORED PROCEDURE: sp_merge_dim_properties (CORRIGIDA)
-- =====================================================

CREATE OR ALTER PROCEDURE dwh.sp_merge_dim_properties
    @dry_run BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @batch_id BIGINT = NEXT VALUE FOR dwh.seq_etl_batch;
    DECLARE @start_time DATETIME2(0) = SYSDATETIME();
    DECLARE @rows_affected BIGINT = 0;
    DECLARE @rows_inserted BIGINT = 0;
    DECLARE @rows_updated BIGINT = 0;
    
    BEGIN TRY
        IF @dry_run = 1
        BEGIN
            SELECT 
                'would_update' AS action,
                s.property_id,
                s.title,
                s.price_per_night AS new_price,
                d.price_per_night AS old_price,
                s.property_type AS new_type,
                d.property_type AS old_type
            FROM staging.tb_property s
            INNER JOIN dwh.dim_properties d
                ON s.property_id = d.property_id AND d.is_current = 1
            WHERE 
                s.price_per_night != d.price_per_night
                OR s.property_type != d.property_type
                OR ISNULL(s.city, '') != ISNULL(d.city, '');
            
            SELECT 
                'would_insert' AS action,
                s.*
            FROM staging.tb_property s
            WHERE NOT EXISTS (
                SELECT 1 FROM dwh.dim_properties d
                WHERE d.property_id = s.property_id AND d.is_current = 1
            );
            
            RETURN;
        END
        
        BEGIN TRANSACTION;
        
        UPDATE target
        SET 
            is_current = 0,
            valid_to = SYSDATETIME(),
            updated_at = SYSDATETIME(),
            updated_by = SYSTEM_USER
        FROM dwh.dim_properties target
        INNER JOIN staging.tb_property source
            ON target.property_id = source.property_id
            AND target.is_current = 1
        WHERE 
            target.price_per_night != source.price_per_night
            OR target.property_type != source.property_type
            OR ISNULL(target.city, '') != ISNULL(source.city, '')
            OR target.accommodates != source.accommodates;
        
        SET @rows_updated = @@ROWCOUNT;
        
        INSERT INTO dwh.dim_properties (
            property_id,
            property_uuid,
            host_sk,
            title,
            description,
            property_type,
            room_type,
            accommodates,
            bedrooms,
            bathrooms,
            city,
            state,
            country,
            latitude,
            longitude,
            price_per_night,
            cleaning_fee,
            valid_from,
            valid_to,
            is_current,
            version_number,
            created_at,
            created_by
        )
        SELECT 
            s.property_id,
            s.property_uuid,
            ISNULL(h.host_sk, -1) AS host_sk,
            s.title,
            s.description,
            s.property_type,
            s.room_type,
            s.accommodates,
            s.bedrooms,
            s.bathrooms,
            s.city,
            s.state,
            s.country,
            s.latitude,
            s.longitude,
            s.price_per_night,
            s.cleaning_fee,
            SYSDATETIME(),
            '9999-12-31 23:59:59',
            1,
            ISNULL(prev.version_number, 0) + 1,
            SYSDATETIME(),
            SYSTEM_USER
        FROM staging.tb_property s
        LEFT JOIN dwh.dim_hosts h
            ON s.host_id = h.host_id AND h.is_current = 1
        LEFT JOIN dwh.dim_properties prev
            ON s.property_id = prev.property_id
            AND prev.is_current = 0
            AND prev.version_number = (
                SELECT MAX(version_number)
                FROM dwh.dim_properties
                WHERE property_id = s.property_id
            )
        WHERE NOT EXISTS (
            SELECT 1 FROM dwh.dim_properties cur
            WHERE cur.property_id = s.property_id AND cur.is_current = 1
        )
        OR EXISTS (
            SELECT 1 FROM dwh.dim_properties cur
            WHERE cur.property_id = s.property_id
                AND cur.is_current = 1
                AND (
                    cur.price_per_night != s.price_per_night
                    OR cur.property_type != s.property_type
                )
        );
        
        SET @rows_inserted = @@ROWCOUNT;
        SET @rows_affected = @rows_updated + @rows_inserted;
        
        INSERT INTO dwh.etl_batch_log (
            batch_id, table_name, operation_type, rows_affected,
            start_time, end_time, created_by
        )
        VALUES (
            @batch_id, 'dim_properties', 'MERGE_SCD2', @rows_affected,
            @start_time, SYSDATETIME(), SYSTEM_USER
        );
        
        COMMIT TRANSACTION;
        
        SELECT 
            @batch_id AS batch_id,
            @rows_updated AS rows_updated,
            @rows_inserted AS rows_inserted,
            @rows_affected AS total_rows_processed,
            'SUCCESS' AS status;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
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

-- =====================================================
-- STORED PROCEDURE: sp_get_user_history
-- =====================================================

CREATE OR ALTER PROCEDURE dwh.sp_get_user_history
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        user_sk,
        user_id,
        full_name,
        email,
        user_type,
        country,
        city,
        valid_from,
        valid_to,
        is_current,
        version_number,
        CASE 
            WHEN version_number = 1 THEN 'INSERT'
            WHEN is_current = 1 THEN 'CURRENT'
            ELSE 'UPDATE'
        END AS change_type,
        LAG(user_type) OVER (ORDER BY valid_from) AS previous_user_type,
        LAG(country) OVER (ORDER BY valid_from) AS previous_country,
        DATEDIFF(DAY, valid_from, valid_to) AS days_valid
    FROM dwh.dim_users
    WHERE user_id = @user_id
    ORDER BY valid_from DESC;
END
GO

-- =====================================================
-- STORED PROCEDURE: sp_get_etl_summary
-- =====================================================

CREATE OR ALTER PROCEDURE dwh.sp_get_etl_summary
    @days_back INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        batch_id,
        table_name,
        operation_type,
        rows_affected,
        start_time,
        end_time,
        DATEDIFF(SECOND, start_time, end_time) AS duration_seconds,
        created_by
    FROM dwh.etl_batch_log
    WHERE start_time >= DATEADD(DAY, -@days_back, SYSDATETIME())
    ORDER BY start_time DESC;
END
GO

-- =====================================================
-- STORED PROCEDURE: sp_get_error_summary
-- =====================================================

CREATE OR ALTER PROCEDURE dwh.sp_get_error_summary
    @days_back INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        error_id,
        batch_id,
        error_number,
        error_procedure,
        error_message,
        error_timestamp,
        created_by
    FROM dwh.etl_error_log
    WHERE error_timestamp >= DATEADD(DAY, -@days_back, SYSDATETIME())
    ORDER BY error_timestamp DESC;
END
GO

PRINT 'All Stored Procedures created successfully!';
PRINT '   - dwh.sp_merge_dim_users';
PRINT '   - dwh.sp_merge_dim_hosts';
PRINT '   - dwh.sp_merge_dim_properties';
PRINT '   - dwh.sp_get_user_history';
PRINT '   - dwh.sp_get_etl_summary';
PRINT '   - dwh.sp_get_error_summary';
GO