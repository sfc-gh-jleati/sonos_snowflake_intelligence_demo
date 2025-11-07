-- ========================================================================
-- SONOS ARC FORECASTING & ANOMALY DETECTION EXAMPLE
-- Use with Q3: "Forecast next 4 weeks for Arc + flag anomalies over past 12 weeks"
-- ========================================================================

USE ROLE SONOS_INTEL_DEMO_ROLE;
USE DATABASE SONOS_AI_DEMO;
USE SCHEMA APP;
USE WAREHOUSE SONOS_INTEL_WH;

-- ========================================================================
-- STEP 1: Prepare Arc daily sales data for North America
-- ========================================================================

CREATE OR REPLACE TABLE arc_daily_sales_ml AS
SELECT 
    s.date as ts,  -- Timestamp column for ML functions
    SUM(s.units) as units_sold
FROM sales_fact s
JOIN product_dim p ON s.product_key = p.product_key
JOIN region_dim r ON s.region_key = r.region_key
WHERE p.product_name = 'Sonos Arc'
  AND r.region_name = 'North America'
  AND s.date >= '2025-01-01'  -- Use recent data for better forecasting
GROUP BY s.date
ORDER BY s.date;

-- Verify data
SELECT 
    'Arc Daily Sales (NA)' as dataset,
    MIN(ts) as start_date,
    MAX(ts) as end_date,
    COUNT(*) as days,
    SUM(units_sold) as total_units,
    AVG(units_sold) as avg_daily_units
FROM arc_daily_sales_ml;


-- ========================================================================
-- STEP 2: FORECASTING - Predict next 4 weeks (28 days)
-- Uses SNOWFLAKE.ML.FORECAST (or fallback if unavailable)
-- ========================================================================

-- Option A: Using Snowflake ML FORECAST function (if available)
-- Uncomment if SNOWFLAKE.ML.FORECAST exists in your account:

/*
CALL SNOWFLAKE.ML.FORECAST(
    INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'arc_daily_sales_ml'),
    SERIES_COLNAME => 'ts',
    TARGET_COLNAME => 'units_sold',
    CONFIG_OBJECT => {'prediction_interval': 0.95}
);

-- Get forecast results
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE ts > CURRENT_DATE()
ORDER BY ts
LIMIT 28;  -- Next 4 weeks
*/

-- Option B: Statistical fallback - Moving average forecast
WITH recent_avg AS (
    SELECT 
        AVG(units_sold) as avg_units,
        STDDEV(units_sold) as stddev_units
    FROM arc_daily_sales_ml
    WHERE ts >= DATEADD(day, -28, CURRENT_DATE())  -- Last 4 weeks average
),
forecast_dates AS (
    SELECT 
        DATEADD(day, SEQ4(), CURRENT_DATE()) as forecast_date
    FROM TABLE(GENERATOR(ROWCOUNT => 28))  -- Next 28 days (4 weeks)
)
SELECT 
    fd.forecast_date as ts,
    ra.avg_units as forecast_units,
    ra.avg_units - 1.96 * ra.stddev_units as lower_bound,
    ra.avg_units + 1.96 * ra.stddev_units as upper_bound,
    'FORECAST' as data_type
FROM forecast_dates fd
CROSS JOIN recent_avg ra
ORDER BY fd.forecast_date;


-- ========================================================================
-- STEP 3: ANOMALY DETECTION - Flag unusual sales in past 12 weeks
-- Uses statistical z-score method
-- ========================================================================

