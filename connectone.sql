-- ============================================================
-- CONNECTONE: Subscriber Churn, Data Usage & Plan Profitability
-- MySQL 8.0+
-- Dataset: master_subscribers_clean.csv + complaints_clean.csv
-- ============================================================

CREATE DATABASE IF NOT EXISTS connectone;
USE connectone;

-- Re-runnable setup
DROP VIEW IF EXISTS vw_subscriber_summary;
DROP TABLE IF EXISTS complaints;
DROP TABLE IF EXISTS subscribers;

-- One row per subscriber. The master CSV already combines subscriber,
-- usage, network and status fields, so it is the main analysis table.
CREATE TABLE subscribers (
    subscriber_id       VARCHAR(20) PRIMARY KEY,
    activation_date     DATE,
    plan_type           VARCHAR(20),
    plan_name           VARCHAR(50),
    city                VARCHAR(80),
    age_group           VARCHAR(30),
    age                 INT,
    call_drops          INT DEFAULT 0,
    avg_data_speed_mbps DECIMAL(10,2),
    tower_area          VARCHAR(100),
    status              VARCHAR(20),
    churn_date          DATE NULL,
    ported_to           VARCHAR(50),
    is_churned          TINYINT(1) DEFAULT 0,
    month_name          VARCHAR(15),
    data_used_gb        DECIMAL(10,2),
    voice_minutes       INT,
    sms_count           INT,
    recharge_amount     DECIMAL(10,2),
    tenure_days         INT,
    CONSTRAINT chk_plan_type CHECK (plan_type IN ('Prepaid','Postpaid')),
    CONSTRAINT chk_status CHECK (status IN ('Active','Churned')),
    INDEX idx_plan_city (plan_name, city),
    INDEX idx_status (status),
    INDEX idx_tower_area (tower_area),
    INDEX idx_month_name (month_name)
);

-- Complaint file supplied has no subscriber_id column.
-- Therefore complaints can be analysed by type/date/resolution time,
-- but cannot honestly be joined to individual subscribers or churn records.
CREATE TABLE complaints (
    complaint_id    VARCHAR(30) PRIMARY KEY,
    complaint_date  DATE,
    complaint_type  VARCHAR(100),
    resolution_days INT,
    INDEX idx_complaint_type (complaint_type),
    INDEX idx_complaint_date (complaint_date)
);

-- ============================================================
-- DATA IMPORT
-- ============================================================

-- ============================================================
-- 1. BASIC DATA CHECKS
-- ============================================================
SELECT COUNT(*) AS total_subscribers FROM subscribers;

SELECT status, COUNT(*) AS subscriber_count
FROM subscribers
GROUP BY status;

SELECT plan_type, COUNT(*) AS subscriber_count
FROM subscribers
GROUP BY plan_type;

SELECT * FROM subscribers LIMIT 10;

-- Find missing values in important columns
SELECT
    SUM(subscriber_id IS NULL) AS missing_subscriber_id,
    SUM(plan_name IS NULL OR plan_name = '') AS missing_plan,
    SUM(city IS NULL OR city = '') AS missing_city,
    SUM(data_used_gb IS NULL) AS missing_data_usage,
    SUM(avg_data_speed_mbps IS NULL) AS missing_network_speed
FROM subscribers;

-- ============================================================
-- 2. CHURN ANALYSIS
-- ============================================================

-- Overall churn count and churn rate
SELECT
    COUNT(*) AS total_subscribers,
    SUM(is_churned = 1) AS churned_subscribers,
    ROUND(100.0 * SUM(is_churned = 1) / NULLIF(COUNT(*), 0), 2) AS churn_rate_pct
FROM subscribers;

-- Churn by plan
SELECT
    plan_name,
    COUNT(*) AS total_subscribers,
    SUM(is_churned = 1) AS churned_subscribers,
    ROUND(100.0 * SUM(is_churned = 1) / COUNT(*), 2) AS churn_rate_pct
FROM subscribers
GROUP BY plan_name
ORDER BY churn_rate_pct DESC;

-- Churn by area (city)
SELECT
    city,
    COUNT(*) AS total_subscribers,
    SUM(is_churned = 1) AS churned_subscribers,
    ROUND(100.0 * SUM(is_churned = 1) / COUNT(*), 2) AS churn_rate_pct
FROM subscribers
GROUP BY city
ORDER BY churn_rate_pct DESC;

-- Churn by subscriber type: Prepaid vs Postpaid
SELECT
    plan_type,
    COUNT(*) AS total_subscribers,
    SUM(is_churned = 1) AS churned_subscribers,
    ROUND(100.0 * SUM(is_churned = 1) / COUNT(*), 2) AS churn_rate_pct
