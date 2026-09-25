-- ============================================================
-- Digital Payments Transaction Analysis
-- SQL verification script (MySQL)
-- ============================================================

CREATE DATABASE IF NOT EXISTS digital_payments;
USE digital_payments;

CREATE TABLE transactions (
  Transaction_ID VARCHAR(20),
  Customer_ID VARCHAR(20),
  Transaction_DateTime DATETIME,
  Payment_Channel VARCHAR(20),
  Network_Provider VARCHAR(20),
  Region VARCHAR(20),
  Merchant_Category VARCHAR(30),
  Amount DECIMAL(12,2),
  Fee DECIMAL(10,2),
  Status VARCHAR(10),
  Failure_Reason VARCHAR(30)
);

-- Load the cleaned CSV (adjust path to your local file location)
LOAD DATA LOCAL INFILE 'payments_cleaned.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Sanity check: row count should be 931
SELECT COUNT(*) AS total_rows FROM transactions;

-- ============================================================
-- Finding 1: Failure rate by Payment_Channel
-- ============================================================
SELECT Payment_Channel,
  COUNT(*) AS total_transactions,
  SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS failed,
  ROUND(SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS failure_rate_pct
FROM transactions
GROUP BY Payment_Channel
ORDER BY failure_rate_pct DESC;

-- ============================================================
-- Finding 1b: USSD failure rate by Network_Provider
-- (confirms the issue is channel-wide, not one carrier)
-- ============================================================
SELECT Network_Provider,
  COUNT(*) AS total_ussd_transactions,
  SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS failed,
  ROUND(SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS failure_rate_pct
FROM transactions
WHERE Payment_Channel = 'USSD'
GROUP BY Network_Provider
ORDER BY failure_rate_pct DESC;

-- ============================================================
-- Finding 2: USSD failures by hour of day
-- ============================================================
SELECT HOUR(Transaction_DateTime) AS txn_hour,
  COUNT(*) AS ussd_failures
FROM transactions
WHERE Payment_Channel = 'USSD' AND Status = 'Failed'
GROUP BY txn_hour
ORDER BY txn_hour;

-- ============================================================
-- Finding 3: Reversal rate for high-value (>50,000) vs normal transactions
-- ============================================================
SELECT
  CASE WHEN Amount > 50000 THEN 'High-value (>50,000)' ELSE 'Normal (<=50,000)' END AS value_band,
  COUNT(*) AS total_transactions,
  SUM(CASE WHEN Status = 'Reversed' THEN 1 ELSE 0 END) AS reversed,
  ROUND(SUM(CASE WHEN Status = 'Reversed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS reversal_rate_pct
FROM transactions
GROUP BY value_band;

-- ============================================================
-- Summary stats
-- ============================================================
SELECT
  COUNT(*) AS total_transactions,
  ROUND(SUM(CASE WHEN Status='Success' THEN Amount ELSE 0 END), 2) AS total_successful_value,
  ROUND(AVG(Amount), 2) AS avg_transaction_value
FROM transactions;
