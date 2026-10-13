-- Field-star negatives, v2 (superseded): within 1 kpc, parallax known to 20% or better
-- Output: archive/data/gaia_1kpc.csv (574,231 rows)
--
-- Run while logged in (anonymous queries are capped at 3,000,000 rows).
-- Its cuts matched section 2b of the v2 notebook (in git history; the current notebook is v3).

SELECT g.source_id, g.parallax, g.parallax_error, g.parallax_over_error,
       g.phot_g_mean_mag, g.phot_bp_mean_mag, g.phot_rp_mean_mag,
       g.pmra, g.pmdec, g.ruwe, g.ra, g.dec
FROM gaiadr3.gaia_source AS g
WHERE g.parallax >= 1                              -- within 1 kpc
  AND g.parallax_over_error >= 5                   -- parallax known to 20% or better
  AND g.phot_g_mean_flux_over_error >= 50
  AND g.phot_bp_mean_flux_over_error >= 10
  AND g.phot_rp_mean_flux_over_error >= 10
  AND g.phot_g_mean_mag < 20.7                     -- SDSS depth: no field stars fainter than any positive
  AND g.random_index < 18000000                    -- uniform random subsample; TODO: confirm the N used
