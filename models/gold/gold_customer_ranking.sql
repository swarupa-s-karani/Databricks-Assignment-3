-- models/gold/gold_customer_ranking.sql
{{ config(
    materialized='table',
    schema='03_gold',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'gold_customer_ranking' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM {{ ref('silver_customers') }}) as source_records,
                   (SELECT COUNT(*) FROM {{ this }}) as target_records,
                   0 as bad_records,
                   'gold_customer_ranking' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}

-- profitable customers
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.age,
    c.state,
    
    -- customer metrics
    COUNT(p.policy_id) as total_policies,
    SUM(p.premium_amount) as total_premiums,
    COUNT(cl.claim_id) as total_claims,
    SUM(cl.approved_amount) as total_payouts,
    
    -- customer profitability
    SUM(p.premium_amount) - COALESCE(SUM(cl.approved_amount), 0) as customer_profit,
    
    --  tier assignment
    CASE 
        WHEN SUM(p.premium_amount) - COALESCE(SUM(cl.approved_amount), 0) >= 3000 THEN 'VIP'
        WHEN SUM(p.premium_amount) - COALESCE(SUM(cl.approved_amount), 0) >= 1000 THEN 'Premium' 
        ELSE 'Standard'
    END as customer_tier,
    
    -- R\risk level
    CASE 
        WHEN COUNT(cl.claim_id) = 0 THEN 'Low Risk'
        WHEN COUNT(cl.claim_id) <= 2 THEN 'Medium Risk'
        ELSE 'High Risk'
    END as risk_level
    
FROM {{ ref('silver_customers') }} c
LEFT JOIN {{ ref('silver_policies') }} p ON c.customer_id = p.customer_id
LEFT JOIN {{ ref('silver_claims') }} cl ON p.policy_id = cl.policy_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.age, c.state
HAVING SUM(p.premium_amount) > 0
ORDER BY customer_profit DESC
LIMIT 100