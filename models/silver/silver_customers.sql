-- models/silver/silver_claims.sql
{{ config(
    materialized='table',
    schema='02_silver',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'silver_claims' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM {{ ref('bronze_claims') }}) as source_records,
                   (SELECT COUNT(*) FROM {{ this }}) as target_records,
                   (SELECT COUNT(*) FROM {{ this }} WHERE is_bad_record = 1) as bad_records,
                   'silver_claims' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}

SELECT 
    claim_id,
    policy_id,
    claim_number,
    claim_date,
    incident_date,
    claim_type,
    claim_amount,
    approved_amount,
    status,
    adjuster_id,
    description,
    
    DATEDIFF(claim_date, incident_date) as days_to_report_claim,
    
    CASE 
        WHEN approved_amount >= claim_amount THEN 'Fully Approved'
        WHEN approved_amount > 0 THEN 'Partially Approved'
        WHEN approved_amount = 0 THEN 'Denied'
        ELSE 'Pending'
    END as approval_status,
    
    CASE 
        WHEN claim_amount < 5000 THEN 'Small Claim'
        WHEN claim_amount < 25000 THEN 'Medium Claim'
        ELSE 'Large Claim'
    END as claim_size,
    
    -- bad record
    CASE 
        WHEN claim_date < incident_date THEN 1
        WHEN claim_amount <= 0 THEN 1
        WHEN approved_amount > claim_amount * 1.5 THEN 1
        WHEN DATEDIFF(claim_date, incident_date) > 365 THEN 1
        ELSE 0
    END as is_bad_record,
    
    bronze_load_time,
    source_system,
    current_timestamp() as silver_load_time
    
FROM {{ ref('bronze_claims') }}
WHERE claim_id IS NOT NULL