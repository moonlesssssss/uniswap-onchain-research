-- 06_data_quality_audit.sql
-- 12-month screen on RAW dex.trades (no exclusions applied): pair-months with >= $100M volume
-- that have few transactions, few senders, or a multi-million median trade.
-- This is the evidence behind rules R1-R3 in 00_excluded_pair_months.sql.
-- already_excluded = the three pairs removed manually in the first version of the project.

WITH t AS (
    SELECT
        date_trunc('month', block_time) AS month,
        blockchain,
        token_pair,
        version,
        amount_usd,
        tx_hash,
        tx_from
    FROM dex.trades
    WHERE project = 'uniswap'
      AND amount_usd IS NOT NULL
      AND token_pair IS NOT NULL
      AND block_time >= date_trunc('month', current_timestamp) - INTERVAL '12' MONTH
      AND block_time < date_trunc('day', current_timestamp)
)
SELECT
    month,
    blockchain,
    token_pair,
    version,
    ROUND(SUM(amount_usd) / 1e9, 3) AS volume_usd_bn,
    COUNT(DISTINCT tx_hash) AS transactions,
    COUNT(DISTINCT tx_from) AS active_senders,
    ROUND(approx_percentile(amount_usd, 0.5), 0) AS median_usd,
    ROUND(MAX(amount_usd), 0) AS max_usd,
    ROUND(SUM(amount_usd) / COUNT(DISTINCT tx_hash), 0) AS usd_per_tx,
    (
        (blockchain = 'robinhood' AND token_pair IN ('AI-WETH', 'COBIE-ETH'))
        OR (blockchain = 'ethereum' AND token_pair = 'MAHC-WETH')
    ) AS already_excluded
FROM t
GROUP BY 1, 2, 3, 4
HAVING SUM(amount_usd) >= 1e8
   AND (
        COUNT(DISTINCT tx_hash) <= 2000
        OR COUNT(DISTINCT tx_from) <= 20
        OR approx_percentile(amount_usd, 0.5) >= 500000
   )
ORDER BY SUM(amount_usd) DESC
LIMIT 100;
