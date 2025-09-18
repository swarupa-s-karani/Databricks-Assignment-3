-- models/gold/gold_risk_analysis.sql
{{ config(
    materialized='table',
    schema='03_gold',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'gold_risk_analysis' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM {{ ref('silver_policies') }}) as source_records,
                   (SELECT COUNT(*) FROM {{ this }}) as target_records,
                   0 as bad_records,
                   'gold_risk_analysis' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}

-- Risk Assessment by Policy Type and Demographics
SELECT 
    p.policy_type,
    c.age,
    c.state,
    c.income_level,
    
    -- Policy metrics
    COUNT(p.policy_id) as total_policies,
    AVG(p.premium_amount) as avg_premium,
    AVG(p.coverage_amount) as avg_coverage,
    
    -- Claim metrics
    COUNT(cl.claim_id) as total_claims,
    COALESCE(SUM(cl.approved_amount), 0) as total_payouts,
    COALESCE(AVG(cl.approved_amount), 0) as avg_claim_payout,
    
    -- Risk calculations
    CASE 
        WHEN COUNT(p.policy_id) > 0 
        THEN ROUND((COUNT(cl.claim_id) * 100.0) / COUNT(p.policy_id), 2)
        ELSE 0 
    END as claims_frequency_percent,
    
    CASE 
        WHEN SUM(p.premium_amount) > 0 
        THEN ROUND((COALESCE(SUM(cl.approved_amount), 0) / SUM(p.premium_amount)) * 100, 2)
        ELSE 0 
    END as loss_ratio_percent,
    
    -- Risk categories
    CASE 
        WHEN COALESCE(SUM(cl.approved_amount), 0) / NULLIF(SUM(p.premium_amount), 0) > 0.8 THEN 'High Risk'
        WHEN COALESCE(SUM(cl.approved_amount), 0) / NULLIF(SUM(p.premium_amount), 0) > 0.5 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END as risk_category,
    
    -- Profitability
    SUM(p.premium_amount) - COALESCE(SUM(cl.approved_amount), 0) as segment_profit,
    
    CASE 
        WHEN SUM(p.premium_amount) - COALESCE(SUM(cl.approved_amount), 0) > 0 THEN 'Profitable'
        ELSE 'Loss Making'
    END as profitability_status,
    
    current_timestamp() as analysis_date
    
FROM {{ ref('silver_customers') }} c
LEFT JOIN {{ ref('silver_policies') }} p ON c.customer_id = p.customer_id
LEFT JOIN {{ ref('silver_claims') }} cl ON p.policy_id = cl.policy_id
WHERE p.policy_id IS NOT NULL
GROUP BY p.policy_type, c.age, c.state, c.income_level
HAVING COUNT(p.policy_id) >= 3  -- Only segments with sufficient data
ORDER BY loss_ratio_percent DESC, claims_frequency_percent DESC