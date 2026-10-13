-- Field-star negatives, v1 (superseded): within 400 pc, parallax known to 5% or better
-- Output: archive/data/gaia_400pc.csv (3,000,000 rows: the anonymous-query cap, so truncated)
--
-- Known problems, fixed in later versions:
--   - pmra_error/pmra <= 0.05 lets every negative pmra through and favours fast-moving stars
--   - the astrometric_excess_noise and proper-motion cuts can't be applied to the spectroscopic sample
--   - the 5% parallax cut kept only 27% of the spectroscopic white dwarfs and 1% of the contaminants

SELECT
g.source_id,
g.phot_g_mean_mag - 5*log10(1000/g.parallax) + 5 AS g_mag_abs,
g.phot_bp_mean_mag - g.phot_rp_mean_mag AS phot_mag_dif,
g.parallax, g.parallax_error, g.parallax_over_error,
g.phot_bp_mean_mag, g.phot_rp_mean_mag, g.phot_g_mean_mag,
g.ra, g.ra_error, g.dec, g.dec_error,
ap.spectraltype_esphs AS class,
ap.classprob_dsc_combmod_whitedwarf AS white_dwarf_prob
FROM gaiadr3.gaia_source g
LEFT JOIN gaiadr3.astrophysical_parameters ap ON g.source_id = ap.source_id
WHERE g.parallax >= 2.5
  AND g.parallax_error/g.parallax <= 0.05
  AND g.astrometric_excess_noise < 1
  AND g.phot_g_mean_flux_over_error >= 50
  AND g.phot_bp_mean_flux_over_error >= 20
  AND g.phot_rp_mean_flux_over_error >= 20
  AND g.pmra_error/g.pmra <= 0.05
  AND g.pmdec_error/g.pmdec <= 0.05
