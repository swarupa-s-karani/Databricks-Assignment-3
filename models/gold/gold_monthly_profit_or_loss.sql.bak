--models/gold/gold_monthly_profit_or_loss.sql
{{ config(
    materialized='table',
    schema='03_gold',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'gold_monthly_profit_or_loss' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM {{ ref('silver_policies') }}) as source_records,
                   (SELECT COUNT(*) FROM {{ this }}) as target_records,
                   0 as bad_records,
                   'gold_monthly_profit_or_loss' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}

-- Monthly P&L Statement - What executives see in board meetings
SELECT 
    YEAR(p.start_date) as business_year,
    MONTH(p.start_date) as business_month,
    CONCAT(CAST(YEAR(p.start_date) AS STRING), '-', 
           LPAD(CAST(MONTH(p.start_date) AS STRING), 2, '0')) as month_year,
    
    -- REVENUE SIDE
    COUNT(p.policy_id) as policies_sold,
    SUM(p.premium_amount) as gross_premium_revenue,
    SUM(pr.amount_paid) as cash_collected,
    
    -- COST SIDE  
    COUNT(c.claim_id) as claims_filed,
    SUM(c.claim_amount) as total_claims_cost,
    SUM(c.approved_amount) as actual_payouts,
    
    -- PROFITABILITY
    SUM(p.premium_amount) - SUM(c.approved_amount) as monthly_profit,
    ROUND((SUM(c.approved_amount) / NULLIF(SUM(p.premium_amount), 0)) * 100, 1) as loss_ratio_percent,
    
    -- BUSINESS HEALTH INDICATORS
    CASE 
        WHEN SUM(p.premium_amount) - SUM(c.approved_amount) > 0 THEN 'PROFITABLE'
        WHEN SUM(p.premium_amount) - SUM(c.approved_amount) = 0 THEN 'BREAK_EVEN' 
        ELSE 'LOSS_MAKING'
    END as month_performance,
    
    -- GROWTH vs PREVIOUS MONTH
    LAG(SUM(p.premium_amount)) OVER (ORDER BY YEAR(p.start_date), MONTH(p.start_date)) as prev_month_revenue,
    LAG(COUNT(p.policy_id)) OVER (ORDER BY YEAR(p.start_date), MONTH(p.start_date)) as prev_month_policies,
    
    -- CASH FLOW
    CASE 
        WHEN SUM(pr.amount_paid) >= SUM(p.premium_amount) * 0.9 THEN 'HEALTHY'
        WHEN SUM(pr.amount_paid) >= SUM(p.premium_amount) * 0.7 THEN 'MODERATE'
        ELSE 'POOR'
    END as cash_flow_status,
    
    current_timestamp() as gold_load_time
    
FROM {{ ref('silver_policies') }} p
LEFT JOIN {{ ref('silver_claims') }} c ON p.policy_id = c.policy_id 
    AND YEAR(p.start_date) = YEAR(c.claim_date) 
    AND MONTH(p.start_date) = MONTH(c.claim_date)
LEFT JOIN {{ ref('silver_premiums') }} pr ON p.policy_id = pr.policy_id
    AND YEAR(p.start_date) = YEAR(pr.payment_date)
    AND MONTH(p.start_date) = MONTH(pr.payment_date)
GROUP BY YEAR(p.start_date), MONTH(p.start_date)
ORDER BY business_year DESC, business_month DESC