--models/bronze/bronze_claims.sql
{{ config(
    materialized='table',
    schema='01_bronze',
    post_hook="INSERT INTO insurance_analytics.04_logs.dbt_logs 
               (dataset, time_processed, source_records, target_records, bad_records, model_name, run_id, status, execution_time_seconds, created_at)
               SELECT 
                   'bronze_claims' as dataset,
                   current_timestamp() as time_processed,
                   (SELECT COUNT(*) FROM delta.`/Volumes/insurance_analytics/00_landing/streaming/claims/`) as source_records,
                   (SELECT COUNT(*) FROM {{ this }}) as target_records,
                   0 as bad_records,
                   'bronze_claims' as model_name,
                   '{{ invocation_id }}' as run_id,
                   'success' as status,
                   0.0 as execution_time_seconds,
                   current_timestamp() as created_at"
) }}


SELECT 
    *,
    current_timestamp() as bronze_load_time,
    'streaming' as source_system
FROM delta.`/Volumes/insurance_analytics/00_landing/streaming/claims/`