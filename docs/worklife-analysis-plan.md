# Work-life analysis plan: confirmed occupational diseases, 2019–2023

Investigation date: 16 October 2026. The implemented analysis follows the later clarifications where they differ from this plan: the primary statistic is an employment-normalised five-year count, not an annual incidence, and acquisition, the StatFin audit and the offline report are separate commands.

The sections below are the original investigation. The analysis, tests and report are implemented from this plan.

No `AGENTS.md` is present in this repository. The plan follows the existing pipeline layout in `_targets.R`, `R/`, `report.qmd`, `data_contract/contract.yaml`, `Makefile`, `renv.lock`, `tests/`, and `.github/workflows/ci.yml`.

The synthetic pediatric-visits example stays as it is. `make data`, `make test`, and `make report` continue to generate, test, and report that example only.

## 1. Verified data source, access method and licence

### Chosen dataset

**Työikäisten vahvistetut ammattitaudit** (Recognised occupational diseases in the working-age population), published in the Finnish Institute of Occupational Health (Työterveyslaitos, FIOH) Work-Life Knowledge service (Työelämätieto).

| Item | Verified value |
| --- | --- |
| Publisher | Työterveyslaitos |
| Service | Työelämätieto |
| Dataset page | https://www.tyoelamatieto.fi/fi/etusivu/aineistot/tyoikaisten-vahvistetut-ammattitaudit/ |
| English slug | `recognized-occupational-diseases-in-the-working-age-population` |
| Page dates | Published 12 March 2019, updated 20 May 2026 |
| Dashboard metadata | https://www.tyoelamatieto.fi/tellu-content/dashboards/occupational-diseases/metadata.json (`license`: `CC BY 4.0`, `contentType`: `national`, `updated` in `dashboards.json`: 2026-05-20) |
| Package pointer | https://www.tyoelamatieto.fi/tellu-content/fragments/fragmentTPSR/metadata.json names `datafile` `occupational-diseases-data-20052026.zip` and `dataurl` `occupational-diseases` |
| Download | https://www.tyoelamatieto.fi/tellu-data/data/occupational-diseases/occupational-diseases-data-20052026.zip |
| Download check | HTTP 200, `Content-Type: application/zip`, 292,234 bytes, on 16 October 2026 |
| SHA-256 | `ad2261e1bcc95b68d852e96e7718b740ee5bbcb3a15c70d6e6d5fd80ece5713f` |

The zip is the access method. Työelämätieto does not publish a separate, versioned API document for this dataset. The fragment metadata and the zip URL are the machine-readable path the service itself uses. The same TSV and DSV files are also requested individually by the dataset page; the zip is the self-describing package (README, licence, variable dictionary, and all periods).

The filename embeds the handover date 20 May 2026. A later publication can change that name. The implementation must pin this URL and hash and stop if the hash differs.

### What the package contains

Verified by opening the zip:

- `README - FI.txt`, `README - EN.txt`, `README - SV.txt`
- `LICENSE.txt`
- `variables.xlsx` (codebook)
- Nine period folders, `data_2011_2015` through `data_2019_2023`
- In each period: `data_A_*.tsv`, `data_B_*.tsv`, `data_C_*.tsv`, `workersPerOccupation_*.dsv`, `workersPerRegion.dsv`
- `finRegionsTopojson/` (region geometry; separate MIT licence; not used in this analysis)

The planned analysis uses only the latest window, **2019–2023**, and only:

- `data_2019_2023/data_A_2019_2023.tsv`
- `data_2019_2023/workersPerOccupation_2019_2023.dsv`
- labels from `variables.xlsx`

### Licence and attribution

`LICENSE.txt` states that the dataset is licensed under **Creative Commons Attribution 4.0 International**:

- https://creativecommons.org/licenses/by/4.0/legalcode.en
- Finnish text: https://creativecommons.org/licenses/by/4.0/legalcode.fi

