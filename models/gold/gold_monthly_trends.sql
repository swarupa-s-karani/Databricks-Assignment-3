-- models/gold/gold_monthly_trends.sql
{{ config(
    materialized='table',
    schema='03_gold',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'gold_monthly_trends' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM {{ ref('silver_policies') }}) as source_records,
                   (SELECT COUNT(*) FROM {{ this }}) as target_records,
                   0 as bad_records,
                   'gold_monthly_trends' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}

SELECT 
    YEAR(p.start_date) as year,
    MONTH(p.start_date) as month,
    
    COUNT(p.policy_id) as policies_sold,
    SUM(p.premium_amount) as monthly_revenue,
    
    COUNT(c.claim_id) as claims_filed,
    COALESCE(SUM(c.approved_amount), 0) as claims_paid,
    
    -- monthly profit
    SUM(p.premium_amount) - COALESCE(SUM(c.approved_amount), 0) as monthly_profit,
    
    -- performance indicator  
    CASE 
        WHEN SUM(p.premium_amount) > COALESCE(SUM(c.approved_amount), 0) THEN 'Profitable'
        ELSE 'Loss Making'
    END as month_performance
    
FROM {{ ref('silver_policies') }} p
LEFT JOIN {{ ref('silver_claims') }} c ON p.policy_id = c.policy_id
    AND YEAR(p.start_date) = YEAR(c.claim_date)
    AND MONTH(p.start_date) = MONTH(c.claim_date)
GROUP BY YEAR(p.start_date), MONTH(p.start_date)
ORDER BY year DESC, month DESC