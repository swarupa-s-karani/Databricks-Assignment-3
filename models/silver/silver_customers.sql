--models/silver/silver_customers.sql
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
                   (SELECT COUNT(*) FROM {{ ref('bronze_customers') }} WHERE customer_id IS NULL) as bad_records,
                   'silver_customers' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}


SELECT 
    customer_id,
    -- Clean up names - make them uppercase and remove extra spaces
    TRIM(UPPER(first_name)) as first_name,
    TRIM(UPPER(last_name)) as last_name,
    -- Clean email - make it lowercase
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
    
    -- Add some useful calculated fields
    YEAR(CURRENT_DATE()) - YEAR(date_of_birth) as age,
    
    -- Categorize income levels
    CASE 
        WHEN annual_income < 30000 THEN 'Low Income'
        WHEN annual_income < 75000 THEN 'Medium Income'
        WHEN annual_income >= 75000 THEN 'High Income'
        ELSE 'Unknown'
    END as income_level,
    
    -- Flag bad data
    CASE 
        WHEN email IS NULL OR email = '' THEN 1 
        ELSE 0 
    END as missing_email_flag,
    
    CASE 
        WHEN date_of_birth > CURRENT_DATE() THEN 1 
        ELSE 0 
    END as bad_birthdate_flag,
    
    -- Keep original fields
    bronze_load_time,
    source_system,
    current_timestamp() as silver_load_time
    
FROM {{ ref('bronze_customers') }}
WHERE customer_id IS NOT NULL