The dataset page and the FIOH open-data page (https://www.ttl.fi/tutkimus/avoin-data, retrieved 16 October 2026) use the same licence unless a single dataset says otherwise. FIOH asks users to name Työterveyslaitos, the dataset name, and the handover date, plus a scientific publication when the dataset information names one.

The zip does not name a journal article. The dataset page links to the register description and the occupational-disease theme page, and to an in-service analysis. Attribution for the case extract:

> Työterveyslaitos, Työelämätieto: Työikäisten vahvistetut ammattitaudit, aineisto luovutettu 20.5.2026. Tiedosto `occupational-diseases-data-20052026.zip`. https://www.tyoelamatieto.fi/fi/etusivu/aineistot/tyoikaisten-vahvistetut-ammattitaudit/ . Licence: CC BY 4.0.

The employment denominator inside the package is Statistics Finland table **115s**, Employment statistics. The package README describes it as “115s — Employed persons by occupational group (Classification of Occupations 2010, levels 1 to 3), area, sex and year, 2010–2023”, retrieved **27 April 2026**. Statistics Finland open data is CC BY 4.0 (https://stat.fi/en/services/statistical-data-services/open-data-and-interfaces). The report must attribute that table as well.

The region GeoJSON is MIT-licensed (Lucify 2017; FIOH 2018) and is out of scope.

### Source population and how the open file was altered

From the dataset page, checked against the files:

- Source register: Työperäisten sairauksien rekisteri (Finnish Register of Occupational Diseases), maintained by FIOH under the Act on the Activities and Funding of the Finnish Institute of Occupational Health (159/1978, section 2 a).
- Inflows named on the page: insurance material from the Finnish Workers’ Compensation Center (TVK) and the Farmers’ Social Insurance Institution (Mela), plus copies of physicians’ occupational-disease notifications to the licensing and supervisory authority (formerly the Regional State Administrative Agency).
- Population in the open file: confirmed occupational diseases among working-age people, described on the page as ages 15–64.
- If several occupational diseases were recorded for the same case, the open file keeps the one with the most severe consequence.
- The open file is coarsened. Åland has been removed. Samples of fewer than five have been removed.
- Because of those edits, the page states that the counts are not fully comparable with the Register’s annual publication.
- The file is updated together with that annual publication.
- Employment figures used as denominators come from Statistics Finland.

### Observation unit

Each row of `data_A`, `data_B`, and `data_C` is one **retained confirmed case** in that file’s variable bundle, after the disclosure edits above. The files are case listings with repeated identical rows, not pre-aggregated count tables.

They are three separate extracts. For 2019–2023 the row counts are:

| File | Columns | Rows |
| --- | --- | ---: |
| `data_A_2019_2023.tsv` | `DIAGNOOSI`, `ALTISTERYHMA`, `AMMATTI` | 6,096 |
| `data_B_2019_2023.tsv` | `SP`, `IKA_KARKEA`, `PAATOIMIALA` | 6,509 |
| `data_C_2019_2023.tsv` | `MAAKUNTAK`, `VAHVVUOSI` | 6,669 |

There is no case identifier. The three files cannot be joined. Each file’s total is the number of cases still present after suppression inside that variable bundle. The analysis will not quote one of these totals as “the” number of confirmed occupational diseases in Finland.

Within file A, every observed combination of diagnosis, exposure group, and occupation occurs at least five times (minimum 5, 158 combinations). Within file B, every sex–age–industry combination occurs at least five times. Within file C, every region–year combination that remains occurs at least eight times. These minima match the stated removal of samples under five; they also show that the released margins are not a complete census.

### Candidates checked and not chosen

**Työsuojeluvalvonnan valvontatiedot** (occupational safety and health inspections). Dataset page https://www.tyoelamatieto.fi/fi/etusivu/aineistot/tyosuojeluvalvonnan-valvontatiedot/ . Dashboard `occupational-safety-and-health-inspections`, updated 24 August 2026, metadata licence CC BY 4.0, `hasEmbeddedContent: true`. The page describes Vera inspection records for 2017–2025. The avoindata.fi dataset “Työsuojeluvalvonnan tarkastusaineisto v. 2017–2020” (https://avoindata.suomi.fi/data/fi/dataset/tyosuojeluvalvonnan-tarkastusaineisto-v-2017-2020) lists one resource with format ZIP, but the resource URL is the Työelämätieto HTML article `analysisOccupationalSafetyAndHealthInspections`. The portal’s own quality record, retrieved 16 October 2026, scores that resource as HTML with openness score 0. No self-describing tabular package comparable to the occupational-disease zip was found. Not chosen.

**Sairauspoissaolot kunnissa.** Dashboard `kunta10-sick-leave`, updated 16 June 2026, licence CC BY 4.0 in dashboard metadata, linked to the Finnish Public Sector study. This is a study-based series rather than a national register extract with a verified codebook package. A downloadable analysis file was not verified in this pass. Not chosen.

**Työpaikkatapaturmat** (workplace accidents on Työelämätieto). Dashboard `accidents-at-work`, updated 20 October 2025, source link Tapaturmavakuutuskeskus TIKKU. The dashboard metadata `license` field is the interface key `content.accidents-at-work.licence_text`, so the machine-readable metadata does not itself state CC BY 4.0. Not chosen.

**Statistics Finland StatFin, accidents at work** (for example table 129s, https://pxdata.stat.fi/PXWeb/pxweb/en/StatFin/StatFin__ttap/). Documented PxWeb API, CSV and JSON, CC BY 4.0, aggregated counts and rates. A sound fallback. It is unnecessary because the preferred Työelämätieto source has a usable, documented file.

**Työolobarometrin työuupumustiedot.** Dashboard `working-life-barometer`, updated 3 June 2026, licence CC BY 4.0, sources Ministry of Economic Affairs and Employment and Statistics Finland. A survey, so sampling weights might support interval estimates, but a downloadable microdata or weight file was not verified here. Not chosen.

## 2. Research question and practical relevance

**Question.** In the 2019–2023 disclosure-controlled extract of confirmed occupational diseases among working-age people in Finland, which two-digit occupations in the Classification of Occupations 2010 have the highest numbers of retained cases, which have the highest rates per 1,000 employed, and how does separating COVID-19 from the other diagnoses change those two rankings?

The question uses only file A and the occupation denominator. It can be answered from variables that were actually downloaded.

Why this question, for a data-science specialist brief at FIOH:

- It is a surveillance question the register is built to support: where confirmed occupational diseases sit across occupations, and where the burden is high relative to employment.
- It forces the distinction the open file requires. A large occupation can lead the case count while a smaller occupation leads the rate. Those are different statements, and both matter for prevention.
- File A is dominated by one diagnosis label. Of 6,096 retained rows, 2,940 have `DIAGNOOSI` equal to `COVID-19-infektio`. An all-cause ranking for 2019–2023 is largely a COVID-19 ranking. Separating that diagnosis is a data-preparation decision, not a model.
- The result is a description of retained register cases in occupation groups. It is not a statement about individual workers, and it is not a complete count of every confirmed case in the full register.

Practical use of the result: it shows researchers which occupations account for many retained cases, which occupations have high period rates, and which of those patterns remain after COVID-19 is set aside. That is the sort of descriptive cut a prevention or surveillance discussion can start from, with the disclosure limits written next to the figure.

## 3. Variable definitions and planned transformations

### File A, one row per retained case

| Column | Codebook definition | Planned use |
| --- | --- | --- |
| `DIAGNOOSI` | Occupational disease, Register classification. Text label. | Group into `COVID-19-infektio` and all other labels. Also keep the full label for a short frequency table. |
| `ALTISTERYHMA` | Exposure group, codes 1–10. | Used in the exposure-composition figure, on the non-COVID subset. |
| `AMMATTI` | Two-digit Classification of Occupations 2010. Includes `XX` unknown and `ZZ` students. | Grouping key. Stored as a two-character code. |

Exposure groups in `variables.xlsx`:

| Code | English label in the codebook |
| --- | --- |
| 1 | Plant- or animal-based exposure agents |
| 2 | Biological exposure agents |
| 3 | Chemical exposure agents |
| 4 | Other dusts and vapours |
| 5 | Exposure to moisture damage and mould |
| 6 | Asbestos and other silicate materials |
| 7 | Noise |
| 8 | Vibration |
| 9 | Repetitive work and unphysiological work positions |
| 10 | Other or unknown factors |

The Swedish text for code 10 in `variables.xlsx` repeats the Swedish text of code 4. The analysis will use the Finnish and English labels.

Occupation labels come from the same workbook (for example `53` Personal care workers, `32` Health associate professionals, `61` Market-oriented skilled agricultural workers, `71` Building and related trades workers, excluding electricians). The implementation will join the codebook rather than hard-code titles.

### Denominator

`workersPerOccupation_2019_2023.dsv` has `AMMATTI` and `TYONTEKIJOITA`. Forty-three occupation codes. Every value is a multiple of 1,000. The sum is 2,373,000.

The README cites StatFin 115s and the retrieval date 27 April 2026. It does not say whether `TYONTEKIJOITA` is one year, a sum, or a mean. That was checked on 16 October 2026 against the live table:

- API: `https://pxdata.stat.fi/PxWeb/api/v1/fi/StatFin/tyokay/115s.px`
- Table title: employed persons by occupational group (AML 2010, levels 1–3), area, sex and year
- Table updated: 7 October 2026 (coverage now through 2024; the package README says the extract was 2010–2023, retrieved 27 April 2026)
- Query: whole country (`SSS`), both sexes (`SSS`), years 2019–2023, occupations `01`, `03`, `23`, `32`, `53`, `61`, `71`

For each of those seven codes, `TYONTEKIJOITA` equals the **arithmetic mean of the five annual employment counts, rounded to the nearest thousand**. Examples: occupation `53` mean 195,745 rounds to 196,000; occupation `61` mean 44,257 rounds to 44,000; occupation `03` mean 234 rounds to 0. The implementation should repeat this check for every code in the DSV and record any code that does not match.

`ZZ` (students) appears in file A (49 rows) and is absent from the denominator. No rate will be calculated for `ZZ`. Occupation `03` has denominator 0 and no rows in file A; its rate is undefined.

Thirteen denominator occupations have no rows in file A (`02`, `03`, `11`, `12`, `14`, `25`, `35`, `43`, `44`, `92`, `95`, `96`, `XX`). Absence can mean either no retained cases or every diagnosis–exposure cell fell below the suppression threshold. Those occupations will be listed as “not present in the released case file”. They will not be plotted as zero.

### Variables deliberately left out of the question

File B has sex (`SP`: 1 man, 2 woman), age group (`IKA_KARKEA`), and industry (`PAATOIMIALA`, TOL 2008 section). The age values present are `55 - 59`, `60 - 64`, `50 - 54`, `45 - 49`, `35 - 39`, `40 - 44`, `30 - 34`, `25 - 29`, and `- 24`. The codebook does not expand `- 24`. The dataset page defines the population as ages 15–64.

File C has region (`MAAKUNTAK`, codes 1–19 in the case file; codebook names, with 3 unused and Åland absent) and confirmation year (`VAHVVUOSI`, 2019–2023). `workersPerRegion.dsv` is yearly employment in thousands (`MKUNTA`, `VUOSI`, employed in 1,000 persons), includes region `21`, and is a different construction from the occupation denominator.

These files support separate one-way descriptions later. They are not part of the occupation question, because a join would invent combinations the publisher split apart.

### Planned transformations

1. Download the pinned zip, check size and SHA-256, unpack to `data/raw/worklife/` (that directory is gitignored).
2. Read file A with UTF-8 and tab separation. Read the occupation DSV with semicolon separation.
3. Validate column names, types, and allowed codes against a new contract (section 6).
4. Attach English and Finnish occupation and exposure labels from a CSV export of `variables.xlsx`. Exporting once avoids adding an Excel reader to the current dependency set.
5. Add `covid19 = DIAGNOOSI == "COVID-19-infektio"`.
6. Count retained cases by occupation, overall and split by `covid19`.
7. Join `TYONTEKIJOITA`. Compute a rate only where the denominator is present and positive.

**Rate definition used in the report.** Five-year retained cases per 1,000 employed:

`rate_per_1000 = n_cases / (TYONTEKIJOITA / 1000)`

`TYONTEKIJOITA` matches a rounded mean annual stock. The numerator covers five confirmation years. This rate is a five-year period rate per 1,000 employed. An annualised figure is `rate_per_1000 / 5`, labelled as approximate annual retained cases per 1,000 employed. Dividing by five does not change ranks. The report will lead with the period rate and show the annualised scale in the axis subtitle or caption so a reader does not treat the period rate as a one-year incidence.

The Työelämätieto page says occupation figures are shown per 1,000 employed. It does not say whether that display divides by five. The report will define its own rate and will not claim numeric equality with the website chart until a direct comparison is made during implementation.

## 4. Analysis methods, assumptions and limitations

### Method

Descriptive counts and rates. No regression, no clustering, no predictive model.

For the occupations that have both retained cases and a positive denominator, compute:

- retained case count, all diagnoses
- retained case count, COVID-19 and other diagnoses separately
- five-year rate per 1,000 employed, same three numerators
- rank by count and rank by rate, for all diagnoses and for other diagnoses

Report the top of each ranking with the count, the denominator, and the rate side by side. State how many occupation codes are in the denominator, how many appear in file A, and how many are excluded from the rate (missing or zero denominator).

A short diagnosis-frequency table (all 26 labels present in file A) sits in the report so the COVID-19 split is visible. An exposure-group composition is shown only for the non-COVID subset, for the occupations at the top of the non-COVID rate ranking. Exposure group 2 (biological) contains the COVID-19 rows; leaving them in would make that figure a restatement of the COVID split.

### Uncertainty

No sampling weights, design effect, or survey sample size are in the package. The source is a register of confirmed cases, then edited for disclosure. Sampling confidence intervals are not planned. They would describe the wrong kind of uncertainty.

The uncertainties that the report will state in words are:

- cells under five were removed, so every count is a lower bound on the underlying confirmed cases in that classification
- the three files do not share one total
- only the most severe disease was kept when several were recorded
- Åland is absent from the case files
- the denominator is rounded to 1,000 persons, so small occupations have a coarse rate
- confirmation by an insurer or a notified and recognised case is not the same as every work-related illness in the population

### Assumptions

- One row in file A is one retained case in the diagnosis–exposure–occupation classification.
- Occupation codes in the case file and the DSV follow the codebook’s two-digit AML 2010 list.
- The packaged `TYONTEKIJOITA` value is the intended denominator for this open file, and the seven-code check is enough to define it as a rounded 2019–2023 mean, subject to the all-code check at implementation.
- Employment is an annual stock (StatFin 115s reference week is the last week of the year). It is an exposure proxy for a five-year case window, not person-time linked to the cases.
- COVID-19 is identified by the exact diagnosis string `COVID-19-infektio`, which is the codebook label and the value present in the file.

### Limitations to write next to the results

- Results describe retained cases in published groups. They do not describe individual people.
- Rankings can change if suppressed cells were restored. Occupations missing from file A are not known to have zero cases.
- Counts in this file are not to be compared numerically with the Register’s annual statistical publication.
- The 2019–2023 window mixes the COVID-19 years with other occupational diseases. That is why the split is part of the question rather than a footnote.
- Industry, sex, age, and region cannot be crossed with occupation in the open file.
- The StatFin table used to interpret the denominator was updated on 7 October 2026, after the 27 April 2026 extract date in the README. The seven checked codes still matched. The implementation check covers the rest.

## 5. Proposed figures

All figures use the 2019–2023 file A extract and, where a rate is shown, `workersPerOccupation_2019_2023.dsv`. Titles will say “retained confirmed cases” and name the disclosure edits. Captions will carry the CC BY 4.0 attribution.

1. **Counts by occupation, COVID-19 and other diagnoses.** Horizontal stacked bars for the occupations with the most retained cases. Two fills: `COVID-19-infektio` and all other diagnoses. Axis is a count of retained cases. This is the absolute-burden view.

2. **Five-year rate per 1,000 employed.** Horizontal bars for the occupations with the highest period rates, with a positive denominator. The same occupations’ case counts and denominators are printed at the end of each bar or in a companion table. `ZZ` and zero denominators are omitted and counted in the caption. The caption states that the denominator is mean annual employment, rounded to 1,000, and that the numerator spans five years.

3. **Count rank against rate rank.** A slope or bump chart for occupations that have both a count and a positive denominator. Two panels, or two paired lines: all diagnoses, and diagnoses other than COVID-19. This is the figure that shows whether “most cases” and “highest rate” are the same occupations.

4. **Exposure groups among other diagnoses.** Stacked or small-multiple bars of `ALTISTERYHMA` for the occupations with the highest non-COVID rates. Limited to the non-COVID rows so biological exposure is not only COVID-19. Groups smaller than a readable share can be collapsed to “other exposure groups” in the figure, with the full counts kept in a table.

A region map is not planned. The GeoJSON is available, but region cannot be tied to occupation, and the question does not need it.

## 6. Integration plan that preserves the existing example

The current pipeline is one `targets` list in `_targets.R`: read `data_contract/contract.yaml`, generate synthetic pediatric visits, validate, `compute_metrics()`, `make_plots()`, render `report.qmd` to `output/report.html`. CI (`.github/workflows/ci.yml`) runs lint, `Rscript run-tests.R`, and `make report`. `renv.lock` records R 4.3.0 and an empty `Packages` object. `data/raw/*` is gitignored apart from the README and `.gitkeep`.

The work-life analysis is a second pipeline, not a change to that list.

| Existing piece | What happens to it |
| --- | --- |
| `make data`, `make test`, `make report`, `make clean` | Unchanged commands and behaviour |
| `_targets.R` pediatric targets | Unchanged |
| `data_contract/contract.yaml` | Remains the pediatric-visits contract |
| `R/synthetic_data.R`, `R/metrics.R`, `R/plots.R`, `R/contract_validate.R` | Unchanged |
| `report.qmd` and `output/report.html` | Remain the pediatric report |
| `tests/testthat/test-*.R` | Existing tests stay; `run-tests.R` sources every `R/*.R`, so new functions must not change old ones |

Planned additions, when the analysis is implemented:

- `data_contract/worklife_occupational_diseases.yaml` for file A and the occupation denominator. Separate from the pediatric contract.
- `R/worklife_prepare.R` for download, hash check, read, and validation.
- `R/worklife_analysis.R` for counts, rates, and ranks.
- `R/worklife_plots.R` for the four figures.
- `data_contract/worklife_codebook.csv` exported from `variables.xlsx`, with a one-line note of the source file and licence.
- `_targets_worklife.R`, a separate targets script. It is not sourced by `_targets.R`, so `targets::tar_make()` from `make report` does not build it.
- `report_worklife.qmd`, rendered to `output/worklife/report.html`, so it does not overwrite `output/report.html`.
- Makefile target `worklife`, documented beside the existing targets. It runs the separate script only.
- Provenance file committed in the repo, for example `data_contract/worklife_source.yml`, holding the URL, SHA-256, byte size, retrieval date, licence, and attribution strings. The zip itself stays in gitignored `data/raw/`.
- Tests that build small in-memory tables with the real column names and check validation, the COVID flag, the refusal to rate a zero denominator, and the refusal to treat a missing occupation as zero. Those tests do not download data and do not replace the register file with synthetic cases. `make test` must still pass without network access.
- CI stays on `make report` for the pediatric example. A later optional job may run `make worklife`. It must not be required for the existing job to pass, because the zip URL can change.

Dependencies stay inside the packages CI already installs where possible: `targets`, `yaml`, `ggplot2`, `testthat`. Base R reads the TSV and DSV. `arrow` is not required for this extract. An Excel package is not required if the codebook CSV is committed. `renv.lock` is currently empty; pinning new packages is a separate reproducibility task and is not part of this plan’s first implementation unless a package outside the current set is actually needed.

`make clean` today deletes `output/` and generated synthetic data. The later change should leave that behaviour intact and add the work-life output directory only if the new target has its own clean path.

## 7. Acceptance criteria and reproducibility requirements

The implementation is acceptable when all of the following hold.

**Data**

- The script downloads `occupational-diseases-data-20052026.zip` from the URL in section 1 and continues only if the SHA-256 matches `ad2261e1bcc95b68d852e96e7718b740ee5bbcb3a15c70d6e6d5fd80ece5713f`.
- File A for 2019–2023 has columns `DIAGNOOSI`, `ALTISTERYHMA`, `AMMATTI` and 6,096 data rows on this pinned file.
- The occupation DSV has columns `AMMATTI` and `TYONTEKIJOITA`.
- Every `ALTISTERYHMA` and `AMMATTI` value in file A is in the codebook, or the run stops.
- Files B and C are not joined to file A.

**Analysis**

- The research question in section 2 is the question the report answers.
- Counts and rates are labelled as different statistics. The rate caption states the five-year numerator and the rounded mean-employment denominator.
- `ZZ` and any non-positive denominator have no rate.
- Occupations present only in the denominator are not drawn as zero cases.
- COVID-19 is split with the exact string `COVID-19-infektio`.
- The four figures in section 5 are produced, with attribution and the disclosure limits in the captions.
- The report does not give sampling confidence intervals.
- The report does not describe individual people and does not present the file totals as identical to the Register’s annual publication.
- A table lists, for the ranked occupations, the case count, the COVID-19 count, the other-diagnosis count, `TYONTEKIJOITA`, and the period rate.

**Repository**

- `make data`, `make test`, and `make report` still perform the pediatric example only.
- `output/report.html` remains the pediatric report.
- New tests pass under `Rscript run-tests.R` without downloading the zip.
- Session info and the source URL, hash, and retrieval date appear in `report_worklife.qmd`.
- Attribution includes Työterveyslaitos, the dataset name, the handover date 20 May 2026, and Statistics Finland table 115s.

**Reproducibility**

- Fixed input hash, fixed period (2019–2023), fixed COVID label, fixed rate formula.
- No random seed is required, because the analysis does not sample.
- The work-life targets script is runnable with `targets` so the figure files are downstream of the hash-checked zip.
- If FIOH replaces the zip, the hash check fails. Updating the pin is a deliberate edit to the provenance file, with the new hash and date written into the report.

## Unresolved points

There is no blocker that prevents this analysis. The zip downloaded, opened, and matched its codebook, and the occupation denominator was interpretable.

These items stay open until implementation:

- The zip name is date-stamped. There is no documented stable API. The hash pin is the safeguard.
- The all-code comparison of `TYONTEKIJOITA` with StatFin 115s is done for seven occupations, not all 43. The table’s 7 October 2026 update is later than the README’s 27 April 2026 extract.
- The website’s own “per 1,000 employed” display does not document division by five. Ranks are unaffected. The report uses the definition in section 3 and checks the website numbers only as a later consistency look, not as a target to force.
- R is available in CI (`r-version: "4.3"`) and was not on `PATH` in the environment used for this investigation. That does not affect the plan. Implementation needs an R session.
- `renv.lock` still has an empty package list. That is a pre-existing gap for the pediatric pipeline as well.