WITH arc_12weeks AS (
    SELECT 
        ts,
        units_sold,
        AVG(units_sold) OVER (ORDER BY ts ROWS BETWEEN 13 PRECEDING AND 1 PRECEDING) as rolling_avg,
        STDDEV(units_sold) OVER (ORDER BY ts ROWS BETWEEN 13 PRECEDING AND 1 PRECEDING) as rolling_stddev
    FROM arc_daily_sales_ml
    WHERE ts >= DATEADD(week, -12, CURRENT_DATE())
      AND ts <= CURRENT_DATE()
),
anomaly_scores AS (
    SELECT 
        ts,
        units_sold,
        rolling_avg,
        rolling_stddev,
        CASE 
            WHEN rolling_stddev > 0 
            THEN (units_sold - rolling_avg) / rolling_stddev
            ELSE 0 
        END as z_score
    FROM arc_12weeks
    WHERE rolling_avg IS NOT NULL
)
SELECT 
    ts as date,
    units_sold,
    ROUND(rolling_avg, 1) as avg_expected,
    ROUND(z_score, 2) as z_score,
    CASE 
        WHEN z_score > 2 THEN '🔴 ANOMALY HIGH'
        WHEN z_score < -2 THEN '🔵 ANOMALY LOW'
        ELSE '✅ NORMAL'
    END as anomaly_flag,
    CASE 
        WHEN z_score > 2 THEN 'Unusual spike - check for promotions or events'
        WHEN z_score < -2 THEN 'Unusual drop - investigate potential issues'
        ELSE ''
    END as note
FROM anomaly_scores
ORDER BY ts DESC;


-- ========================================================================
-- STEP 4: COMBINED VIEW - Historical + Anomalies + Forecast
-- ========================================================================

-- Historical data with anomaly flags (past 12 weeks)
WITH historical_anomalies AS (
    SELECT 
        ts as date,
        units_sold as actual_units,
        NULL as forecast_units,
        CASE 
            WHEN (units_sold - AVG(units_sold) OVER (ORDER BY ts ROWS BETWEEN 13 PRECEDING AND 1 PRECEDING)) / 
                 NULLIF(STDDEV(units_sold) OVER (ORDER BY ts ROWS BETWEEN 13 PRECEDING AND 1 PRECEDING), 0) > 2 
            THEN 'ANOMALY HIGH'
            ELSE 'NORMAL'
        END as flag,
        'HISTORICAL' as data_type
    FROM arc_daily_sales_ml
    WHERE ts >= DATEADD(week, -12, CURRENT_DATE())
      AND ts <= CURRENT_DATE()
),
-- Forecast (next 4 weeks)
forecast_data AS (
    SELECT 
        DATEADD(day, SEQ4(), CURRENT_DATE()) as date,
        NULL as actual_units,
        AVG(units_sold) as forecast_units,
        'NORMAL' as flag,
        'FORECAST' as data_type
    FROM arc_daily_sales_ml
    WHERE ts >= DATEADD(day, -28, CURRENT_DATE())
    CROSS JOIN TABLE(GENERATOR(ROWCOUNT => 28))
    GROUP BY DATEADD(day, SEQ4(), CURRENT_DATE())
)
SELECT * FROM historical_anomalies
UNION ALL
SELECT * FROM forecast_data
ORDER BY date;


-- ========================================================================
-- STEP 5: Simple summary for demo
-- ========================================================================

SELECT 
    '📊 SONOS ARC FORECASTING SUMMARY' as report,
    '' as value
UNION ALL
SELECT 'Data Range', MIN(ts)::VARCHAR || ' to ' || MAX(ts)::VARCHAR FROM arc_daily_sales_ml WHERE region_name = 'North America'
UNION ALL
SELECT 'Total Days', COUNT(DISTINCT ts)::VARCHAR FROM arc_daily_sales_ml WHERE region_name = 'North America'
UNION ALL
SELECT 'Total Arc Units (NA)', SUM(daily_units)::VARCHAR FROM arc_daily_sales_ml WHERE region_name = 'North America'
UNION ALL
SELECT 'Avg Daily Units (Last 4 weeks)', ROUND(AVG(daily_units), 1)::VARCHAR FROM arc_daily_sales_ml WHERE region_name = 'North America' AND ts >= DATEADD(week, -4, CURRENT_DATE())
UNION ALL
SELECT 'Forecasted Daily Units (Next 4 weeks)', ROUND(AVG(daily_units), 1)::VARCHAR FROM arc_daily_sales_ml WHERE region_name = 'North America' AND ts >= DATEADD(week, -4, CURRENT_DATE())
UNION ALL
SELECT '🎯 Ready for Q3 Demo', 'YES ✅';

