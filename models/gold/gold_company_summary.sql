-- models/gold/gold_company_summary.sql
{{ config(
    materialized='table',
    schema='03_gold',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'gold_company_summary' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM {{ ref('silver_policies') }}) as source_records,
                   1 as target_records,
                   0 as bad_records,
                   'gold_company_summary' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}

SELECT 
    COUNT(p.policy_id) as total_policies,
    COUNT(DISTINCT p.customer_id) as total_customers,
    SUM(p.premium_amount) as total_revenue,
    COUNT(c.claim_id) as total_claims,
    COALESCE(SUM(c.approved_amount), 0) as total_payouts,
    
    -- profit calculation
    SUM(p.premium_amount) - COALESCE(SUM(c.approved_amount), 0) as net_profit,
    
    -- loss ratio with null handling
    ROUND((COALESCE(SUM(c.approved_amount), 0) / NULLIF(SUM(p.premium_amount), 0)) * 100, 1) as loss_ratio_percent,
    
    -- company health
    CASE 
        WHEN (COALESCE(SUM(c.approved_amount), 0) / NULLIF(SUM(p.premium_amount), 0)) < 0.8 THEN 'Healthy'
        ELSE 'Needs Review'
    END as company_status,
    
    current_timestamp() as report_date
    
FROM {{ ref('silver_policies') }} p
LEFT JOIN {{ ref('silver_claims') }} c ON p.policy_id = c.policy_id
WHERE p.currently_active = 'Yes'