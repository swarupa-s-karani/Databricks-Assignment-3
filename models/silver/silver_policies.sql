--models/silver/silver_policies.sql
{{ config(
    materialized='table',
    schema='02_silver',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'silver_policies' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM {{ ref('bronze_policies') }}) as source_records,
                   (SELECT COUNT(*) FROM {{ this }}) as target_records,
                   (SELECT COUNT(*) FROM {{ ref('bronze_policies') }} WHERE policy_id IS NULL) as bad_records,
                   'silver_policies' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}


SELECT 
    policy_id,
    customer_id,
    policy_number,
    policy_type,
    coverage_amount,
    premium_amount,
    deductible,
    start_date,
    end_date,
    status,
    agent_id,
    
    -- Add useful calculated fields
    DATEDIFF(end_date, start_date) as policy_length_days,
    
    -- Is the policy currently active?
    CASE 
        WHEN start_date <= CURRENT_DATE() 
         AND end_date >= CURRENT_DATE() 
         AND status = 'Active' 
        THEN 'Yes' 
        ELSE 'No' 
    END as currently_active,
    
    -- Categorize coverage amounts
    CASE 
        WHEN coverage_amount < 50000 THEN 'Basic Coverage'
        WHEN coverage_amount < 200000 THEN 'Standard Coverage'
        ELSE 'Premium Coverage'
    END as coverage_level,
    
    -- Flag problematic data
    CASE 
        WHEN end_date <= start_date THEN 1 
        ELSE 0 
    END as bad_dates_flag,
    
    CASE 
        WHEN coverage_amount <= 0 OR premium_amount <= 0 THEN 1 
        ELSE 0 
    END as bad_amounts_flag,
    
    -- Keep original fields
    bronze_load_time,
    source_system,
    current_timestamp() as silver_load_time
    
FROM {{ ref('bronze_policies') }}
WHERE policy_id IS NOT NULL