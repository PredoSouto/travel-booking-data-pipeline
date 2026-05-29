# Data Warehouse - Travel Booking Star Schema

mermaid
erDiagram
    dim_users {
        BIGINT user_sk PK
        INT user_id BK
        NVARCHAR full_name
        NVARCHAR email
        VARCHAR user_type
        BIT is_current
    }
    
    dim_hosts {
        BIGINT host_sk PK
        INT host_id BK
        NVARCHAR full_name
        BIT is_superhost
        BIT is_current
    }
    
    dim_properties {
        BIGINT property_sk PK
        INT property_id BK
        NVARCHAR title
        VARCHAR property_type
        DECIMAL price_per_night
        BIT is_current
    }
    
    dim_dates {
        INT date_sk PK
        DATE full_date
        SMALLINT year_number
        BIT is_weekend
    }
    
    fact_bookings {
        BIGINT booking_sk PK
        BIGINT booking_id BK
        BIGINT user_sk FK
        BIGINT property_sk FK
        INT checkin_date_sk FK
        DECIMAL total_price
        VARCHAR booking_status
    }
    
    fact_payments {
        BIGINT payment_sk PK
        BIGINT booking_sk FK
        BIGINT user_sk FK
        INT payment_date_sk FK
        DECIMAL amount
        VARCHAR payment_status
    }
    
    dim_reviews {
        BIGINT review_sk PK
        BIGINT user_sk FK
        BIGINT property_sk FK
        INT review_date_sk FK
        TINYINT overall_rating
    }
    
    dim_users ||--o{ fact_bookings : "user_sk"
    dim_properties ||--o{ fact_bookings : "property_sk"
    dim_dates ||--o{ fact_bookings : "checkin_date_sk"
    fact_bookings ||--o{ fact_payments : "booking_sk"
    dim_users ||--o{ dim_reviews : "user_sk"
    dim_properties ||--o{ dim_reviews : "property_sk"