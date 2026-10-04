-- 03_version_mix_cleaned.sql  (Dune query 8872041)
-- Monthly USD volume and share by protocol version, last 12 complete calendar months.

WITH clean_trades AS (
    SELECT t.*
    FROM dex.trades t
    LEFT JOIN dune.moonlesssssss.result_uniswap_excluded_pair_months e
        ON e.blockchain = t.blockchain
       AND e.token_pair = t.token_pair
       AND (e.version IS NULL OR e.version = t.version)
       AND (e.month IS NULL OR e.month = date_trunc('month', t.block_time))
    WHERE t.project = 'uniswap'
      AND t.amount_usd IS NOT NULL
      AND t.block_time >= date_trunc('month', current_timestamp) - INTERVAL '12' MONTH
      AND t.block_time < date_trunc('month', current_timestamp)
      AND e.token_pair IS NULL
      AND t.tx_hash NOT IN (
        0x951ad0f7ae53f38d9d983e9e9e720daccbdb674e13e3f7aad68568d0f9fe397a,
        0xa9e4d1329af152e6388433f52afb299489e35ef96f328bbc56fe84fa8f0b5833,
        0xf5872c19325262b25ef74dad347c1cbc81bc92e71d2a2bdbea9e22cc97f82b2c,
        0x818c97aad39b84bd6502bf8fe56559648a0218dce1f2e94d5aff2a16e1691553,
        0x675ee1d70de1437ebb21e68a7d87740b57006ff38e42ba08be50452078690bbf,
        0x82946e71476288c9a8dc58b3d5f03f0ab98280fb9d281bcc7d60ba9f996e5f47,
        0xd4077f3a90015b5c8fe4e1e7195fcb5b25c1ec97c4997d7a21bc726a3d8a7d4d,
        0x093336d4c3cd9ec528494d84fe53cce5e061f8cb86c122d58dde02f3cd94b749
      )
)
,

monthly_version AS (
    SELECT
        date_trunc('month', block_time) AS month,
        version,
        SUM(amount_usd) AS volume_usd
    FROM clean_trades
    GROUP BY 1, 2
)

SELECT
    month,
    version,
    ROUND(volume_usd / 1e9, 2) AS volume_usd_bn,
    ROUND(100.0 * volume_usd / SUM(volume_usd) OVER (PARTITION BY month), 2) AS monthly_share_pct
FROM monthly_version
ORDER BY month, version;
