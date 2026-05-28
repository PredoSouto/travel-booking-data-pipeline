USE ETL;
GO

SELECT 
    s.name AS schema_name,
    t.name AS table_name,
    CASE 
        WHEN t.name LIKE 'dim%' THEN '📊 Dimension'
        WHEN t.name LIKE 'fact%' THEN '📈 Fact'
        WHEN t.name LIKE 'etl%' THEN '⚙️ Control'
        WHEN t.name LIKE 'tb%' THEN '📥 Staging'
        ELSE '📁 Other'
    END AS table_type,
    t.create_date
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN ('dwh', 'staging')
ORDER BY s.name, t.name;