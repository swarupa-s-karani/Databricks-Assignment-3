--models/gold/gold_business_dashboard.sql
{{ config(
    materialized='table',
    schema='03_gold',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'gold_business_dashboard' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM {{ ref('silver_policies') }}) as source_records,
                   (SELECT COUNT(*) FROM {{ this }}) as target_records,
                   0 as bad_records,
                   'gold_business_dashboard' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}

-- Executive Dashboard - Key business numbers at a glance
WITH business_metrics AS (
    SELECT 
        -- REVENUE SUMMARY
        COUNT(DISTINCT p.policy_id) as total_policies_active,
        COUNT(DISTINCT p.customer_id) as total_customers,
        SUM(p.premium_amount) as total_annual_revenue,
        AVG(p.premium_amount) as average_policy_value,
        
        -- CLAIMS PERFORMANCE
        COUNT(DISTINCT c.claim_id) as total_claims_filed,
        SUM(c.claim_amount) as total_claims_requested,
        SUM(c.approved_amount) as total_claims_paid,
        
        -- OPERATIONAL METRICS
        COUNT(DISTINCT p.agent_id) as active_agents,
        COUNT(DISTINCT pr.premium_id) as total_transactions,
        SUM(pr.amount_paid) as total_cash_collected,
        COUNT(CASE WHEN pr.was_late = 'Yes' THEN 1 END) as late_payments
        
    FROM {{ ref('silver_policies') }} p
    LEFT JOIN {{ ref('silver_claims') }} c ON p.policy_id = c.policy_id
    LEFT JOIN {{ ref('silver_premiums') }} pr ON p.policy_id = pr.policy_id
    WHERE p.currently_active = 'Yes'
),

policy_mix AS (
    SELECT 
        p.policy_type,
        COUNT(p.policy_id) as policies_count,
        SUM(p.premium_amount) as revenue_by_type,
        ROUND(AVG(p.premium_amount), 0) as avg_premium_by_type,
        COUNT(c.claim_id) as claims_by_type,
        COALESCE(SUM(c.approved_amount), 0) as payouts_by_type
    FROM {{ ref('silver_policies') }} p
    LEFT JOIN {{ ref('silver_claims') }} c ON p.policy_id = c.policy_id
    WHERE p.currently_active = 'Yes'
    GROUP BY p.policy_type
)

SELECT 
    'BUSINESS_SUMMARY' as metric_type,
    'Company Overview' as metric_name,
    
    -- TOP LINE NUMBERS (What CEO cares about)
    bm.total_annual_revenue as annual_revenue,
    bm.total_policies_active as active_policies,
    bm.total_customers as customer_base,
    bm.average_policy_value as avg_policy_value,
    
    -- PROFITABILITY (What CFO cares about)  
    bm.total_annual_revenue - bm.total_claims_paid as net_profit,
    ROUND((bm.total_claims_paid / NULLIF(bm.total_annual_revenue, 0)) * 100, 1) as loss_ratio_percent,
    ROUND(((bm.total_annual_revenue - bm.total_claims_paid) / NULLIF(bm.total_annual_revenue, 0)) * 100, 1) as profit_margin_percent,
    
    -- CLAIMS EFFICIENCY (What COO cares about)
    bm.total_claims_filed as claims_volume,
    ROUND((bm.total_claims_filed * 100.0) / NULLIF(bm.total_policies_active, 0), 1) as claims_frequency_percent,
    ROUND(bm.total_claims_paid / NULLIF(bm.total_claims_filed, 0), 0) as avg_claim_payout,
    
    -- CASH FLOW (What CFO watches daily)
    bm.total_cash_collected as cash_collected,
    ROUND((bm.total_cash_collected / NULLIF(bm.total_annual_revenue, 0)) * 100, 1) as collection_rate_percent,
    ROUND((bm.late_payments * 100.0) / NULLIF(bm.total_transactions, 0), 1) as late_payment_rate_percent,
    
    -- BUSINESS HEALTH INDICATORS
    CASE 
        WHEN (bm.total_claims_paid / NULLIF(bm.total_annual_revenue, 0)) <= 0.60 THEN 'HEALTHY'
        WHEN (bm.total_claims_paid / NULLIF(bm.total_annual_revenue, 0)) <= 0.80 THEN 'ACCEPTABLE'
        WHEN (bm.total_claims_paid / NULLIF(bm.total_annual_revenue, 0)) <= 1.00 THEN 'CONCERNING'
        ELSE 'CRITICAL'
    END as business_health_status,
    
    CASE 
        WHEN bm.total_annual_revenue - bm.total_claims_paid > bm.total_annual_revenue * 0.3 THEN 'HIGHLY_PROFITABLE'
        WHEN bm.total_annual_revenue - bm.total_claims_paid > bm.total_annual_revenue * 0.15 THEN 'PROFITABLE'
        WHEN bm.total_annual_revenue - bm.total_claims_paid > 0 THEN 'BREAK_EVEN'
        ELSE 'LOSS_MAKING'
    END as profitability_status,
    
    -- OPERATIONAL EFFICIENCY
    ROUND(bm.total_policies_active / NULLIF(bm.active_agents, 0), 0) as policies_per_agent,
    ROUND(bm.total_annual_revenue / NULLIF(bm.active_agents, 0), 0) as revenue_per_agent,
    
    current_timestamp() as gold_load_time
    
FROM business_metrics bm

UNION ALL

-- PRODUCT LINE PERFORMANCE  
SELECT 
    'PRODUCT_PERFORMANCE' as metric_type,
    pm.policy_type as metric_name,
    
    pm.revenue_by_type as annual_revenue,
    pm.policies_count as active_policies,
    NULL as customer_base,
    pm.avg_premium_by_type as avg_policy_value,
    
    pm.revenue_by_type - pm.payouts_by_type as net_profit,
    ROUND((pm.payouts_by_type / NULLIF(pm.revenue_by_type, 0)) * 100, 1) as loss_ratio_percent,
    ROUND(((pm.revenue_by_type - pm.payouts_by_type) / NULLIF(pm.revenue_by_type, 0)) * 100, 1) as profit_margin_percent,
    
    pm.claims_by_type as claims_volume,
    ROUND((pm.claims_by_type * 100.0) / NULLIF(pm.policies_count, 0), 1) as claims_frequency_percent,
    ROUND(pm.payouts_by_type / NULLIF(pm.claims_by_type, 0), 0) as avg_claim_payout,
    
    NULL as cash_collected,
    NULL as collection_rate_percent,
    NULL as late_payment_rate_percent,
    
    CASE 
        WHEN (pm.payouts_by_type / NULLIF(pm.revenue_by_type, 0)) <= 0.50 THEN 'EXCELLENT'
        WHEN (pm.payouts_by_type / NULLIF(pm.revenue_by_type, 0)) <= 0.70 THEN 'GOOD'
        WHEN (pm.payouts_by_type / NULLIF(pm.revenue_by_type, 0)) <= 0.90 THEN 'ACCEPTABLE'
        ELSE 'NEEDS_ATTENTION'
    END as business_health_status,
    
    CASE 
        WHEN pm.revenue_by_type - pm.payouts_by_type > pm.revenue_by_type * 0.4 THEN 'STAR_PRODUCT'
        WHEN pm.revenue_by_type - pm.payouts_by_type > pm.revenue_by_type * 0.2 THEN 'CORE_PRODUCT'
        WHEN pm.revenue_by_type - pm.payouts_by_type > 0 THEN 'MARGINAL_PRODUCT'
        ELSE 'PROBLEM_PRODUCT'
    END as profitability_status,
    
    NULL as policies_per_agent,
    NULL as revenue_per_agent,
    
    current_timestamp() as gold_load_time
    
FROM policy_mix pm
WHERE pm.policies_count > 0

ORDER BY 
    metric_type,
    CASE WHEN metric_type = 'BUSINESS_SUMMARY' THEN 0 ELSE annual_revenue END DESC