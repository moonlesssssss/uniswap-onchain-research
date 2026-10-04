-- 08_robinhood_usdg_weth_senders.sql  (Dune query 8890201)
-- Who generates the volume in the largest market (Robinhood Chain USDG-WETH)?
-- Senders are bucketed by their number of swap transactions over the last 30 full days.

WITH s AS (
    SELECT
        tx_from,
        COUNT(*) AS txs,
        SUM(amount_usd) AS vol
    FROM dex.trades
    WHERE project = 'uniswap'
      AND blockchain = 'robinhood'
      AND token_pair = 'USDG-WETH'
      AND amount_usd IS NOT NULL
      AND tx_from IS NOT NULL
      AND block_time >= date_trunc('day', current_timestamp) - INTERVAL '30' DAY
      AND block_time < date_trunc('day', current_timestamp)
    GROUP BY 1
),

b AS (
    SELECT
        CASE
            WHEN txs = 1 THEN 1
            WHEN txs <= 10 THEN 2
            WHEN txs <= 100 THEN 3
            WHEN txs <= 1000 THEN 4
            ELSE 5
        END AS bucket_order,
        CASE
            WHEN txs = 1 THEN '1 tx'
            WHEN txs <= 10 THEN '2-10 txs'
            WHEN txs <= 100 THEN '11-100 txs'
            WHEN txs <= 1000 THEN '101-1,000 txs'
            ELSE '>1,000 txs'
        END AS sender_bucket,
        txs,
        vol
    FROM s
)

SELECT
    sender_bucket,
    COUNT(*) AS senders,
    SUM(txs) AS transactions,
    ROUND(SUM(vol) / 1e9, 3) AS volume_usd_bn,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_senders,
    ROUND(100.0 * SUM(txs) / SUM(SUM(txs)) OVER (), 1) AS pct_of_transactions,
    ROUND(100.0 * SUM(vol) / SUM(SUM(vol)) OVER (), 1) AS pct_of_volume
FROM b
GROUP BY bucket_order, sender_bucket
ORDER BY bucket_order;