FROM subscribers
GROUP BY plan_type
ORDER BY churn_rate_pct DESC;

-- Monthly active and churned subscribers by plan and city.
-- month_name is the usage month in the supplied dataset.
SELECT
    month_name,
    plan_name,
    city,
    SUM(status = 'Active') AS active_subscribers,
    SUM(status = 'Churned') AS churned_subscribers
FROM subscribers
GROUP BY month_name, plan_name, city
ORDER BY FIELD(month_name,
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'),
    plan_name, city;

-- Churn by age group
SELECT
    age_group,
    COUNT(*) AS total_subscribers,
    SUM(is_churned = 1) AS churned_subscribers,
    ROUND(100.0 * SUM(is_churned = 1) / COUNT(*), 2) AS churn_rate_pct
FROM subscribers
GROUP BY age_group
ORDER BY churn_rate_pct DESC;

-- ============================================================
-- 3. USAGE AND NETWORK ANALYSIS
-- ============================================================

-- Average data, voice, SMS and recharge by subscriber status
SELECT
    status,
    ROUND(AVG(data_used_gb), 2) AS avg_data_gb,
    ROUND(AVG(voice_minutes), 2) AS avg_voice_minutes,
    ROUND(AVG(sms_count), 2) AS avg_sms_count,
    ROUND(AVG(recharge_amount), 2) AS avg_recharge
FROM subscribers
GROUP BY status;

-- Compare churned and active users on usage and network quality
SELECT
    status,
    COUNT(*) AS subscribers,
    ROUND(AVG(data_used_gb), 2) AS avg_data_gb,
    ROUND(AVG(voice_minutes), 2) AS avg_voice_minutes,
    ROUND(AVG(call_drops), 2) AS avg_call_drops,
    ROUND(AVG(avg_data_speed_mbps), 2) AS avg_speed_mbps
FROM subscribers
GROUP BY status;

-- Areas with the most call drops and poor network speed
SELECT
    tower_area,
    COUNT(*) AS subscribers,
    SUM(call_drops) AS total_call_drops,
    ROUND(AVG(call_drops), 2) AS avg_call_drops,
    ROUND(1000.0 * SUM(call_drops) / NULLIF(COUNT(*), 0), 2)
        AS call_drops_per_1000_subscribers,
    ROUND(AVG(avg_data_speed_mbps), 2) AS avg_speed_mbps
FROM subscribers
GROUP BY tower_area
ORDER BY call_drops_per_1000_subscribers DESC;

-- Rank areas by call drops per 1,000 subscribers
SELECT
    tower_area,
    COUNT(*) AS subscribers,
    ROUND(1000.0 * SUM(call_drops) / NULLIF(COUNT(*), 0), 2)
        AS call_drops_per_1000,
    DENSE_RANK() OVER (
        ORDER BY 1000.0 * SUM(call_drops) / NULLIF(COUNT(*), 0) DESC
    ) AS area_rank
FROM subscribers
GROUP BY tower_area;

-- Rank areas by complaint volume per 1,000 subscribers.
-- Complaint records are not linked to subscriber/tower area in the supplied file,
-- so this query is intentionally not included: the required relationship is absent.

-- ============================================================
-- 4. PLAN PROFITABILITY / ARPU
-- ============================================================

-- Average revenue per user (ARPU) by plan
SELECT
    plan_name,
    COUNT(*) AS subscribers,
    ROUND(SUM(recharge_amount), 2) AS total_revenue,
    ROUND(AVG(recharge_amount), 2) AS arpu,
    ROUND(AVG(recharge_amount) * COUNT(*), 2) AS estimated_revenue
FROM subscribers
GROUP BY plan_name
ORDER BY arpu DESC;

-- Revenue and churn together to identify risky plans
SELECT
    plan_name,
    COUNT(*) AS subscribers,
    ROUND(AVG(recharge_amount), 2) AS arpu,
    SUM(is_churned = 1) AS churned_subscribers,
    ROUND(100.0 * SUM(is_churned = 1) / COUNT(*), 2) AS churn_rate_pct
FROM subscribers
GROUP BY plan_name
ORDER BY arpu DESC;

-- Revenue by plan type
SELECT
    plan_type,
    COUNT(*) AS subscribers,
    ROUND(SUM(recharge_amount), 2) AS total_revenue,
    ROUND(AVG(recharge_amount), 2) AS arpu
FROM subscribers
GROUP BY plan_type;

-- ============================================================
-- 5. DATA USAGE DROP > 50% IN THE LAST THREE MONTHS
-- ============================================================
-- IMPORTANT DATA LIMITATION:
-- The supplied usage_clean.csv/master file has only ONE usage row per
-- subscriber and a month name without a year. It cannot establish a
-- subscriber's change across three months. The query below is a template
-- for when monthly usage history is available (multiple rows per subscriber).
--
-- For historical monthly data, create a separate usage_history table with
-- one row per subscriber per calendar month, and use a real month_date.
--
-- CREATE TABLE usage_history (
--     usage_id BIGINT PRIMARY KEY AUTO_INCREMENT,
--     subscriber_id VARCHAR(20) NOT NULL,
--     month_date DATE NOT NULL,
--     data_used_gb DECIMAL(10,2),
--     UNIQUE KEY uq_subscriber_month (subscriber_id, month_date),
--     FOREIGN KEY (subscriber_id) REFERENCES subscribers(subscriber_id)
-- );
--
-- WITH usage_comparison AS (
--     SELECT subscriber_id, month_date, data_used_gb,
--            LAG(data_used_gb, 3) OVER (
--                PARTITION BY subscriber_id ORDER BY month_date
--            ) AS usage_three_months_ago
--     FROM usage_history
-- )
-- SELECT subscriber_id, month_date, usage_three_months_ago, data_used_gb,
--        ROUND(100.0 * (usage_three_months_ago - data_used_gb)
--              / NULLIF(usage_three_months_ago, 0), 2) AS usage_drop_pct
-- FROM usage_comparison
-- WHERE usage_three_months_ago IS NOT NULL
--   AND data_used_gb < usage_three_months_ago * 0.50;

-- ============================================================
-- 6. COMPLAINT ANALYSIS
-- ============================================================

-- Complaint count by type
SELECT
    complaint_type,
    COUNT(*) AS complaint_count,
    ROUND(AVG(resolution_days), 2) AS avg_resolution_days
FROM complaints
GROUP BY complaint_type
ORDER BY complaint_count DESC;

-- Longest average resolution time
SELECT
    complaint_type,
    ROUND(AVG(resolution_days), 2) AS avg_resolution_days,
    MAX(resolution_days) AS maximum_resolution_days
FROM complaints
GROUP BY complaint_type
ORDER BY avg_resolution_days DESC;

-- Monthly complaint trend
SELECT
    DATE_FORMAT(complaint_date, '%Y-%m') AS complaint_month,
    COUNT(*) AS total_complaints,
    ROUND(AVG(resolution_days), 2) AS avg_resolution_days
FROM complaints
GROUP BY DATE_FORMAT(complaint_date, '%Y-%m')
ORDER BY complaint_month;

-- Resolution time bands
SELECT
    CASE
        WHEN resolution_days <= 3 THEN '0-3 days'
        WHEN resolution_days <= 7 THEN '4-7 days'
        WHEN resolution_days <= 14 THEN '8-14 days'
        ELSE 'Above 14 days'
    END AS resolution_band,
    COUNT(*) AS complaint_count
FROM complaints
GROUP BY resolution_band
ORDER BY MIN(resolution_days);

-- ============================================================
-- 7. VIEWS FOR REPORTING / POWER BI
-- ============================================================

CREATE OR REPLACE VIEW vw_subscriber_summary AS
SELECT
    subscriber_id, plan_type, plan_name, city, age_group,
    status, is_churned, month_name, data_used_gb,
    voice_minutes, sms_count, recharge_amount,
    call_drops, avg_data_speed_mbps, tower_area
FROM subscribers;

-- Check the view
SELECT * FROM vw_subscriber_summary LIMIT 20;

-- ============================================================
-- 8. RETENTION ACTION LIST
-- ============================================================

-- Churned subscribers: useful for win-back campaign analysis
SELECT
    subscriber_id, plan_name, plan_type, city, tower_area,
    recharge_amount, data_used_gb, call_drops, avg_data_speed_mbps,
    churn_date, ported_to
FROM subscribers
WHERE status = 'Churned'
ORDER BY churn_date DESC;

-- Active subscribers with high call drops and low network speed
SELECT
    subscriber_id, city, tower_area, plan_name,
    call_drops, avg_data_speed_mbps
FROM subscribers
WHERE status = 'Active'
  AND call_drops >= 10
  AND avg_data_speed_mbps < 20
ORDER BY call_drops DESC, avg_data_speed_mbps ASC;

-- Active subscribers with low data usage (possible engagement risk)
SELECT
    subscriber_id, plan_name, city, data_used_gb, recharge_amount
FROM subscribers
WHERE status = 'Active'
  AND data_used_gb < 5
ORDER BY data_used_gb ASC;

-- ============================================================
-- END OF CONNECTONE SQL PROJECT
-- ============================================================

