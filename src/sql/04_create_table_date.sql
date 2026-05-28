USE ETL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'dim_dates'
    AND schema_id = SCHEMA_ID('dwh')
)
BEGIN
    CREATE TABLE dwh.dim_dates
    (
        date_sk                 INT NOT NULL,
        full_date               DATE NOT NULL,

        year_number             SMALLINT NOT NULL,
        quarter_number          TINYINT NOT NULL,
        semester_number         TINYINT NOT NULL,

        month_number            TINYINT NOT NULL,
        month_name              VARCHAR(20) NOT NULL,
        month_abbreviation      CHAR(3) NOT NULL,

        week_number             TINYINT NOT NULL,
        week_of_month           TINYINT NOT NULL,

        day_of_month            TINYINT NOT NULL,
        day_of_week             TINYINT NOT NULL,
        day_name                VARCHAR(20) NOT NULL,
        day_abbreviation        CHAR(3) NOT NULL,

        is_weekend              BIT NOT NULL,
        is_month_start          BIT NOT NULL,
        is_month_end            BIT NOT NULL,
        is_quarter_start        BIT NOT NULL,
        is_quarter_end          BIT NOT NULL,
        is_year_start           BIT NOT NULL,
        is_year_end             BIT NOT NULL,

        fiscal_year             SMALLINT NULL,
        fiscal_quarter          TINYINT NULL,

        CONSTRAINT PK_dim_dates
            PRIMARY KEY CLUSTERED (date_sk),
        CONSTRAINT UQ_dim_dates_full_date
            UNIQUE (full_date)
    );
END
GO