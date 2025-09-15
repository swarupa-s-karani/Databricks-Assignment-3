-- This tests if dbt can connect to your Databricks catalog
-- Create this file as models/connection_test.sql in dbt Cloud

{{ config(materialized='table') }}

SELECT 
    'dbt_connection_successful' as status,
    current_timestamp() as test_time,
    'insurance_analytics' as catalog_name,
    1 as test_record_1,
    2 as test_record_2,
    3 as test_record_3