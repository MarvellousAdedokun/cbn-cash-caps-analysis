USE payments_analysis;
SELECT 
    COUNT(*)
FROM
    channel_quarterly;

CREATE OR REPLACE VIEW v_channel_wide AS
    SELECT 
        channel,
        SUM(CASE
            WHEN period = 'Q1 2025' THEN volume_transactions
        END) AS vol_25,
        SUM(CASE
            WHEN period = 'Q1 2026' THEN volume_transactions
        END) AS vol_26,
        SUM(CASE
            WHEN period = 'Q1 2025' THEN value_ngn_trillion
        END) AS val_25,
        SUM(CASE
            WHEN period = 'Q1 2026' THEN value_ngn_trillion
        END) AS val_26
    FROM
        channel_quarterly
    WHERE
        is_total = 0
    GROUP BY channel;
 
CREATE OR REPLACE VIEW v_channel_group AS
    SELECT 
        CASE
            WHEN channel IN ('POS' , 'ATM') THEN 'Cash-linked (POS + ATM)'
            WHEN channel IN ('Mobile Pay' , 'NIP', 'WEB Pay') THEN 'Digital(Mobile + NIP + WEB)'
            ELSE 'Cheque'
        END AS channel_group,
        SUM(vol_25) AS vol_25,
        SUM(vol_26) AS vol_26,
        SUM(val_25) AS val_25,
        SUM(val_26) AS val_26
    FROM
        v_channel_wide
    GROUP BY channel_group;

 SELECT channel vol_25, vol_26, ROUND(100 * (vol_26 / vol_25 - 1), 2) AS vol_chg_pct, val_25, val_26, ROUND(100 * (val_26 / val_25 - 1), 2) AS val_chg_pct FROM v_channel_wide ORDER BY val_chg_pct DESC;
 
SELECT w.channel,
  ROUND(100 * w.vol_25 / t.v25, 2) AS vol_share_25,
  ROUND(100 * w.vol_26 / t.v26, 2) AS vol_share_26,
  ROUND(100 * w.vol_26 / t.v26 - 100 * w.vol_25 / t.v25, 2) AS vol_share_shift_pp,
  ROUND(100 * w.val_25 / t.t25, 2) AS val_share_25,
  ROUND(100 * w.val_26 / t.t26, 2) AS val_share_26,
  ROUND(100 * w.val_26 / t.t26 - 100 * w.val_25 / t.t25, 2) AS val_share_shift_pp
FROM v_channel_wide w
CROSS JOIN (SELECT SUM(vol_25) v25, SUM(vol_26) v26,
                   SUM(val_25) t25, SUM(val_26) t26
            FROM v_channel_wide) t
ORDER BY val_share_shift_pp;

SELECT g.channel_group,
	ROUND(100 * g.vol_25 / t.v25, 2) AS vol_share_25,
    ROUND(100 * g.vol_26 / t.v26, 2) AS vol_share_26, 
    ROUND(100 * g.val_25 / t.t25, 2) AS val_share_25,
    ROUND(100 * g.val_26 / t.t26, 2) AS val_share_26
FROM v_channel_group g
CROSS JOIN (SELECT SUM(vol_25) v25, SUM(vol_26) v26,
					SUM(val_25) t25, SUM(val_26) t26
                    FROM v_channel_group) t
ORDER BY g.channel_group;

SELECT channel,
	ROUND(val_25 * 1000000000000 / vol_25, 0) AS avg_naira_per_txn_25,
    ROUND(val_26 * 1000000000000 / vol_26, 0) AS avg_naira_per_txn_26,
    ROUND(100 * ((val_26 / vol_26) / (val_25 / vol_25) -1), 1) AS avg_size_chg_pct
FROM v_channel_wide
ORDER BY avg_size_chg_pct DESC;
