-- =====================================================================
-- 01_create_and_load.sql
-- Moniepoint x CBN cash-cap analysis: schema + load + sanity checks
-- =====================================================================
-- BEFORE YOU RUN:
--   1. Replace every  /PATH/TO/  below with the folder holding your CSVs.
--      Use forward slashes even on Windows, e.g. 'C:/Users/you/Downloads/'
--   2. LOAD DATA LOCAL needs local_infile on, on BOTH server and client:
--        SHOW VARIABLES LIKE 'local_infile';      -- want ON
--        SET GLOBAL local_infile = 1;             -- if OFF (needs admin)
--      Client side: start the CLI with   mysql --local-infile=1 -u root -p
--      or in Workbench: connection > Advanced > Others > OPT_LOCAL_INFILE=1
--   3. Files use Unix line endings ('\n'). If you re-save any CSV in Excel
--      on Windows, change '\n' to '\r\n' in that file's LOAD statement.
-- =====================================================================
SET GLOBAL local_infile = 1;

SHOW VARIABLES LIKE 'local_infile';

CREATE DATABASE IF NOT EXISTS payments_analysis;
USE payments_analysis;

-- ---------------------------------------------------------------------
-- 1) Main table: CBN Q1 2025 vs Q1 2026 by channel
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS channel_quarterly;
CREATE TABLE channel_quarterly (
  channel             VARCHAR(30)      NOT NULL,
  period              VARCHAR(10)      NOT NULL,           -- 'Q1 2025' / 'Q1 2026'
  volume_transactions BIGINT UNSIGNED  NOT NULL,           -- raw count (13B+ overflows INT)
  value_ngn_trillion  DECIMAL(10,2)    NOT NULL,           -- NGN trillion
  source              VARCHAR(200),
  source_date         DATE,
  is_total            TINYINT(1) GENERATED ALWAYS AS (channel = 'All Channels Total') STORED,
  PRIMARY KEY (channel, period)
);

LOAD DATA LOCAL INFILE 'C:/Users/HP/Documents/GitHub/cbn-cash-caps-analysis/data/nibss_cbn_q1_channel_data.csv'
INTO TABLE channel_quarterly
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(channel, period, volume_transactions, value_ngn_trillion, source, source_date);

-- ---------------------------------------------------------------------
-- 2) Annual context: CBN 2025 Annual Report (full-year 2025 vs 2024)
--    Mixed units by row (see `metric`), so keep it as a context table;
--    do not union it with channel_quarterly.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS annual_context_2025;
CREATE TABLE annual_context_2025 (
  metric       VARCHAR(60)    NOT NULL,                    -- unit lives in the text
  channel      VARCHAR(30)    NOT NULL,
  year_2024    DECIMAL(12,2)  NULL,                        -- 'NA' in file -> NULL
  year_2025    DECIMAL(12,2)  NOT NULL,
  pct_change   DECIMAL(7,2),
  source       VARCHAR(100),
  source_month CHAR(7),                                    -- 'YYYY-MM' in file
  PRIMARY KEY (metric, channel)
);

LOAD DATA LOCAL INFILE 'C:/Users/HP/Documents/GitHub/cbn-cash-caps-analysis/data/cbn_annual_2025_context.csv'
INTO TABLE annual_context_2025
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(metric, channel, @y24, year_2025, pct_change, source, source_month)
SET year_2024 = NULLIF(@y24, 'NA');

-- ---------------------------------------------------------------------
-- 3) Moniepoint stats: text-valued company/press figures, for dashboard
--    callout cards only. Not analytical data.
--    NOTE: no ENCLOSED BY here on purpose: one value contains literal
--    double quotes mid-field ("8 in 10") which would confuse the parser.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS moniepoint_stats;
CREATE TABLE moniepoint_stats (
  metric      VARCHAR(80)   NOT NULL PRIMARY KEY,
  value_text  VARCHAR(120)  NOT NULL,
  period      VARCHAR(40),
  source      VARCHAR(150),
  source_date VARCHAR(10)                                  -- mix of full dates and '2026'
);

LOAD DATA LOCAL INFILE 'C:/Users/HP/Documents/GitHub/cbn-cash-caps-analysis/data/moniepoint_verified_stats.csv'
INTO TABLE moniepoint_stats
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(metric, value_text, period, source, source_date);

-- =====================================================================
-- SANITY CHECKS: run these and paste the output back
-- =====================================================================
SHOW WARNINGS;

-- A) Row counts. Expect 14 / 4 / 4
SELECT 'channel_quarterly' AS tbl, COUNT(*) AS n FROM channel_quarterly
UNION ALL SELECT 'annual_context_2025', COUNT(*) FROM annual_context_2025
UNION ALL SELECT 'moniepoint_stats',    COUNT(*) FROM moniepoint_stats;

-- B) Reconciliation of channel rows vs reported totals. Expect:
--    Q1 2025 | 13854990000 | 13840000000 | 1024.15 | 1024.00
--    Q1 2026 | 12571630000 | 12570000000 | 1053.33 | 1053.00
--    (small gaps are expected: the source rounds its totals)
SELECT period,
  SUM(CASE WHEN is_total = 0 THEN volume_transactions END) AS channels_vol,
  SUM(CASE WHEN is_total = 1 THEN volume_transactions END) AS reported_vol,
  SUM(CASE WHEN is_total = 0 THEN value_ngn_trillion  END) AS channels_val,
  SUM(CASE WHEN is_total = 1 THEN value_ngn_trillion  END) AS reported_val
FROM channel_quarterly
GROUP BY period
ORDER BY period;

-- C) Load hygiene. Expect 0 / 0 / 2 (2 = the two NA rows in year_2024)
SELECT
  (SELECT COUNT(*) FROM channel_quarterly WHERE source_date IS NULL)        AS null_dates,
  (SELECT COUNT(*) FROM moniepoint_stats  WHERE source_date LIKE '%\r')     AS stray_cr,
  (SELECT COUNT(*) FROM annual_context_2025 WHERE year_2024 IS NULL)        AS na_to_null;

USE payments_analysis;
SELECT COUNT(*) FROM channel_quarterly;      -- 14
SELECT COUNT(*) FROM annual_context_2025;    -- 4
SELECT COUNT(*) FROM moniepoint_stats;       -- 4
