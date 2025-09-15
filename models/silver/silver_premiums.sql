--models/silver/silver_premiums.sql
{{ config(
    materialized='table',
    schema='02_silver',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'silver_premiums' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM {{ ref('bronze_premiums') }}) as source_records,
                   (SELECT COUNT(*) FROM {{ this }}) as target_records,
                   (SELECT COUNT(*) FROM {{ ref('bronze_premiums') }} WHERE premium_id IS NULL) as bad_records,
                   'silver_premiums' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}

SELECT 
    premium_id,
    policy_id,
    payment_date,
    due_date,
    amount_due,
    amount_paid,
    payment_method,
    status,
    late_fee,
    
    -- useful calculated fields
    DATEDIFF(payment_date, due_date) as days_late_or_early,
    
    -- payment status
    CASE 
        WHEN amount_paid >= amount_due AND payment_date <= due_date THEN 'On Time'
        WHEN amount_paid >= amount_due AND payment_date > due_date THEN 'Late but Paid'
        WHEN amount_paid < amount_due AND amount_paid > 0 THEN 'Partial Payment'
        WHEN amount_paid = 0 THEN 'Not Paid'
        ELSE 'Other'
    END as payment_status,
    
    -- wwas payment late?
    CASE 
        WHEN payment_date > due_date THEN 'Yes' 
        ELSE 'No' 
    END as was_late,
    
    -- flaging problematic data
    CASE 
        WHEN amount_due <= 0 THEN 1 
        ELSE 0 
    END as bad_amount_flag,
    
    CASE 
        WHEN payment_date IS NULL OR due_date IS NULL THEN 1 
        ELSE 0 
    END as missing_dates_flag,
    
    bronze_load_time,
    source_system,
    current_timestamp() as silver_load_time
    
FROM {{ ref('bronze_premiums') }}
WHERE premium_id IS NOT NULL