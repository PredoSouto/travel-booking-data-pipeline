USE ETL;
GO

-- =====================================================
-- POPULATE DIM_DATES (apenas se estiver vazia)
-- =====================================================

-- Só popula se a tabela estiver vazia
IF (SELECT COUNT(*) FROM dwh.dim_dates) = 0
BEGIN
    DECLARE @start_date DATE = '2020-01-01';
    DECLARE @end_date DATE = '2099-12-31';
    DECLARE @current_date DATE = @start_date;

    WHILE @current_date <= @end_date
    BEGIN
        INSERT INTO dwh.dim_dates
        (
            date_sk,
            full_date,
            year_number,
            quarter_number,
            semester_number,
            month_number,
            month_name,
            month_abbreviation,
            week_number,
            week_of_month,
            day_of_month,
            day_of_week,
            day_name,
            day_abbreviation,
            is_weekend,
            is_month_start,
            is_month_end,
            is_quarter_start,
            is_quarter_end,
            is_year_start,
            is_year_end,
            fiscal_year,
            fiscal_quarter
        )
        VALUES
        (
            YEAR(@current_date) * 10000 + MONTH(@current_date) * 100 + DAY(@current_date),
            @current_date,
            YEAR(@current_date),
            DATEPART(QUARTER, @current_date),
            CASE WHEN MONTH(@current_date) <= 6 THEN 1 ELSE 2 END,
            MONTH(@current_date),
            DATENAME(MONTH, @current_date),
            LEFT(DATENAME(MONTH, @current_date), 3),
            DATEPART(WEEK, @current_date),
            (DATEPART(DAY, @current_date) - 1) / 7 + 1,
            DAY(@current_date),
            DATEPART(WEEKDAY, @current_date),
            DATENAME(WEEKDAY, @current_date),
            LEFT(DATENAME(WEEKDAY, @current_date), 3),
            CASE WHEN DATEPART(WEEKDAY, @current_date) IN (1, 7) THEN 1 ELSE 0 END,
            CASE WHEN DAY(@current_date) = 1 THEN 1 ELSE 0 END,
            CASE WHEN DAY(@current_date) = DAY(EOMONTH(@current_date)) THEN 1 ELSE 0 END,
            CASE WHEN MONTH(@current_date) IN (1, 4, 7, 10) AND DAY(@current_date) = 1 THEN 1 ELSE 0 END,
            CASE WHEN MONTH(@current_date) IN (3, 6, 9, 12) AND DAY(@current_date) = DAY(EOMONTH(@current_date)) THEN 1 ELSE 0 END,
            CASE WHEN MONTH(@current_date) = 1 AND DAY(@current_date) = 1 THEN 1 ELSE 0 END,
            CASE WHEN MONTH(@current_date) = 12 AND DAY(@current_date) = 31 THEN 1 ELSE 0 END,
            CASE WHEN MONTH(@current_date) >= 7 THEN YEAR(@current_date) + 1 ELSE YEAR(@current_date) END,
            CASE 
                WHEN MONTH(@current_date) IN (7, 8, 9) THEN 1
                WHEN MONTH(@current_date) IN (10, 11, 12) THEN 2
                WHEN MONTH(@current_date) IN (1, 2, 3) THEN 3
                WHEN MONTH(@current_date) IN (4, 5, 6) THEN 4
            END
        );
        
        SET @current_date = DATEADD(DAY, 1, @current_date);
    END
    
    PRINT '✅ dim_dates populated successfully!';
    PRINT '   Intervalo: 2020-01-01 até 2030-12-31';
END
ELSE
BEGIN
    PRINT 'ℹ️ dim_dates already has data. Skipping population.';
END
GO

-- Mostrar estatísticas
SELECT 
    COUNT(*) AS total_dates,
    MIN(full_date) AS min_date,
    MAX(full_date) AS max_date
FROM dwh.dim_dates;
GO