-- Gaia DR3 measurements for the SDSS spectroscopic sample (v3, query 1)
-- Output: data/sdss_spec_gaiadr3.csv (32,321 rows)
--
-- Before running: log in to the Gaia archive and upload data/sdss_wd_ids.vot as a user table
-- named sdss_wd_ids. Replace <username> with your archive username.
--
-- No cuts here: the notebook applies the same cuts as field_v3_pm.sql, on the same columns.
-- Labels are not uploaded; they are joined back from gaiaedr3_wd_sdssspec.csv on source_id.

SELECT g.source_id, g.ra, g.dec, g.l, g.b,
       g.parallax, g.parallax_error, g.parallax_over_error,
       g.pm, g.pmra, g.pmra_error, g.pmdec, g.pmdec_error,
       g.phot_g_mean_mag, g.phot_bp_mean_mag, g.phot_rp_mean_mag,
       g.phot_g_mean_flux_over_error, g.phot_bp_mean_flux_over_error,
       g.phot_rp_mean_flux_over_error, g.ruwe
FROM user_<username>.sdss_wd_ids AS s
JOIN gaiadr3.gaia_source AS g ON g.source_id = s.source_id
