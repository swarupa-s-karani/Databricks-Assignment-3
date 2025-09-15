--models/gold/gold_top_customers.sql
{{ config(
    materialized='table',
    schema='03_gold',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'gold_top_customers' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM {{ ref('silver_customers') }}) as source_records,
                   (SELECT COUNT(*) FROM {{ this }}) as target_records,
                   0 as bad_records,
                   'gold_top_customers' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}

-- VIP Customer List - Who brings in the money
WITH customer_value AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.age,
        c.income_level,
        c.state,
        
        -- REVENUE METRICS
        COUNT(p.policy_id) as total_policies,
        SUM(p.premium_amount) as annual_premium_revenue,
        SUM(p.coverage_amount) as total_coverage_value,
        
        -- COST METRICS
        COALESCE(SUM(cl.approved_amount), 0) as total_claims_paid,
        COUNT(cl.claim_id) as number_of_claims,
        
        -- PROFITABILITY
        SUM(p.premium_amount) - COALESCE(SUM(cl.approved_amount), 0) as customer_profit,
        
        -- PAYMENT BEHAVIOR
        COUNT(pr.premium_id) as payment_count,
        COUNT(CASE WHEN pr.was_late = 'Yes' THEN 1 END) as late_payments,
        
        -- BUSINESS RELATIONSHIPS
        COUNT(DISTINCT p.policy_type) as product_types_purchased,
        MAX(p.start_date) as most_recent_purchase,
        MIN(p.start_date) as first_purchase,
        DATEDIFF(CURRENT_DATE(), MIN(p.start_date)) as customer_lifetime_days
        
    FROM {{ ref('silver_customers') }} c
    LEFT JOIN {{ ref('silver_policies') }} p ON c.customer_id = p.customer_id
    LEFT JOIN {{ ref('silver_claims') }} cl ON p.policy_id = cl.policy_id
    LEFT JOIN {{ ref('silver_premiums') }} pr ON p.policy_id = pr.policy_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.age, c.income_level, c.state
)

SELECT 
    customer_id,
    first_name,
    last_name,
    age,
    income_level,
    state,
    
    -- FINANCIAL METRICS
    annual_premium_revenue,
    total_claims_paid,
    customer_profit,
    total_coverage_value,
    
    -- LOYALTY METRICS
    total_policies,
    product_types_purchased,
    ROUND(customer_lifetime_days / 365.0, 1) as customer_years,
    
    -- RISK ASSESSMENT  
    number_of_claims,
    CASE 
        WHEN total_policies > 0 
        THEN ROUND((number_of_claims * 100.0) / total_policies, 1)
        ELSE 0 
    END as claims_per_policy_percent,
    
    CASE 
        WHEN payment_count > 0 
        THEN ROUND((late_payments * 100.0) / payment_count, 1)
        ELSE 0 
    END as late_payment_percent,
    
    -- CUSTOMER TIER
    CASE 
        WHEN customer_profit >= 5000 THEN 'PLATINUM (VIP Treatment)'
        WHEN customer_profit >= 2000 THEN 'GOLD (Priority Service)'
        WHEN customer_profit >= 500 THEN 'SILVER (Standard Plus)'
        WHEN customer_profit >= 0 THEN 'BRONZE (Standard)'
        ELSE 'REVIEW (Potential Issue)'
    END as customer_tier,
    
    -- RELATIONSHIP STATUS
    CASE 
        WHEN DATEDIFF(CURRENT_DATE(), most_recent_purchase) <= 30 THEN 'ACTIVE'
        WHEN DATEDIFF(CURRENT_DATE(), most_recent_purchase) <= 90 THEN 'RECENT' 
        WHEN DATEDIFF(CURRENT_DATE(), most_recent_purchase) <= 365 THEN 'DORMANT'
        ELSE 'INACTIVE'
    END as engagement_status,
    
    -- BUSINESS VALUE SCORE (1-10)
    LEAST(10, GREATEST(1,
        CASE 
            WHEN customer_profit >= 5000 THEN 10
            WHEN customer_profit >= 2000 THEN 8
            WHEN customer_profit >= 1000 THEN 6
            WHEN customer_profit >= 0 THEN 4
            ELSE 2
        END +
        CASE 
            WHEN product_types_purchased >= 3 THEN 1
            WHEN product_types_purchased >= 2 THEN 0.5
            ELSE 0
        END +
        CASE 
            WHEN late_payment_percent = 0 THEN 1
            WHEN late_payment_percent <= 10 THEN 0.5
            ELSE 0
        END
    )) as business_value_score,
    
    -- RECOMMENDED ACTION
    CASE 
        WHEN customer_profit >= 2000 AND late_payment_percent = 0 
            THEN 'VIP: Personal relationship manager, exclusive offers'
        WHEN customer_profit >= 1000 AND product_types_purchased = 1 
            THEN 'UPSELL: Cross-sell other products, loyalty rewards'
        WHEN customer_profit < 0 AND number_of_claims >= 3 
            THEN 'REVIEW: Consider policy terms adjustment or exit'
        WHEN engagement_status = 'INACTIVE' AND customer_profit > 0 
            THEN 'WINBACK: Retention campaign, special offers'
        ELSE 'MAINTAIN: Standard customer service and communications'
    END as recommended_action,
    
    most_recent_purchase,
    current_timestamp() as gold_load_time
    
FROM customer_value
WHERE annual_premium_revenue > 0
ORDER BY customer_profit DESC, annual_premium_revenue DESC
LIMIT 500