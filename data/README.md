# Data

The respondent-level data used in this project are **not included in this repository**.

This directory explains where to obtain the source data, what the build script expects, how the local analytic files are created, and how to check that you have reproduced them correctly.

## Why the data are not here

Two reasons, and the second matters more.

The NFCS is distributed free of charge by the FINRA Investor Education Foundation. Free to download is not the same as licensed for redistribution, so we point to the source rather than republishing a derived copy.

More importantly: a reader who downloads FINRA's file and runs our build script has reproduced the chain. A reader who runs our analysis against a dataset we prepared has only re-run our last step. Shipping the code and not the data is the arrangement that makes reproduction mean something.

## Source data

Project 1 uses two public-use files from the **2024 National Financial Capability Study (NFCS)**.

### 2024 NFCS Investor Survey
- Starting sample: **2,861 respondents**
- Provides the 11-item investment-knowledge battery
- Provides the G43 outcome
- Provides self-assessed investment knowledge (G2)
- Provides the Investor Survey analysis weight (`WGT1`)
- Also carries five demographic variables copied from the State-by-State Survey (`S_Gender2`, `S_Age`, `S_Education`, `S_Income`, `S_Ethnicity`), which are the covariates used in the primary models

### 2024 NFCS State-by-State Survey
- Full sample: **25,539 respondents**
- Used for merge verification and for the finer demographic measures used in robustness analyses

The files are merged 1:1 using `NFCSID`. All 2,861 Investor Survey respondents match a State-by-State record — they are the same people, screened into the Investor Survey on `B14A_1`.

**Where to get them:** the FINRA Investor Education Foundation, https://www.finrafoundation.org/nfcs-data-and-downloads — free, no registration. Download the 2024 Investor Survey and the 2024 State-by-State Survey. Each zip contains `.dta`, `.csv`, and `.sav` versions plus the codebook, questionnaire, and methodology documents. The `.dta` and `.sav` versions carry variable and value labels; the code in this repository expects `.dta`.

## Expected local files

Place both files in this directory. `code/01_build.do` expects:

```text
data/
├── NFCS 2024 Investor.dta
└── NFCS 2024 State.dta
```

If your filenames differ, edit the two globals at the top of `01_build.do`:

```stata
global INVDTA "NFCS 2024 Investor.dta"
global SBSDTA "NFCS 2024 State.dta"
```

The build script normalizes all variable names to lowercase immediately after loading each file (`rename *, lower`), so the distributed mixed-case names do not need editing.

## What the build produces

`code/01_build.do` writes two files locally. Both are ignored by `.gitignore` and neither belongs in version control.

| File | Rows | Contents |
|---|---:|---|
| `nfcs_p1_built_full.dta` | 2,861 | All respondents, all derived variables, after the validation gate passes |
| `nfcs_p1_built_analytic.dta` | 2,797 | Analytic sample: respondents with no refusals on the 11 quiz items |
| `nfcs_p1_built_analytic.csv` | 2,797 | The same analytic sample, exported with value labels for the Python layer |

The `built_` prefix marks these as products of `01_build.do`. `02_analyze.do` and the Python scripts read them and never modify them.

Sample sizes downstream: **2,861** full → **2,797** analytic → **2,796** in models requiring valid G43 → **2,783** in models also requiring valid G2.

## Verifying your build

The build stops on its own if the reconstruction drifts. Expected values are asserted in code, so a mismatch halts the run rather than producing a plausible-looking table. Watch for these in the log:

- Weighted mean correct, full sample: **5.33** (FINRA published 5.3)
- Male / female incorrect count: **3.31 / 3.33** (both round to the published 3.3)
- Respondents with at least one quiz refusal: **64** (174 item-level refusals)
- Analytic sample: **2,797**
- G43 weighted distribution: **49.6% Yes / 20.6% No / 29.6% Don't know**

If the gate passes, your build matches ours.

To confirm you have the same source files we used, compare checksums:

```bash
shasum -a 256 "NFCS 2024 Investor.dta" "NFCS 2024 State.dta"
```

Reference checksums for the two source files are not yet recorded here. Until they are, the validation gate above is the check: if it passes, your source files reproduce our build.

## Reading the exported CSV in Python — important

`01_build.do` exports the analytic file with `export delimited`, which writes **value labels rather than numeric codes**. One legitimate response label is the string `"None"` (B3 = no trades in the past 12 months, 772 respondents), and pandas converts `"None"` to missing under default settings.

Read the file this way when reconstructing item-level measures:

```python
d = pd.read_csv("nfcs_p1_built_analytic.csv", low_memory=False, keep_default_na=False)
```

Without `keep_default_na=False`, 772 respondents silently lose a valid B3 response. The prediction scripts in `code/` are unaffected — they use only numeric derived variables and the G43 labels — but any script that reads item-level responses from the labeled export needs this.

A second consequence of label export: `"Don't know"` is a string, not the code 98. Item-level DK counts are built by matching the label, as in `code/05_nonquiz_dk_sensitivity.py`.

## A note on the CSV distribution of the State-by-State file

If you work from FINRA's `.csv` rather than the `.dta`, be aware that 44 columns contain a space character where a question was skipped by design. A single space is not an empty cell, so those columns import as text. The build script converts any string column with `destring, force`, which is safe here because every column in these files is numerically coded — the only values that fail to convert are the design skips, which should become missing.

## Questions

Open an Issue, or email householdfinancelab@gmail.com.
