USE ETL;
GO

-- =====================================================
-- DIM_REVIEWS (Avaliações dos usuários)
-- =====================================================

IF NOT EXISTS
(
    SELECT 1 FROM sys.tables
    WHERE name = 'dim_reviews'
    AND schema_id = SCHEMA_ID('dwh')
)
BEGIN
    CREATE TABLE dwh.dim_reviews
    (
        -- Surrogate Key
        review_sk               BIGINT IDENTITY(1,1) NOT NULL,
        
        -- Business Key
        review_id               INT NOT NULL,
        
        -- Foreign Keys
        booking_id              INT NOT NULL,
        user_sk                 BIGINT NOT NULL,
        property_sk             BIGINT NOT NULL,
        review_date_sk          INT NOT NULL,
        
        -- Ratings (1-5)
        rating_accuracy         TINYINT NULL,
        rating_cleanliness      TINYINT NULL,
        rating_checkin          TINYINT NULL,
        rating_communication    TINYINT NULL,
        rating_location         TINYINT NULL,
        rating_value            TINYINT NULL,
        overall_rating          TINYINT NOT NULL,
        
        -- Comments
        comment_title           NVARCHAR(200) NULL,
        comment_text            NVARCHAR(MAX) NULL,
        
        -- Host response
        host_response           NVARCHAR(MAX) NULL,
        host_response_date      DATE NULL,
        
        -- Audit
        created_at              DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
        
        -- Constraints
        CONSTRAINT PK_dim_reviews PRIMARY KEY CLUSTERED (review_sk),
        CONSTRAINT UQ_dim_reviews_review_id UNIQUE (review_id),
        CONSTRAINT FK_dim_reviews_user FOREIGN KEY (user_sk) REFERENCES dwh.dim_users(user_sk),
        CONSTRAINT FK_dim_reviews_property FOREIGN KEY (property_sk) REFERENCES dwh.dim_properties(property_sk),
        CONSTRAINT FK_dim_reviews_date FOREIGN KEY (review_date_sk) REFERENCES dwh.dim_dates(date_sk),
        CONSTRAINT CHK_dim_reviews_overall_rating CHECK (overall_rating BETWEEN 1 AND 5)
    );
END
GO

-- Índices
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_dim_reviews_booking')
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_reviews_booking
        ON dwh.dim_reviews(booking_id);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_dim_reviews_property')
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_reviews_property
        ON dwh.dim_reviews(property_sk, overall_rating);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_dim_reviews_user')
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_reviews_user
        ON dwh.dim_reviews(user_sk, review_date_sk);
END
GO

PRINT '✅ dim_reviews created successfully!';
GO