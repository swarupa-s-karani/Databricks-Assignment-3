-- models/silver/silver_customers.sql (Consolidated version)
{{ config(
    materialized='table',
    schema='02_silver',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'silver_customers' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM {{ ref('bronze_customers') }}) as source_records,
                   (SELECT COUNT(*) FROM {{ this }}) as target_records,
                   (SELECT COUNT(*) FROM {{ this }} WHERE is_bad_record = 1) as bad_records,
                   'silver_customers' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}

SELECT 
    customer_id,
    TRIM(UPPER(first_name)) as first_name,
    TRIM(UPPER(last_name)) as last_name,
    LOWER(TRIM(email)) as email,
    phone,
    address,
    city,
    state,
    zip_code,
    date_of_birth,
    gender,
    marital_status,
    employment_status,
    annual_income,
    credit_score,
    registration_date,
    
    -- Age calculation
    YEAR(CURRENT_DATE()) - YEAR(date_of_birth) as age,
    
    -- Income categorization
    CASE 
        WHEN annual_income < 30000 THEN 'Low Income'
        WHEN annual_income < 75000 THEN 'Medium Income'
        WHEN annual_income >= 75000 THEN 'High Income'
        ELSE 'Unknown'
    END as income_level,
    
    -- CONSOLIDATED BAD RECORD FLAG
    CASE 
        WHEN email IS NULL OR email = '' OR email NOT LIKE '%@%.%' THEN 1
        WHEN date_of_birth > CURRENT_DATE() OR date_of_birth < '1900-01-01' THEN 1
        WHEN phone IS NULL OR LENGTH(phone) < 10 THEN 1
        WHEN annual_income IS NULL OR annual_income < 0 OR annual_income > 500000 THEN 1
        ELSE 0
    END as is_bad_record,
    
    -- DETAILED BREAKDOWN (Optional - for debugging)
    CASE WHEN email IS NULL OR email = '' OR email NOT LIKE '%@%.%' THEN 'INVALID_EMAIL' ELSE '' END ||
    CASE WHEN date_of_birth > CURRENT_DATE() OR date_of_birth < '1900-01-01' THEN 'INVALID_BIRTHDATE|' ELSE '' END ||
    CASE WHEN phone IS NULL OR LENGTH(phone) < 10 THEN 'INVALID_PHONE|' ELSE '' END ||
    CASE WHEN annual_income IS NULL OR annual_income < 0 OR annual_income > 500000 THEN 'SUSPICIOUS_INCOME|' ELSE '' END as quality_issues,
    
    -- Keep original fields
    bronze_load_time,
    source_system,
    current_timestamp() as silver_load_time
    
FROM {{ ref('bronze_customers') }}
WHERE customer_id IS NOT NULL