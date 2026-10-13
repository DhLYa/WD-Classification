# Data notes

Task: binary classification of white dwarfs (1) vs other objects (0) using Gaia DR3 photometry and
astrometry, with labels set by spectroscopy rather than by position in the colour-magnitude
diagram.

The data files are not in the repository (about 3.3 GB). This page records where each one comes
from, what's in it and how the notebook uses it. Only this file and `sdss_wd_ids.vot` are tracked
in git.

## 1. Files

**Current (v3)**, in `data/`:

| File | Rows | Role | Source |
|---|---|---|---|
| `gaiaedr3_wd_sdssspec.csv` | 42,007 spectra (32,321 objects) | **Labels** (`spec_class`) for white dwarfs and confirmed contaminants | `raw/gaiaedr3_wd_sdssspec.fits.gz`: Gaia EDR3 white dwarf candidates cross-matched with SDSS DR16 spectroscopy (Gentile Fusillo et al. 2021), converted with `notebooks/01_fits_to_csv.ipynb` |
| `gaiaedr3_wd_main.csv` | 1,280,266 | White dwarf candidate catalogue, used **only** to clean white dwarfs (`Pwd > 0.75`) out of the field-star negatives | `raw/gaiaedr3_wd_main.fits.gz`: Gaia EDR3 white dwarf candidates, main catalogue (Gentile Fusillo et al. 2021), converted the same way |
| `sdss_wd_ids.vot` | 32,321 | Unique `source_id`s of the spectroscopic sample, for upload to the Gaia archive | Built from `gaiaedr3_wd_sdssspec.csv`. VOTable keeps the 19-digit IDs exact |
| `sdss_spec_gaiadr3.csv` | 32,321 | Gaia DR3 measurements for the spectroscopic sample | [`queries/sdss_spec_gaiadr3.sql`](../queries/sdss_spec_gaiadr3.sql) |
| `gaia_field_pm.csv` | 3,031,564 | Field-star negatives | [`queries/field_v3_pm.sql`](../queries/field_v3_pm.sql) |

**Superseded or unused**, in `archive/data/` (not used by the current notebook):

| File | Rows | Version | Query |
|---|---|---|---|
| `gaia_400pc.csv` | 3,000,000 | v1 field stars (truncated by the anonymous row cap) | [`queries/field_v1_400pc.sql`](../queries/field_v1_400pc.sql) |
| `gaia_1kpc.csv` | 574,231 | v2 field stars | [`queries/field_v2_1kpc.sql`](../queries/field_v2_1kpc.sql) |
| `gaia_100pc.csv` | 235,729 | Early exploratory pull (parallax ≥ 10 mas, within 100 pc); not used by any notebook in this repository | Not recorded |

## 2. Getting the data

**Gentile Fusillo catalogues.** Warwick astronomy group, "Catalogues hosted at Warwick":
<https://warwick.ac.uk/fac/sci/physics/research/astro/research/catalogues/>

Files on that page relevant to this project:

- Gaia EDR3 white dwarf candidates (current):
  - `gaiaedr3_wd_main.fits.gz`: main catalogue
  - `gaiaedr3_wd_sdssspec.fits.gz`: cross-match with SDSS DR16 spectroscopy
  - `gaiaedr3_wd_rpm_ext.fits.gz`: proper-motion extension (not used)
- Gaia DR2 white dwarf candidates, V2.1 (source of the original, circular labels; no longer used):
  - `gaia_dr2_white_dwarf_candidates_v2.1.csv`
  - `gaia-sdss_white_dwarf_catalogue_v2.1.csv`
  - Also on VizieR: J/MNRAS/482/4570

The original labels came from V2.1 of the DR2 catalogue (the page also lists V2.0 and V1.0).

Put the `.fits.gz` files in `data/raw/` and convert each with `notebooks/01_fits_to_csv.ipynb`,
which writes the CSV to `data/` under the name the analysis notebook loads.

