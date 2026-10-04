-- 00_excluded_pair_months.sql
-- Dune query 8889500. Saved as materialized view:
--   dune.moonlesssssss.result_uniswap_excluded_pair_months  (53 rows on 3 Oct 2026)
-- Single source of truth for data-quality exclusions. Every other query anti-joins this table.
--
-- A "pair-month" is one (blockchain, token_pair, version, month). Only pair-months with
-- >= $100M of volume are tested:
--   R1: median trade >= $1M
--   R2: <= 1,000 transactions, median trade < $1K and max trade >= $5M
--   R3: a pair flagged by R1/R2 in >= 3 months is excluded in all months (month = NULL)
--   M1: three pairs excluded manually in the first version of this project
-- These are heuristics, not proof. See README section 9.6 for limitations.

WITH pair_month AS (
    SELECT
        date_trunc('month', block_time) AS month,
        blockchain,
        token_pair,
        version,
        SUM(amount_usd) AS volume_usd,
        COUNT(DISTINCT tx_hash) AS transactions,
        COUNT(DISTINCT tx_from) AS active_senders,
        approx_percentile(amount_usd, 0.5) AS median_usd,
        MAX(amount_usd) AS max_usd
    FROM dex.trades
    WHERE project = 'uniswap'
      AND amount_usd IS NOT NULL
      AND token_pair IS NOT NULL
      AND block_time >= date_trunc('month', current_timestamp) - INTERVAL '13' MONTH
      AND block_time < date_trunc('day', current_timestamp)
    GROUP BY 1, 2, 3, 4
),

hits AS (
    SELECT
        *,
        CASE
            WHEN volume_usd >= 1e8 AND median_usd >= 1e6
                THEN 'R1: median trade >= $1M on a >= $100M pair-month'
            WHEN volume_usd >= 1e8 AND transactions <= 1000 AND median_usd < 1000 AND max_usd >= 5e6
                THEN 'R2: <= 1,000 txs, median < $1K, max >= $5M on a >= $100M pair-month'
        END AS rule
    FROM pair_month
),

flagged AS (
    SELECT * FROM hits WHERE rule IS NOT NULL
),

repeat_offenders AS (
    SELECT blockchain, token_pair, version
    FROM flagged
    GROUP BY 1, 2, 3
    HAVING COUNT(DISTINCT month) >= 3
)

-- month-level exclusions (pairs that are not repeat offenders)
SELECT
    f.month,
    f.blockchain,
    f.token_pair,
    f.version,
    f.rule,
    ROUND(f.volume_usd, 0) AS volume_usd,
    f.transactions,
    f.active_senders,
    ROUND(f.median_usd, 0) AS median_usd,
    ROUND(f.max_usd, 0) AS max_usd
FROM flagged f
LEFT JOIN repeat_offenders r
    ON f.blockchain = r.blockchain
   AND f.token_pair = r.token_pair
   AND f.version = r.version
WHERE r.token_pair IS NULL

UNION ALL

-- pair-level exclusions for repeat offenders (month = NULL means all months)
SELECT
    CAST(NULL AS timestamp(3) with time zone) AS month,
    p.blockchain,
    p.token_pair,
    p.version,
    'R3: flagged by R1/R2 in >= 3 months, excluded in all months' AS rule,
    ROUND(SUM(p.volume_usd), 0) AS volume_usd,
    SUM(p.transactions) AS transactions,
    CAST(NULL AS bigint) AS active_senders,
    CAST(NULL AS double) AS median_usd,
    ROUND(MAX(p.max_usd), 0) AS max_usd
FROM pair_month p
JOIN repeat_offenders r
    ON p.blockchain = r.blockchain
   AND p.token_pair = r.token_pair
   AND p.version = r.version
GROUP BY p.blockchain, p.token_pair, p.version

UNION ALL

-- pairs excluded manually in the first version of the project (all versions, all months)
SELECT
    CAST(NULL AS timestamp(3) with time zone) AS month,
    m.blockchain,
    m.token_pair,
    CAST(NULL AS varchar) AS version,
    'M1: manual exclusion from v1 of the project (audited)' AS rule,
    ROUND(SUM(p.volume_usd), 0) AS volume_usd,
    SUM(p.transactions) AS transactions,
    CAST(NULL AS bigint) AS active_senders,
    CAST(NULL AS double) AS median_usd,
    ROUND(MAX(p.max_usd), 0) AS max_usd
FROM (VALUES
    ('robinhood', 'AI-WETH'),
    ('robinhood', 'COBIE-ETH'),
    ('ethereum', 'MAHC-WETH')
) AS m(blockchain, token_pair)
LEFT JOIN pair_month p
    ON p.blockchain = m.blockchain
   AND p.token_pair = m.token_pair
GROUP BY m.blockchain, m.token_pair

ORDER BY 6 DESC;
