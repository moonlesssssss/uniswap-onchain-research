-- 07_raw_vs_cleaned_monthly.sql  (Dune query 8890199)
-- For each of the last 12 complete months: raw volume, volume removed by the data-quality
-- rules (R1-R3, M1 plus 8 audited transaction hashes) and cleaned volume.

WITH base AS (
    SELECT
        date_trunc('month', t.block_time) AS month,
        t.amount_usd,
        (
            e.token_pair IS NOT NULL
            OR t.tx_hash IN (
                0x951ad0f7ae53f38d9d983e9e9e720daccbdb674e13e3f7aad68568d0f9fe397a,
                0xa9e4d1329af152e6388433f52afb299489e35ef96f328bbc56fe84fa8f0b5833,
                0xf5872c19325262b25ef74dad347c1cbc81bc92e71d2a2bdbea9e22cc97f82b2c,
                0x818c97aad39b84bd6502bf8fe56559648a0218dce1f2e94d5aff2a16e1691553,
                0x675ee1d70de1437ebb21e68a7d87740b57006ff38e42ba08be50452078690bbf,
                0x82946e71476288c9a8dc58b3d5f03f0ab98280fb9d281bcc7d60ba9f996e5f47,
                0xd4077f3a90015b5c8fe4e1e7195fcb5b25c1ec97c4997d7a21bc726a3d8a7d4d,
                0x093336d4c3cd9ec528494d84fe53cce5e061f8cb86c122d58dde02f3cd94b749
            )
        ) AS is_excluded
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
)

SELECT
    month,
    ROUND(SUM(amount_usd) / 1e9, 2) AS raw_volume_usd_bn,
    ROUND(SUM(CASE WHEN is_excluded THEN amount_usd ELSE 0 END) / 1e9, 2) AS excluded_volume_usd_bn,
    ROUND(SUM(CASE WHEN NOT is_excluded THEN amount_usd ELSE 0 END) / 1e9, 2) AS cleaned_volume_usd_bn,
    ROUND(100.0 * SUM(CASE WHEN is_excluded THEN amount_usd ELSE 0 END) / SUM(amount_usd), 1) AS excluded_share_pct
FROM base
GROUP BY 1
ORDER BY 1;