**Gaia DR3 files.** From the [ESA Gaia archive](https://gea.esac.esa.int/archive/), logged in
(anonymous queries are capped at 3,000,000 rows):

1. Upload `sdss_wd_ids.vot` as a user table named `sdss_wd_ids`.
2. Run `queries/sdss_spec_gaiadr3.sql`, with your username filled in, and save the result as
   `sdss_spec_gaiadr3.csv`. It applies no cuts, so it returns all 32,321 objects.
3. Run `queries/field_v3_pm.sql` and save the result as `gaia_field_pm.csv`. It uses
   `random_index < 94000000`, a uniform ~5% sample of the ~58M stars that pass the cuts.

Gaia EDR3 and DR3 share `source_id`s, astrometry and photometry, so the EDR3-based catalogues join
directly onto DR3.

## 3. Columns

**`sdss_spec_gaiadr3.csv` and `gaia_field_pm.csv`** have identical columns from `gaiadr3.gaia_source`,
so both samples are cut and featurised the same way:

| Column | Meaning |
|---|---|
| `source_id` | Gaia DR3 source identifier (same as EDR3) |
| `ra`, `dec` | Sky position (degrees) |
| `l`, `b` | Galactic longitude and latitude (degrees), used for the footprint cut |
| `parallax`, `parallax_error`, `parallax_over_error` | Parallax (mas), its error and S/N. Can be negative for distant sources |
| `pm`, `pmra`, `pmra_error`, `pmdec`, `pmdec_error` | Total proper motion and its components with errors (mas/yr) |
| `phot_g_mean_mag`, `phot_bp_mean_mag`, `phot_rp_mean_mag` | Apparent G, BP and RP magnitudes |
| `phot_*_mean_flux_over_error` | Flux S/N in each band, used for the photometric quality cuts |
| `ruwe` | Renormalised unit weight error: ≈ 1 for a well-behaved single star; < 1.4 is the standard threshold for reliable astrometry |

**`gaiaedr3_wd_sdssspec.csv`**: the notebook uses only `source_id`, `dr2_source_id` (carried along,
unused), `spec_class` (the label) and `S/N` (to choose between duplicate spectra). Its own Gaia
columns are no longer used, because the DR3 query provides them. It also has SDSS ugriz photometry
(`umag` to `zmag`), unused so far but planned for spectral subtypes (`notebooks/03_wd_subtypes.ipynb`).

**`gaiaedr3_wd_main.csv`**: only `source_id` and `Pwd` are loaded.

## 4. Labels

From `spec_class` in `gaiaedr3_wd_sdssspec.csv`. Strip whitespace first: FITS strings are
space-padded, and `.isin()` fails silently otherwise.

- **Label 1, white dwarf:** DA, DA:, DAB, DABZ, DAH, DAO, DAZ, DA_DQ, DApec, DB, DB:, DBA, DBAH,
  DBH, DBZ, DBAZ, DC, DC:, DO, DOX, DQ, DQ:, DQZ, pecDQ, hotDQ, DZ, DZ:, DZA, DZAB, DZB, DZBA, DZH,
  WD, WDpec, MWD, PG1159
- **Label 0, confirmed contaminant:** STAR, QSO, GALAXY, CV
- **Dropped:** everything else. In practice: UNKN and Unreli (unknown or unreliable spectra), and
  DA_MS, DA_MS:, DC_MS, DB_MS (white dwarf + main-sequence binaries, with blended photometry).

Both lists are matched explicitly, so an unlisted class is dropped rather than silently becoming a
negative. An earlier version labelled a `DApec` white dwarf (one object, two spectra) as a
contaminant this way.

**Duplicates:** 7,467 objects have several spectra. Objects whose spectra disagree on the label (62)
are dropped; the rest keep their highest-S/N spectrum. This leaves 30,383 objects: 25,620 white
dwarfs and 4,763 contaminants.

**Never used as features**, because they leak the label: `Pwd`, `PHwd`, and every atmosphere-fit
column (`teff_*`, `logg_*`, `mass_*`, `chisq_*` and their errors `eteff_*`, `elogg_*`, `emass_*`).
They are derived assuming the object is a white dwarf, or from colour-magnitude position.

## 5. Selection cuts (v3)

Applied in `queries/field_v3_pm.sql` for the field stars, and by `passes_selection()` in the
notebook for the spectroscopic sample. The notebook asserts that every field star passes
`passes_selection()`, so the two can't drift apart.

| Cut | Meaning |
|---|---|
| `phot_g_mean_mag < 20.7` | SDSS depth (99th percentile of the spectroscopic sample) |
| G flux S/N ≥ 50; BP and RP flux S/N ≥ 10 | Good photometry |
| `ruwe < 1.4` | Clean astrometric solution |
| pm² ≥ 5 √((pmra·σ_pmra)² + (pmdec·σ_pmdec)²) | Proper motion S/N ≥ 5, with errors propagated from both components |
| \|b\| ≥ 20°, dec ≥ −10° | Approximate SDSS footprint: 97.9% of the spectroscopic sample has \|b\| ≥ 20° and 99.4% has dec ≥ −10° |

There is deliberately no parallax cut (see section 7). Objects passing:

| | All | Pass |
|---|---|---|
| Spectroscopic white dwarfs | 25,620 | 20,472 |
| Spectroscopic contaminants | 4,763 | 3,773 (3,607 STAR, 157 CV, 5 GALAXY, 4 QSO) |

## 6. Building the modelling dataset

**Features**, computed the same way for both samples:

- `H_G = G + 5 log10(pm / 1000) + 5`: reduced proper motion (pm in mas/yr). Equal to
  M_G + 5 log10(v_t / 4.74), so it stands in for absolute magnitude without needing a parallax.
- `bp_rp = BP - RP` and `g_rp = G - RP`: two independent colours.
- `parallax`: as measured, with no cut.

**Negatives:** field stars from `gaia_field_pm.csv`, cleaned in two steps:

1. Remove every `source_id` in the spectroscopic file (1,237), including objects dropped from
   labelling (unreliable spectra, binaries, conflicting labels). They aren't clean negatives.
2. Remove high-confidence catalogue white dwarfs, `Pwd > 0.75` (3,602). Lower-`Pwd` candidates are
   kept as hard negatives. Using `Pwd` to *clean* negatives is fine because it's never a feature.

This leaves 3,026,725 field stars. With the 3,773 spectroscopic contaminants, there are 3,030,498
negatives against 20,472 positives (0.67% positive). The field stars are a random subsample, so
that share is set by the sampling fraction, not the true sky density.

Residual contamination (white dwarfs missed by both catalogues) remains among the field stars and
sets a soft ceiling on precision.

**Then:** stratified train/test split (80/20) → undersample the majority class in the training set
only (10:1) → fit the scaler on the training set.

**Models:** L1 logistic regression, linear SVM, random forest, XGBoost.

**Metrics:** PR-AUC (headline), plus precision, MCC, balanced accuracy and false alarms per white
dwarf at a threshold giving ≥ 99% recall. False alarms are also reported separately for field stars
and spectroscopic contaminants.

## 7. Version history

| | v1 | v2 | v3 (current) |
|---|---|---|---|
| Field file | `gaia_400pc.csv` | `gaia_1kpc.csv` | `gaia_field_pm.csv` |
| Field cuts | parallax ≥ 2.5 mas, parallax/error ≥ 20, G S/N ≥ 50, BP/RP S/N ≥ 20, `astrometric_excess_noise` < 1, proper-motion cuts | parallax ≥ 1 mas, parallax/error ≥ 5, G S/N ≥ 50, BP/RP S/N ≥ 10, G < 20.7 | Section 5 |
| Spectroscopic Gaia data | From the SDSS file; S/N derived from magnitude errors | Same | DR3 user-table join |
| Distance/brightness feature | Absolute magnitude | Absolute magnitude | Reduced proper motion |
| White dwarfs / contaminants kept | 6,831 / 46 | 17,794 / 224 | 20,472 / 3,773 |

- **v1 → v2:** matching the 5% parallax cut kept only 27% of the spectroscopic white dwarfs and 1% of
  the contaminants. White dwarfs are faint: at the sample's median G of 19.4, a 5%-precise parallax
  needs the star to be within ~150 pc. Contaminants are mostly too distant.
- **v2 → v3:** parallax cuts can't keep distant contaminants at all, so v3 cuts on proper motion
  instead. Gaia measures proper motions far more precisely relative to their size.

Before v1, labels came from the Gentile Fusillo DR2 catalogue's `Pwd`. Those labels are defined by
colour-magnitude position, the same space as the features, which gave a circular PR-AUC of 1.0.

## 8. Known issues and checks

**Resolved:**

1. **3,000,000-row cap (v1).** The v1 output had exactly 3,000,000 rows, the archive's cap for
   anonymous queries, so it was truncated and possibly biased by sky position. Fixed from v2 on by
   sampling with `random_index`, which gives a uniform sample of a chosen size. v3 returned more
   than 3,000,000 rows, so it has to be run logged in.
2. **Proper-motion cut bug (v1).** `pmra_error/pmra <= 0.05` always passes for negative `pmra` and
   favours fast-moving stars. Removed in v2. v3 uses a properly propagated proper-motion S/N.
3. **No proper motions for the positives.** The SDSS file has no `pmra`/`pmdec`. Fixed in v3 by the
   user-table join. Note: `sqrt(ra**2 + dec**2)` is NOT proper motion (it is angular distance from
   the coordinate origin) and must never be used.
4. **Unmatched quality cuts.** `astrometric_excess_noise` (v1) applied to the field stars only. v3
   applies `ruwe < 1.4` to both samples from the same column.
5. **Duplicate spectra and the silent label default.** See section 4.

**Open:**

6. **Contaminant population.** Label-0 objects in the spectroscopic sample are whatever SDSS chose to
   observe, not a representative population.
7. **Inherited preselection.** The spectroscopic sample consists of Gentile Fusillo candidates, which
   were selected using parallax-based absolute magnitudes. The field stars weren't, so part of
   parallax's importance may reflect this preselection.
8. **Approximate footprint.** The |b|/dec box only approximates the SDSS footprint. Matching on
   HEALPix pixels that contain spectroscopic objects (`GAIA_HEALPIX_INDEX`) would be exact.
9. **Release IDs.** All matching uses DR3 `source_id`s (identical to EDR3). `dr2_source_id` is
   carried along but must not be mixed into any `.isin()` match, or matches fail silently.
10. **v2 sampling limit not recorded.** `queries/field_v2_1kpc.sql` lists
    `random_index < 18000000`, but the value actually used wasn't saved.

## 9. Citations

- Gentile Fusillo, N. P. et al. (2019). A Gaia Data Release 2 catalogue of white dwarfs and a
  comparison with SDSS. *MNRAS*, 482, 4570. arXiv:1807.03315.
- Gentile Fusillo, N. P. et al. (2021). A catalogue of white dwarfs in Gaia EDR3. *MNRAS*, 508, 3877.
- Gaia Collaboration, Vallenari, A. et al. (2023). Gaia Data Release 3: Summary of the content and
  survey properties. *A&A*, 674, A1.
