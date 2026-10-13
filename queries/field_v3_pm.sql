-- Field-star negatives, v3 (query 2): proper-motion cuts instead of parallax cuts
-- Output: data/gaia_field_pm.csv
--
-- Run while logged in (anonymous queries are capped at 3,000,000 rows).
-- random_index runs over all ~1.81 billion DR3 sources. N = 1,000,000 returned ~32k rows,
-- so ~58M stars pass these cuts; N = 94,000,000 gives ~3M rows.
-- TODO: record the N actually used here.
--
-- Every cut must match the selection cell in notebooks/02_wd_classification.ipynb.

SELECT g.source_id, g.ra, g.dec, g.l, g.b,
       g.parallax, g.parallax_error, g.parallax_over_error,
       g.pm, g.pmra, g.pmra_error, g.pmdec, g.pmdec_error,
       g.phot_g_mean_mag, g.phot_bp_mean_mag, g.phot_rp_mean_mag,
       g.phot_g_mean_flux_over_error, g.phot_bp_mean_flux_over_error,
       g.phot_rp_mean_flux_over_error, g.ruwe
FROM gaiadr3.gaia_source AS g
WHERE g.phot_g_mean_mag < 20.7
  AND g.phot_g_mean_flux_over_error >= 50
  AND g.phot_bp_mean_flux_over_error >= 10
  AND g.phot_rp_mean_flux_over_error >= 10
  AND g.ruwe < 1.4                                         -- clean astrometry
  AND g.pm * g.pm >= 5 * SQRT(POWER(g.pmra * g.pmra_error, 2)
                            + POWER(g.pmdec * g.pmdec_error, 2))   -- pm S/N >= 5
  AND ABS(g.b) >= 20 AND g.dec >= -10                      -- approximate SDSS footprint
  AND g.random_index < 94000000                            -- TODO: confirm N
