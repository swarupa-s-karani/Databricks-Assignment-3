-- This queries the test table we created in Databricks
-- Create this as models/query_test_table.sql in dbt Cloud

{{ config(materialized='table') }}

SELECT 
    id,
    name,
    created_date,
    'queried_from_dbt' as source,
    current_timestamp() as dbt_processed_time
FROM insurance_analytics.01_bronze.test_table
ORDER BY id