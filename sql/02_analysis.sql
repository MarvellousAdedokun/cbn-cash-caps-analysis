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

 