# White Dwarf Classification with Gaia, Without Data Leakage

Finding white dwarfs among Gaia stars within 1 kpc using only Gaia photometry and parallaxes,
with labels from SDSS spectroscopy and every known leakage path closed off.

White dwarfs make up about 3% of the dataset, so this is a rare-object detection problem. The
best model (logistic regression) recovers **99% of spectroscopically confirmed white dwarfs at
99.1% precision**: 33 false alarms against 114,463 test negatives.

The bigger part of the project is getting a result like that honestly. A first version scored a
perfect PR-AUC of 1.0, and it was wrong. Most of the work went into finding out why.

> **In progress (v3):** the results on this page use the v2 dataset (parallax-based cuts). v3
> replaces parallax cuts with proper-motion cuts and adds reduced proper motion as a feature, which
> raises the number of hard negatives from 224 to 3,773. See
> [v3: reduced proper motion](#v3-reduced-proper-motion-in-progress).

![Gaia H-R diagram of the combined dataset: field stars as a density map, spectroscopic white dwarfs in blue](figures/hr_diagram.png)

## Leakage traps, and how each one is handled

| Trap | What goes wrong | Fix |
|---|---|---|
| **Circular labels** | The usual white dwarf labels (`Pwd` from the Gentile Fusillo catalogue) are *defined* by position on the colour-magnitude diagram, which is built from the same quantities used as features. The model just learns the catalogue's selection boundary. This produced the original PR-AUC of 1.0. | Labels come from SDSS spectra (`spec_class`), which are independent of photometry. |
| **Label-derived columns** | `teff_*`, `logg_*`, `mass_*` and `Pwd`/`PHwd` are fitted on the assumption that the object *is* a white dwarf. | Excluded from the features. |
| **Selection-function mismatch** | The field stars come from a Gaia query with parallax, parallax-precision and photometric quality cuts. The spectroscopic sample has no such cuts, so parallax and apparent brightness reveal *which catalogue* an object came from, not what it is. | The query's cuts are applied to the spectroscopic sample too. Afterwards, permutation importance for parallax is ≈ 0. The first query's strict cuts discarded most of the spectroscopic sample, so the query was loosened ([details below](#field-star-query-and-the-culling-problem)). |
| **Duplicate spectra** | 7,467 objects have several SDSS spectra, so copies of one star can end up in both train and test. | One row per object, keeping the highest-S/N spectrum. The 62 objects whose spectra disagree on the label are dropped. |
| **Imbalance handled in the wrong order** | Undersampling before the split gives a test set with a fake class balance and inflated metrics. | Split first (stratified), undersample only the training set (10:1), and fit the scaler on train only. The test set keeps the dataset's ~32:1 imbalance. |
| **Negatives that are secretly positives** | The field-star sample contains uncatalogued white dwarfs. | Field stars that are high-confidence catalogue white dwarfs (`Pwd > 0.75`) are removed. Lower-`Pwd` candidates stay in as hard negatives. `Pwd` is never a feature. |

## Data

| File | Rows | Role | Source |
|---|---|---|---|
| `gaiaedr3_wd_sdssspec.csv` | 42,007 spectra | Positives (white dwarfs) and confirmed contaminants (STAR, QSO, GALAXY, CV) | `gaiaedr3_wd_sdssspec.fits.gz`: Gaia EDR3 white dwarf candidates cross-matched with SDSS DR16 spectroscopy (Gentile Fusillo et al. 2021) |
| `gaiaedr3_wd_main.csv` | 1.28M candidates | Used **only** to clean white dwarfs out of the negatives | `gaiaedr3_wd_main.fits.gz`: Gaia EDR3 white dwarf candidate main catalogue (Gentile Fusillo et al. 2021) |
| `gaia_1kpc.csv` | 574,231 | Field-star negatives (v2, current results) | [`queries/field_v2_1kpc.sql`](queries/field_v2_1kpc.sql) on the [ESA Gaia archive](https://gea.esac.esa.int/archive/) (Gaia DR3) |
| `sdss_wd_ids.vot` | 32,321 | Unique `source_id`s of the spectroscopic sample, uploaded to the Gaia archive as a user table (v3) | Built from `gaiaedr3_wd_sdssspec.csv` |
| `sdss_spec_gaiadr3.csv` | 32,321 | Gaia DR3 measurements (including proper motions and `ruwe`) for the spectroscopic sample (v3) | [`queries/sdss_spec_gaiadr3.sql`](queries/sdss_spec_gaiadr3.sql) |
| `gaia_field_pm.csv` | **TBD** <!-- TODO: fill in once query 2 finishes --> | Field-star negatives (v3, pending) | [`queries/field_v3_pm.sql`](queries/field_v3_pm.sql) |
| `gaia_400pc.csv` | 3,000,000 | Field-star negatives for the first version (archived, not used) | [`queries/field_v1_400pc.sql`](queries/field_v1_400pc.sql), replaced by v2 (see [below](#field-star-query-and-the-culling-problem)) |

Both catalogue files are on the Warwick astronomy group's
[catalogue page](https://warwick.ac.uk/fac/sci/physics/research/astro/research/catalogues/), under
the Gaia EDR3 white dwarf candidates. They download as FITS and are converted to CSV with
`notebooks/01_fits_to_csv.ipynb`.

The data files total about 3 GB and are **not included** in this repository. Download them from
the sources above into `data/`, with the FITS downloads in `data/raw/`. Provenance details,
label definitions and known data issues are in
[`data/white_dwarf_data_notes.txt`](data/white_dwarf_data_notes.txt).

**Pipeline:**

```
SDSS spectra (42,007)
  → keep definite labels, one spectrum per object  →  30,383 objects
  → apply the field-star selection cuts            →  17,794 white dwarfs + 224 contaminants
Gaia field stars (574,231)
  → remove objects already in the spectroscopic sample, and catalogue WDs with Pwd > 0.75
                                                   → 572,090 field stars
Combined: 17,794 positives vs 572,314 negatives (3.0% positive)
```

The field stars are a uniform random subsample of everything that passes the query, so the 3%
positive share is set by the sampling fraction. Among all stars that pass the same cuts, white
dwarfs are much rarer.

**Features:** absolute G magnitude, BP−RP colour, G−RP colour and parallax. Together they hold
exactly the information in the G, BP and RP magnitudes plus parallax. A longer list of derived
magnitudes would only add exact duplicates, which split feature importance and hide what the model
actually relies on.

## Field-star query and the culling problem

### What went wrong

The positives and negatives have to pass the same selection. Otherwise the model learns which
survey an object came from rather than what it is. Matching the first field-star query (v1, below)
fixed that leak, but it discarded most of the spectroscopic sample:

| Spectroscopic objects | Total | Pass all v1 cuts | Main reason for failing |
|---|---|---|---|
| White dwarfs | 25,620 | 6,831 (27%) | 5% parallax precision: only 28% pass |
| Contaminants | 4,763 | 46 (1%) | Too distant: median parallax 0.26 mas (~4 kpc), and quasars and galaxies have no real parallax |

Most white dwarfs failed because they're faint, not because they're far away: 68% are within 400 pc.
White dwarfs are intrinsically dim, so SDSS white dwarfs have a median apparent G of 19.4, and
Gaia's parallax errors grow quickly with faintness. At G = 19–20 the typical error is 0.34 mas, so
5% precision needs a parallax of 6.8 mas or more. That means being within about 150 pc, which most
are not. The field stars pass easily: they're mostly main-sequence stars, much brighter at the same
distance (median G 15.8).

Without the matching, the leak is large. A random forest given **only parallax and apparent G** (no
colours) scores PR-AUC 0.84 on the unmatched data, against 0.45 once the cuts match. Some of that
0.45 is real physics, since apparent magnitude plus parallax gives absolute magnitude. The jump to
0.84 comes from the survey difference.

### The fix: loosen the cuts

The parallax precision cut is what limits the sample, so the new query relaxes it and extends the
distance limit to 1 kpc. Spectroscopic objects surviving each option:

| Cuts (applied to both samples) | White dwarfs | Contaminants |
|---|---|---|
| v1: parallax ≥ 2.5, parallax/error ≥ 20, BP/RP S/N ≥ 20 | 6,831 | 46 |
| parallax ≥ 2.5, parallax/error ≥ 10, BP/RP S/N ≥ 10 | 11,797 | 87 |
| parallax ≥ 1, parallax/error ≥ 10, BP/RP S/N ≥ 10 | 12,638 | 125 |
| **v2: parallax ≥ 1, parallax/error ≥ 5, BP/RP S/N ≥ 10, G < 20.7** | **17,794** | **224** |

v2 keeps about 2.6× the white dwarfs and 5× the hard contaminants. The trade-off is noisier absolute
magnitudes: up to ±0.4 mag at parallax/error = 5, against ±0.1 mag in v1. That blurs the region
where the white dwarf and main sequences approach each other, which makes the problem harder and
more realistic.

### Field-star query (v2)

Run on the [ESA Gaia archive](https://gea.esac.esa.int/archive/) (Gaia DR3) while logged in.
Anonymous queries are capped at 3,000,000 rows. Also saved as
[`queries/field_v2_1kpc.sql`](queries/field_v2_1kpc.sql).

```sql
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
  AND g.random_index < 18000000                    -- uniform ~1% subsample; tune after a COUNT(*)
```

Changes from v1:

- **Looser parallax and photometry cuts**, as in the table above.
- **Faint limit `G < 20.7`**, the 99th percentile of the spectroscopic sample. Without it, the field
  would contain stars fainter than any positive, giving a reverse shortcut: "very faint → never a
  white dwarf".
- **Random subsample via `random_index`** instead of a truncated result. `random_index` is a random
  ordering of all ~1.8 billion Gaia sources, so `random_index < N` returns a uniform sample. That
  removes the sky-position bias of v1's row-capped output. Run `SELECT COUNT(*)` with the same
  `WHERE` clause first, then set N to give a few million rows.
- **Proper-motion cuts removed.** `pmra_error/pmra <= 0.05` let every negative `pmra` through,
  favoured fast-moving stars, and couldn't be applied to the spectroscopic sample.
- **`astrometric_excess_noise` cut removed**, because it couldn't be applied to the spectroscopic
  sample either. `ruwe` is returned so a quality cut can be added later, on both samples.
- **`astrophysical_parameters` join removed.** Its `class` and `white_dwarf_prob` columns were only
  used for exploration.
- **`g_mag_abs` and `phot_mag_dif` are no longer computed in the query.** The notebook derives all
  features from the raw magnitudes and parallax, the same way for both samples.

The notebook's selection cell (section 2b) applies the same cuts to the spectroscopic sample. If
you change the query, change that cell to match.

The superseded v1 query is in [`queries/field_v1_400pc.sql`](queries/field_v1_400pc.sql). It
returned exactly 3,000,000 rows, the archive's cap for anonymous queries, so its output was almost
certainly truncated.

## v3: reduced proper motion (in progress)

### Why

Even with the v2 cuts, only 224 of the 4,763 spectroscopic contaminants survive. Most are halo stars
thousands of parsecs away, or quasars and galaxies, so their parallaxes are essentially noise. No
parallax-based cut can keep them, and they're exactly the hard negatives the evaluation needs.

Proper motion avoids this. For a typical disk star, the proper motion in mas/yr is several times
the parallax in mas, while Gaia measures both to similar precision. So a star whose parallax is noise
can still have a well-measured proper motion. **Reduced proper motion** turns it into a stand-in for
absolute magnitude that needs no parallax:

H_G = G + 5 log₁₀(μ) + 5 = M_G + 5 log₁₀(v_t / 4.74)

with μ in arcsec/yr and v_t the transverse velocity in km/s. White dwarfs still sit well below the
main sequence in colour vs H_G. Fast-moving halo stars are shifted toward them, which is exactly
where the hard contaminants are.

### How

Both samples now come from the **same Gaia columns, with the same cuts**:

1. Upload the spectroscopic `source_id`s ([`data/sdss_wd_ids.vot`](data/sdss_wd_ids.vot)) to the
   Gaia archive as a user table, and pull their Gaia DR3 measurements without cuts
   ([`queries/sdss_spec_gaiadr3.sql`](queries/sdss_spec_gaiadr3.sql)). Labels are joined back locally
   on `source_id`.
2. Pull the field stars with the cuts applied in the query
   ([`queries/field_v3_pm.sql`](queries/field_v3_pm.sql)), and apply the identical cuts to the
   spectroscopic sample in the notebook.

| Cut | v2 | v3 |
|---|---|---|
| Distance | parallax ≥ 1 mas | none |
| Astrometric precision | parallax/error ≥ 5 | proper motion S/N ≥ 5 |
| Astrometric quality | none | `ruwe < 1.4`, on both samples |
| Photometry | G S/N ≥ 50, BP/RP S/N ≥ 10, G < 20.7 | unchanged |
| Sky area | all-sky | \|b\| ≥ 20°, dec ≥ −10° (approximate SDSS footprint) |

The sky cut is new. Without a parallax limit, the proper-motion distribution and the disk/halo mix
both depend on direction. The SDSS objects sit at high galactic latitude (median |b| = 49°), so an
all-sky field sample would let the model learn sky position. The cut removes about 2.5% of the
spectroscopic sample.

### Status

| | v2 | v3 |
|---|---|---|
| Spectroscopic white dwarfs passing the cuts | 17,794 | **20,472** |
| Spectroscopic contaminants passing the cuts | 224 | **3,773** (3,607 STAR, 157 CV, 9 QSO/galaxy) |
| Field stars | 572,090 | **TBD** <!-- TODO: gaia_field_pm.csv row count after removing catalogue WDs --> |
| Best PR-AUC | 0.997 (logistic regression) | **TBD** <!-- TODO --> |
| No-skill PR-AUC | 0.030 | **TBD** <!-- TODO --> |
| Test contaminants flagged as white dwarfs at 99% recall | 25–26 of 48 | **TBD** <!-- TODO --> |

The spectroscopic counts come from query 1. The rest waits on the field-star query (query 2)
and a v3 version of the notebook. That version will add H_G as a feature and keep parallax as a
plain feature with no cut on it.

<!-- TODO (v3): once results are in, update the intro, the pipeline block, Results, "What the
results mean", Limitations and the figures, then remove the in-progress notes. -->


## Results

Four models: L1 logistic regression, linear SVM, random forest and XGBoost. They're evaluated on a
held-out test set of 3,559 white dwarfs and 114,463 negatives, with no resampling. Each model uses
its own threshold, set to the highest value that still recovers ≥ 99% of white dwarfs.

| Model | PR-AUC | Precision | Recall | MCC | False alarms per WD found |
|---|---|---|---|---|---|
| **Logistic regression** | **0.9967** | 0.991 | 0.990 | 0.990 | 0.009 |
| XGBoost | 0.9967 | 0.991 | 0.990 | 0.990 | 0.009 |
| Linear SVM | 0.9966 | 0.990 | 0.990 | 0.990 | 0.010 |
| Random forest | 0.9954 | 0.991 | 0.990 | 0.990 | 0.009 |

A no-skill classifier scores a PR-AUC of **0.030** (the share of white dwarfs in the test set).
ROC-AUC is 0.9999 for every model. That's typical under heavy imbalance, which is why PR-AUC is
the headline metric here.

![Precision-recall and ROC curves for all four models](figures/pr_roc_curves.png)

### What the results mean

- **Field white dwarfs are still easy to find.** Even out to 1 kpc with 20% parallaxes, the white
  dwarf sequence sits well below the main sequence (see the H-R diagram above). All four models
  are within 0.0013 PR-AUC of each other, and logistic regression is the best, so the classes are
  close to linearly separable in colour and absolute magnitude.
- **The real difficulty is the objects that sit on the white dwarf sequence.** Every model flags
  25–26 of the 48 spectroscopically confirmed contaminants in the test set as white dwarfs. After
  the cuts, the contaminants are mostly cataclysmic variables (CVs; 129 of 224, binaries that
  contain a white dwarf) and stars that SDSS targeted for their white-dwarf-like colours (90). Only
  7–10 of the 114,415 field stars are false alarms. Every false alarm in the error plot lies on or
  next to the white dwarf sequence, so some field-star false alarms may be real white dwarfs missing
  from both catalogues.
- **Missed white dwarfs** fall mostly at the cool, red, faint end of the sequence, which runs into
  the scatter of field stars with noisy parallaxes. Recall by spectral type is ≥ 97.6% for DA, DB,
  DC and DZ, but lower for the rarer DQ (92.5% of 53) and "other" types (94.6% of 74).
- **No shortcut features.** Permutation importance on the test set ranks G−RP colour and absolute
  magnitude far ahead of BP−RP. Parallax is ≈ 0, which confirms the selection-function leak is
  closed.

![Logistic regression errors on the H-R diagram](figures/error_analysis.png)

![Permutation importance for logistic regression](figures/permutation_importance.png)

### Effect of the looser query

| | v1 (≤ 400 pc, 5% parallaxes) | v2 (≤ 1 kpc, 20% parallaxes) |
|---|---|---|
| White dwarfs | 6,831 | 17,794 |
| Spectroscopic contaminants | 46 | 224 |
| Best PR-AUC | 0.994 (random forest) | 0.997 (logistic regression) |
| No-skill PR-AUC | 0.0023 | 0.030 |
| Test contaminants flagged as white dwarfs | 7 of 11 | 25–26 of 48 |

The PR-AUCs aren't directly comparable, because the share of positives differs by more than ten
times between the two datasets. The main gain from v2 is a hard-negative test set four times
larger. It confirms that about half of the spectroscopic contaminants look like white dwarfs to
every model, using Gaia photometry and parallax alone.

## Limitations

- **Artificial class balance.** The field stars are a random subsample, so the 3% white dwarf share
  is set by the sampling fraction. Among all stars that pass the cuts, white dwarfs are far rarer,
  so the same model would have lower precision at 99% recall. Recall doesn't depend on it.
- **Small hard-negative set.** 224 spectroscopic contaminants survive the cuts, and 48 are in the
  test set, so the contaminant numbers are indicative only.
- **Threshold chosen on the test set.** Recall is fixed by construction and precision is slightly
  optimistic. A separate validation split would remove this.
- **No astrometric quality cut.** Neither sample has a `ruwe` or `astrometric_excess_noise` cut,
  because the spectroscopic file lacks those columns. The field sample therefore includes some
  stars with spurious parallaxes, visible as scatter between the two sequences. Matching a `ruwe`
  cut needs the user-table approach. v3 adds `ruwe < 1.4` to both samples.
- **SDSS-selected samples.** The white dwarfs and contaminants are whatever SDSS chose to observe,
  not representative populations, and that targeting can't be reproduced for the field stars. Even
  the v2 cuts can't recover most contaminants: they're too distant for a meaningful parallax. v3
  keeps 3,773 of them by cutting on proper motion instead.
- **Scope.** The results apply to stars within 1 kpc with parallaxes known to 20% or better. At
  larger distances or with noisier parallaxes, the white dwarf and main sequences blur together.

## Reproducing

1. Create an environment (developed with Python 3.10):
   ```
   pip install -r requirements.txt
   ```
   `astropy` is only needed for the FITS conversion, and `mlflow` only for run tracking.
2. Download `gaiaedr3_wd_main.fits.gz` and `gaiaedr3_wd_sdssspec.fits.gz` from the
   [Warwick catalogue page](https://warwick.ac.uk/fac/sci/physics/research/astro/research/catalogues/)
   into `data/raw/`. Convert each one with `notebooks/01_fits_to_csv.ipynb` by setting `fits_path`
   to it. The CSVs are written to `data/` under the names the analysis notebook loads.
3. Run [`queries/field_v2_1kpc.sql`](queries/field_v2_1kpc.sql) on the Gaia archive and save the
   result as `data/gaia_1kpc.csv`.
4. Run `notebooks/02_wd_classification.ipynb` top to bottom, from the `notebooks/` folder: data paths
   are relative to it. The final section logs runs to an MLflow server at `localhost:5000`. Set
   `USE_MLFLOW = False` to skip it, or start a server from the repository root with
   `mlflow server --port 5000`.

All random seeds are fixed. A query with the same `random_index` limit returns the same field
stars, so a re-run reproduces the numbers above.

**v3 data (in progress):**

1. Log in to the Gaia archive and upload `data/sdss_wd_ids.vot` as a user table named
   `sdss_wd_ids`.
2. Run [`queries/sdss_spec_gaiadr3.sql`](queries/sdss_spec_gaiadr3.sql), with your username filled
   in, and save the result as `data/sdss_spec_gaiadr3.csv`.
3. Run [`queries/field_v3_pm.sql`](queries/field_v3_pm.sql) and save the result as
   `data/gaia_field_pm.csv`.
4. **TBD**: the v3 notebook. <!-- TODO: notebook name and run instructions once it exists -->

## Repository contents

```
├── notebooks/
│   ├── 01_fits_to_csv.ipynb          FITS → CSV conversion for the Gentile Fusillo catalogue files
│   └── 02_wd_classification.ipynb    Full analysis: labelling, selection matching, features, modelling, evaluation
├── queries/                          ADQL queries for the Gaia archive, one per data file
│   ├── sdss_spec_gaiadr3.sql         v3: Gaia data for the spectroscopic sample (user-table join)
│   ├── field_v3_pm.sql               v3: field stars, proper-motion cuts
│   ├── field_v2_1kpc.sql             v2: field stars within 1 kpc
│   └── field_v1_400pc.sql            v1: superseded
├── data/                             Not tracked (≈ 3 GB), apart from the notes and the upload file
│   ├── white_dwarf_data_notes.txt    Data provenance, label definitions and known issues
│   ├── sdss_wd_ids.vot               Spectroscopic source_ids for the Gaia archive upload
│   ├── raw/                          FITS downloads
│   └── *.csv                         Converted catalogues and the Gaia query outputs
├── figures/                          Figures used in this README
├── requirements.txt
└── LICENSE
```

## References

- Gentile Fusillo, N. P. et al. (2019). A Gaia Data Release 2 catalogue of white dwarfs and a
  comparison with SDSS. *MNRAS*, 482, 4570. [arXiv:1807.03315](https://arxiv.org/abs/1807.03315)
- Gentile Fusillo, N. P. et al. (2021). A catalogue of white dwarfs in Gaia EDR3. *MNRAS*, 508, 3877.
- Gaia Collaboration, Vallenari, A. et al. (2023). Gaia Data Release 3: Summary of the content and
  survey properties. *A&A*, 674, A1.

This work uses data from the European Space Agency mission *Gaia*, processed by the Gaia Data
Processing and Analysis Consortium (DPAC), and from the Sloan Digital Sky Survey.

## License

The code in this repository is released under the [MIT License](LICENSE). The data comes from the
sources listed above and is covered by their own terms.
