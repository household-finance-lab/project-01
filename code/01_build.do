*==============================================================================*
*  Household Finance Lab — Project 1 | 01_build.do                       v2.0
*  Response behavior under uncertainty and an implausible investment proposition
*
*  DATA   : 2024 NFCS Investor Survey (n = 2,861) + 2024 NFCS State-by-State
*           Stata .dta files as distributed
*  OUTCOME: G43 — guaranteed, risk-free 25% annual return for 5 years
*  DESIGN : EXPLORATORY. The expectation below is a post-hoc formalization of a
*           result already known from prior work. It is NOT confirmatory and is
*           never to be relabeled as such.
*
*  RQ1: Among investors with comparable levels of objective investment
*  knowledge, is the tendency to respond "Don't know" rather than answer
*  incorrectly associated with acceptance of an implausible high-return,
*  no-risk investment proposition?
*
*  H1: Holding the number of correct investment-knowledge responses constant, a
*  greater number of "Don't know" responses will be associated with a lower
*  probability of accepting an investment proposition promising a guaranteed,
*  risk-free 25% annual return.
*
*  H1 is an EXPLORATORY expectation, formalized after the result was already
*  known from prior work. The H-label is notation, not a claim of
*  prespecification, and the repository must say so wherever H1 appears.
*
*  OPERATIONALIZATION
*    objective knowledge ........ n_correct
*    DK rather than incorrect ... n_dk, conditional on n_correct
*    investment proposition ..... G43
*    covariates ................. age, education, income, gender, ethnicity
*
*  ==============================================================================*

version 19.0
clear all
set more off
set linesize 100

*------------------------------------------------------------------------------*
* 0. PATHS
*
*  Run this file from the repository root, e.g.
*      cd "/path/to/project-01"
*      do code/01_build.do
*
*  RAW is where you placed the two FINRA .dta files (see data/README.md).
*  OUT is where built datasets and logs are written. Both default to
*  repository-relative locations; override them only if your data live
*  elsewhere.
*------------------------------------------------------------------------------*
global REPO "`c(pwd)'"
global RAW  "$REPO/data"
global OUT  "$REPO/output"
global LOGS "$REPO/logs"

global INVDTA "NFCS 2024 Investor.dta"
global SBSDTA "NFCS 2024 State.dta"

* Fail early and loudly if the working directory is not the repository root.
capture confirm file "$REPO/code/01_build.do"
if _rc {
    display as error "Working directory is not the repository root."
    display as error "cd to the folder containing code/ and data/, then rerun."
    exit 601
}

capture mkdir "$OUT"
capture mkdir "$OUT/tables"
capture mkdir "$LOGS"

capture log close _all
log using "$LOGS/hfl_p1_build.log", replace text

capture file close dec
file open dec using "$OUT/build-decisions.txt", write replace

*==============================================================================*
*  BLOCK A — LOAD AND MERGE
*==============================================================================*

display _newline(2) as text "{hline 78}"
display as result "BLOCK A — LOAD AND MERGE"
display as text "{hline 78}"

*------------------------------------------------------------------------------*
* A1. State-by-State file
*------------------------------------------------------------------------------*
use "$RAW/$SBSDTA", clear

* The distributed .dta files carry mixed-case names (NFCSID, WGT1, G4). Stata is
* case-sensitive, so one convention prevents an entire class of "variable not
* found" errors. Everything below is lowercase.
rename *, lower

count
display as text "  State-by-State rows loaded: " as result r(N)

* Validate the merge key BEFORE merging. merge 1:1 would eventually catch a
* duplicate, but failing at the point of the actual problem is clearer for a
* reader of the repository than failing three commands later.
isid nfcsid

* --- String columns -----------------------------------------------------------
* In the CSV distribution, 44 columns carry a space where a question was skipped
* by design, which forces the column to import as text. The .dta distribution
* usually resolves this, so this block is defensive: it converts only if
* something arrives as a string, and reports what it touched.
*
*** DECISION A1: destring with force on any string column.
*   Every column in these files is numerically coded, so the only values that
*   cannot convert are design skips, which SHOULD become missing.
*   Alternative: hand-convert a named list. Rejected — the list rots silently if
*   FINRA changes skip patterns in a later wave.

quietly ds, has(type string)
if "`r(varlist)'" != "" {
    local strvars "`r(varlist)'"
    display as text "  String columns converted: " as result wordcount("`strvars'")
    destring `strvars', replace force
}

* --- Pre-merge check on the source file ---------------------------------------
* B14A_1 is the securities-ownership screener. Confirming its weighted share on
* the full State file, with that file's own national weight, verifies we opened
* the file we think we opened.
* EXPECTED: 33.6% weighted yes; 8,933 unweighted yes.

quietly summarize wgt_n2
local wtot = r(sum)
quietly summarize wgt_n2 if b14a_1 == 1
local wyes = r(sum)
local pct  = 100 * `wyes' / `wtot'
quietly count if b14a_1 == 1
local nyes = r(N)

display as text "  B14A_1 weighted yes: "   as result %4.1f `pct'  as text "%  (expected 33.6)"
display as text "  B14A_1 unweighted yes: " as result `nyes'       as text "   (expected 8,933)"
assert abs(`pct' - 33.6) < 0.15
assert `nyes' == 8933

* --- Suffix everything --------------------------------------------------------
* The two files reuse names for different questions. G23 is a debt-attitude item
* here and the call-option quiz item in the Investor Survey; G30_1 through G30_5
* are student-loan checkboxes here and reasons-for-investing items there.
* Suffixing the whole block catches collisions nobody has noticed yet and makes
* provenance visible in every later line of code.
*
*** DECISION A2: suffix ALL State-by-State variables with _sbs.
*   Alternative: rename only the six known collisions. Rejected — a missed
*   collision runs cleanly and means nothing, which is the worst failure mode.

foreach v of varlist _all {
    if "`v'" != "nfcsid" {
        rename `v' `v'_sbs
    }
}

tempfile sbs
quietly save `sbs', replace

*------------------------------------------------------------------------------*
* A2. Investor Survey file
*------------------------------------------------------------------------------*
use "$RAW/$INVDTA", clear
rename *, lower

count
assert r(N) == 2861
display as text "  Investor Survey rows loaded: " as result r(N) as text "  (expected 2,861)"

isid nfcsid

quietly ds, has(type string)
if "`r(varlist)'" != "" {
    destring `r(varlist)', replace force
}

*------------------------------------------------------------------------------*
* A3. Merge
*------------------------------------------------------------------------------*
* 1:1 on NFCSID. The Investor respondents are a subset of State-by-State
* respondents — the same people, not a different sample — so every Investor
* record must find a match. _merge==1 would mean the key is broken.

merge 1:1 nfcsid using `sbs'


assert _merge != 1

quietly count if _merge == 3
display as text "  Matched records: " as result r(N) as text "  (expected 2,861)"
assert r(N) == 2861

keep if _merge == 3
drop _merge

assert b14a_1_sbs == 1
display as text "  All 2,861 confirmed as B14A_1 = yes in the State file."

*------------------------------------------------------------------------------*
* A4. Weights
*------------------------------------------------------------------------------*
* WGT1 is the Investor Survey weight, documented as weighting by age and
* education. Use it for everything estimated on this subsample.
*
* wgt_n2 is a NATIONAL weight built for the full 25,539-respondent State sample.
* Applying it here would ignore the subsampling entirely: 8,933 screened yes on
* B14A_1 but only 2,861 completed the Investor Survey, and WGT1 is what carries
* that correction. The State weights are dropped rather than left in the file to
* be picked up by accident.
*
*** DECISION A3: WGT1 for all estimation; State weights dropped from the file.
*
* NOTE for the write-up: WGT1 post-stratifies on age and education only. Sex,
* income, and ethnicity are UNADJUSTED in every weighted estimate below. That
* bears directly on the gender heterogeneity analysis in C6 and on how far the
* ethnicity coefficient can be read in C2.

drop wgt_n2_sbs wgt_d2_sbs wgt_s3_sbs

assert !missing(wgt1)
quietly summarize wgt1
display as text "  WGT1: mean " as result %5.3f r(mean) as text ", sum " as result %8.1f r(sum)

svyset [pweight = wgt1]

* What svyset buys us here, and what it does not. FINRA does not release primary
* sampling units or strata for this file, so this declaration handles the weights
* and produces design-consistent standard errors under a with-replacement
* assumption. It does not recover a clustered design we have no information
* about. State that limitation rather than implying a fuller design was modeled.

*------------------------------------------------------------------------------*
* A5. Demographics
*------------------------------------------------------------------------------*
* The Investor file already carries demographics copied from the State survey:
*   S_Gender2   1 Male, 2 Female
*   S_Age       1 18-34, 2 35-54, 3 55+      <- exactly FINRA's published bands
*   S_Education 1 some college or less, 2 college grad or more
*   S_Income    1 <$50K, 2 $50K-$100K, 3 $100K+
*   S_Ethnicity 1 White non-Hispanic, 2 Non-White
*
* Verified against the merged State variables: agreement is 1.00 on sex (A50A),
* age (A3Ar_w collapsed to three bands) and education (A5_2015 collapsed at
* bachelor's), with no missing values.
*
*** DECISION A4: primary models use the S_* variables.
*   Alternative: the finer State-side variables (a3ar_w 6 bands, a5_2015 7
*   categories, a8_2021 10 brackets), retained in the merged file and used as a
*   robustness check in C5. The coarse versions are primary because they match
*   the bands FINRA validates against and are less likely to produce empty cells
*   in the interaction models.


describe s_gender2 s_age s_education s_income s_ethnicity

rename s_gender2   sex
rename s_age       agecat
rename s_education educ
rename s_income    income
rename s_ethnicity ethnicity

label define sexlbl 1 "Male" 2 "Female", replace
label define agelbl 1 "18-34" 2 "35-54" 3 "55+", replace
label define edulbl 1 "Some college or less" 2 "College grad or more", replace
label define inclbl 1 "<$50K" 2 "$50K-$100K" 3 "$100K+", replace
label define ethlbl 1 "White non-Hispanic" 2 "Non-White", replace
label values sex sexlbl
label values agecat agelbl
label values educ edulbl
label values income inclbl
label values ethnicity ethlbl

assert !missing(sex, agecat, educ, income, ethnicity)

**Quick check**
tab sex
tab agecat
tab educ
tab income
tab ethnicity

file write dec "BLOCK A" _n ///
  "A1 destring force on any string column; alt = hand list, rejected as fragile" _n ///
  "A2 suffix ALL State variables _sbs; alt = rename six known collisions, rejected (silent failure mode)" _n ///
  "A3 WGT1 only; State weights dropped. WGT1 adjusts on age and education only" _n ///
  "A4 primary covariates = S_* (coarse, match FINRA bands); finer State versions kept for C5" _n _n

*==============================================================================*
*  BLOCK B — VALIDATION GATE
*  Nothing is estimated until every check below passes.
*==============================================================================*

display _newline(2) as text "{hline 78}"
display as result "BLOCK B — VALIDATION GATE"
display as text "{hline 78}"

*------------------------------------------------------------------------------*
* B1. Build the three tallies
*------------------------------------------------------------------------------*
* The 11-item battery is FROZEN. FINRA's 2024 report states the quiz is 11 items
* including the newly added inflation question (G44), and that the call-option
* item (G23) is a bonus explicitly not counted. G23 stays out.
*
* Correct-answer codes read from the 2024 Investor Survey instrument:
*   G4  stock ownership .......... 1  (you own part of the company)     4 options
*   G5  bond ownership ........... 2  (you have lent money)             4 options
*   G6  bankruptcy risk .......... 2  (common stock)                    3 options
*   G7  risk-return .............. 1  (True)                            2 options
*   G21 past performance ......... 2  (False)                           2 options
*   G8  20-year best returns ..... 1  (stocks)                          5 options
*   G44 inflation ................ 3  (more than 5%)                    3 options
*   G22 index funds .............. 2  (lower fees and expenses)         3 options
*   G11 municipal bonds .......... 3  (can be tax-free)                 3 options
*   G12 margin loss .............. 3  ($0)                              3 options
*   G13 selling short ............ 4  (selling borrowed shares)         4 options
*
* Code 98 = don't know, 99 = prefer not to say, throughout the survey.

local qitems  g4 g5 g6 g7 g21 g8 g44 g22 g11 g12 g13
local qkeys   1  2  2  1  2   1  3   2   3   3   4
local qopts   4  4  3  2  2   5  3   3   3   3   4

foreach v of local qitems {
    assert !missing(`v')
}

gen byte n_correct = 0
gen byte n_dk      = 0
gen byte n_pnts    = 0

local i = 0
foreach v of local qitems {
    local ++i
    local k : word `i' of `qkeys'
    quietly replace n_correct = n_correct + (`v' == `k')
    quietly replace n_dk      = n_dk      + (`v' == 98)
    quietly replace n_pnts    = n_pnts    + (`v' == 99)
}

*** DECISION B1: n_incorrect is STRICT — refusals excluded, not folded in.
*   Verified against the published figures: the gender row reproduces only under
*   the strict definition (3.31 male / 3.33 female, both rounding to the
*   published 3.3). Folding refusals in gives 3.36 / 3.41, which rounds to 3.4
*   and fails. FINRA's table therefore excludes refusals.
*   The loose version is retained and used in the C5 robustness branch.

gen byte n_incorrect       = 11 - n_correct - n_dk - n_pnts   // strict, primary
gen byte n_incorrect_loose = 11 - n_correct - n_dk            // refusals folded in

label variable n_correct   "Correct responses (0-11)"
label variable n_dk        "Don't-know responses (0-11)"
label variable n_pnts      "Prefer-not-to-say responses (0-11)"
label variable n_incorrect "Incorrect responses (0-11, refusals excluded)"

assert n_correct + n_incorrect + n_dk + n_pnts == 11

quietly count if n_pnts > 0
display as text "  Respondents with at least one refusal: " as result r(N) as text "  (expected 64)"
assert r(N) == 64
quietly summarize n_pnts
display as text "  Total item-level refusals: " as result r(sum) as text "  (expected 174)"

*------------------------------------------------------------------------------*
* B2. The checking tool
*------------------------------------------------------------------------------*
* Expected values live in the code, not in a notebook. A drifting number stops
* the run rather than producing a plausible-looking table nobody re-checks.
* Tolerance is 0.06, which is what a target published to one decimal allows.

capture program drop hflcheck
program define hflcheck
    syntax varname [if], TARget(real) DESC(string)
    quietly summarize `varlist' `if' [aw=wgt1]
    local m = r(mean)
    local d = abs(`m' - `target')
    if `d' <= 0.06 {
        display as text "  PASS   " %-34s "`desc'" ///
            "  computed " as result %6.2f `m' as text "   target " %5.2f `target'
    }
    else {
        display as error "  FAIL   " %-34s "`desc'" ///
            "  computed " %6.2f `m' "   target " %5.2f `target' "   diff " %5.2f `d'
        error 9
    }
end

*------------------------------------------------------------------------------*
* B3. Sample basis for the gate
*------------------------------------------------------------------------------*
*** DECISION B2: the gate runs on the FULL n = 2,861, before the analytic sample
*   rule is applied.
*   Tested both ways. On the full sample every published figure reproduces. On
*   the refusal-dropped sample the female mean rises to 4.59 (rounds to 4.6
*   against a published 4.5) and G40 becomes 5.63/5.28 against a published
*   5.6/5.2. Gating on the analytic sample would fire a failure at a correctly
*   built pipeline. The gate asks "did we reproduce the published numbers"; the
*   sample rule asks "which respondents can support our estimates". Different
*   questions, asked in that order.

display _newline as text "  --- Overall (full sample, n = 2,861) ---"
hflcheck n_correct, target(5.3) desc("Mean correct, overall")

display _newline as text "  --- By sex ---"
* The strongest single check in the set. Male and female respondents record
* essentially IDENTICAL incorrect counts while differing by roughly 1.5 items in
* both correct and DK. A coding error in the answer key or the DK code would have
* to break two tallies in exactly offsetting directions to leave incorrect equal.
hflcheck n_correct   if sex==1, target(6.0) desc("Male: correct")
hflcheck n_incorrect if sex==1, target(3.3) desc("Male: incorrect")
hflcheck n_dk        if sex==1, target(1.7) desc("Male: DK")
hflcheck n_correct   if sex==2, target(4.5) desc("Female: correct")
hflcheck n_incorrect if sex==2, target(3.3) desc("Female: incorrect")
hflcheck n_dk        if sex==2, target(3.1) desc("Female: DK")

display _newline as text "  --- By age band ---"
hflcheck n_correct   if agecat==1, target(4.3) desc("18-34: correct")
hflcheck n_incorrect if agecat==1, target(4.3) desc("18-34: incorrect")
hflcheck n_dk        if agecat==1, target(2.3) desc("18-34: DK")
hflcheck n_correct   if agecat==2, target(5.3) desc("35-54: correct")
hflcheck n_incorrect if agecat==2, target(3.5) desc("35-54: incorrect")
hflcheck n_dk        if agecat==2, target(2.1) desc("35-54: DK")
hflcheck n_correct   if agecat==3, target(5.8) desc("55+: correct")
hflcheck n_incorrect if agecat==3, target(2.7) desc("55+: incorrect")
hflcheck n_dk        if agecat==3, target(2.4) desc("55+: DK")

*------------------------------------------------------------------------------*
* B4. Self-assessed knowledge (G2)
*------------------------------------------------------------------------------*
* G2 is measured BEFORE the quiz, on a 1-7 scale. Codes 98 and 99 go missing:
* they are non-responses on a rating scale, not scale points, and averaging them
* in would be arithmetic on category labels.

gen byte g2_band = .
replace g2_band = 1 if inrange(g2,1,3)
replace g2_band = 2 if g2 == 4
replace g2_band = 3 if inrange(g2,5,7)
label define g2lbl 1 "Low (1-3)" 2 "Neutral (4)" 3 "High (5-7)", replace
label values g2_band g2lbl

gen byte g2_scale = g2 if inrange(g2,1,7)
label variable g2_scale "Self-assessed investing knowledge, 1-7"

display _newline as text "  --- By self-assessed knowledge (G2) ---"
hflcheck n_correct   if g2_band==3, target(6.0) desc("G2 high (5-7): correct")
hflcheck n_incorrect if g2_band==3, target(3.5) desc("G2 high (5-7): incorrect")
hflcheck n_dk        if g2_band==3, target(1.4) desc("G2 high (5-7): DK")
hflcheck n_correct   if g2_band==2, target(5.0) desc("G2 neutral (4): correct")
hflcheck n_incorrect if g2_band==2, target(3.4) desc("G2 neutral (4): incorrect")
hflcheck n_dk        if g2_band==2, target(2.6) desc("G2 neutral (4): DK")
hflcheck n_correct   if g2_band==1, target(4.1) desc("G2 low (1-3): correct")
hflcheck n_incorrect if g2_band==1, target(2.8) desc("G2 low (1-3): incorrect")
hflcheck n_dk        if g2_band==1, target(4.1) desc("G2 low (1-3): DK")

*------------------------------------------------------------------------------*
* B5. Family exposure items (G40, G41)
*------------------------------------------------------------------------------*
display _newline as text "  --- By parental investing (G40) and family conversation (G41) ---"
hflcheck n_correct   if g40==1, target(5.6) desc("G40 yes: correct")
hflcheck n_correct   if g40==2, target(5.2) desc("G40 no: correct")
hflcheck n_correct   if g41==1, target(5.5) desc("G41 yes: correct")
hflcheck n_correct   if g41==2, target(5.3) desc("G41 no: correct")
hflcheck n_incorrect if g41==1, target(3.6) desc("G41 yes: incorrect")
hflcheck n_incorrect if g41==2, target(3.2) desc("G41 no: incorrect")

*------------------------------------------------------------------------------*
* B6. The outcome (G43)
*------------------------------------------------------------------------------*
drop pct_g43_*

display _newline as text "  --- G43 response distribution ---"

gen byte pct_g43_yes = 100 * (g43 == 1)
gen byte pct_g43_no  = 100 * (g43 == 2)
gen byte pct_g43_dk  = 100 * (g43 == 98)

hflcheck pct_g43_yes, target(49.6) desc("G43 Yes (%)")
hflcheck pct_g43_no,  target(20.6) desc("G43 No (%)")
hflcheck pct_g43_dk,  target(29.6) desc("G43 DK (%)")

drop pct_g43_*
*------------------------------------------------------------------------------*
* B7. Per-item table
*------------------------------------------------------------------------------*

* Re-create local macros because we are running sections separately
local qitems  g4 g5 g6 g7 g21 g8 g44 g22 g11 g12 g13
local qkeys   1  2  2  1  2   1  3   2   3   3   4

display _newline as text "  --- Per-item response distribution (weighted %) ---"
display as text "  item   correct  incorrect     DK    refused"

local i = 0

foreach v of local qitems {

    local ++i
    local k : word `i' of `qkeys'

    quietly summarize wgt1
    local tot = r(sum)

    foreach cat in c x d p {

        local cnd_c "`v' == `k'"
        local cnd_x "!inlist(`v', `k', 98, 99)"
        local cnd_d "`v' == 98"
        local cnd_p "`v' == 99"

        quietly summarize wgt1 if `cnd_`cat''
        local w_`cat' = cond(r(N)==0, 0, r(sum))
    }

    display as text "  " %-5s "`v'" ///
        as result %8.1f 100*`w_c'/`tot' ///
        %10.1f 100*`w_x'/`tot' ///
        %8.1f 100*`w_d'/`tot' ///
        %9.1f 100*`w_p'/`tot'
}

display _newline as result "  VALIDATION GATE PASSED."

file write dec "BLOCK B" _n ///
  "B1 n_incorrect STRICT (refusals excluded); verified against the published gender row" _n ///
  "B2 gate runs on full n=2,861 BEFORE the sample rule; the analytic sample does not reproduce published figures" _n _n
*------------------------------------------------------------------------------*
* B8. Derived variables, then save the validated full dataset
*------------------------------------------------------------------------------*
* Outcome coded for the multinomial. Refusals on G43 (about 0.2%) go missing: a
* refusal to answer is not a fourth substantive response state.
gen byte g43_3 = .
replace g43_3 = 1 if g43 == 2      // No       <- base outcome
replace g43_3 = 2 if g43 == 98     // Don't know
replace g43_3 = 3 if g43 == 1      // Yes
label define g43lbl 1 "No" 2 "Don't know" 3 "Yes", replace
label values g43_3 g43lbl
label variable g43_3 "Response to guaranteed 25% return proposition"

gen byte g43_yes_all = (g43 == 1) if inlist(g43, 1, 2, 98)   // Yes vs No+DK
gen byte g43_yes_no  = (g43 == 1) if inlist(g43, 1, 2)       // Yes vs No only

* Finer covariates, built here so the robustness branches can use them.
gen byte inc_fine = a8_2021_sbs if inrange(a8_2021_sbs, 1, 10)

*------------------------------------------------------------------------------*
* B9. General non-quiz DK propensity
*------------------------------------------------------------------------------*
* NAMING MATTERS HERE, and the earlier name overclaimed. This is NOT a validated
* response-style scale. Several of its items involve genuine substantive
* uncertainty about one's own finances — whether an account permits margin or
* options, which fees are paid, whether disclosures were received, whether one
* was targeted by fraud. A "don't know" there may mean "I do not know this fact
* about my own accounts" rather than any habit of clicking DK.
*
* So the index measures one thing only: how often this respondent selected DK on
* non-quiz Investor Survey items. The analysis it supports is correspondingly
* narrow — whether the quiz-DK association survives adjustment for a
* respondent's broader propensity to select DK elsewhere in the same instrument.
* Do not write "response style" or "satisficing" off this variable.
*
* Construction rules:
*   1. G43 is NOT among the items. Including the outcome inside a control would
*      guarantee an association and prove nothing. Asserted below, not assumed.
*   2. The 11 quiz items are excluded — they are the predictor.
*   3. G2, G40, G41 excluded — they enter models elsewhere.
*   4. Only universally-asked items. Items behind a skip pattern (B6, B34,
*      B24-B26, C41-C43, D42, E3, E4) would give respondents different
*      denominators, so the index would partly measure how many questions
*      someone was shown.
*   5. H40 is not present in this file and has been removed from the list.
*
*** DECISION C2: index built from 30 universally-asked non-quiz items.
*   Alternative: include skip-pattern items for a longer index. Rejected — a
*   varying denominator makes the index non-comparable across respondents.
*   Second alternative: add the F30 reliance and F31 platform batteries (22 more
*   universally-asked items). Not taken, to keep the index close to the earlier
*   26-item version.
*   ACTION: reconcile this list against the earlier 26-item index. If they
*   differ, recompute the earlier result on whichever list is kept rather than
*   reporting the two as interchangeable.

local dkitems a2 b30_2024 b3 b4_2024 b5 b33 b10 b40 b41 b23 ///
              c22_1 c22_2 c22_3 c22_4 c40 c23_1 c23_2 c23_3 c23_4 c24 c26 c7 ///
              d40 d31 d41 e2 e6 f40 g31 g42

foreach v of local dkitems {
    if "`v'" == "g43" {
        display as error "  G43 found in the DK index list — stop."
        error 9
    }
}

gen byte nonquiz_dk_n = 0
local nitems = 0
foreach v of local dkitems {
    capture confirm variable `v'
    if _rc {
        display as error "  DK-index item not found in file: `v' — stop."
        error 111
    }
    quietly replace nonquiz_dk_n = nonquiz_dk_n + (`v' == 98)
    local ++nitems
}

gen double nonquiz_dk_share = nonquiz_dk_n / `nitems'
label variable nonquiz_dk_n     "Count of DK responses on non-quiz items"
label variable nonquiz_dk_share "Share of non-quiz items answered DK"
display as text "  Non-quiz DK index built from " as result `nitems' as text " items  (expected 30)"
assert `nitems' == 30

*------------------------------------------------------------------------------*
* B10. Analytic sample rule
*------------------------------------------------------------------------------*
*** DECISION B3: drop any respondent with at least one refusal on the 11 items.
*   n_incorrect is derived by subtraction, so an unremoved refusal is silently
*   absorbed into the incorrect tally and breaks the sum-to-11 identity the
*   specification rests on.
*   Alternative (keep them, folding refusals into incorrect) is executed in C5b.

gen byte analytic = (n_pnts == 0)
label variable analytic "In analytic sample (no quiz refusals)"

quietly count if analytic
display _newline as text "  Analytic sample: " as result r(N) as text " of 2,861  (expected 2,797)"
assert r(N) == 2797

file write dec "B3 analytic sample = no quiz refusals (2,861 -> 2,797); loose alternative executed in C5b" _n ///
  "B4 G43 refusals set to missing (~0.2%); a refusal is not a fourth response state" _n ///
  "B5 DK index renamed: 'response style' -> 'general non-quiz DK propensity'. Items include genuine" _n ///
  "   substantive uncertainty about own accounts, so a response-style claim would exceed the measure" _n _n

*------------------------------------------------------------------------------*
* BUILD OUTPUTS
*------------------------------------------------------------------------------*
* Save only after the analytic flag has been constructed. The full file supports
* robustness checks; the analytic file is the frozen input for 02_analyze.do and
* the Python prediction scripts.

save "$OUT/nfcs_p1_built_full.dta", replace
display as text "  Full built dataset saved (n = 2,861)."

preserve
    keep if analytic
    quietly count
    assert r(N) == 2797
    save "$OUT/nfcs_p1_built_analytic.dta", replace
    export delimited using "$OUT/nfcs_p1_built_analytic.csv", replace
restore

file close dec
display _newline(2) as result "BUILD COMPLETE."
display as text "Build decisions: $OUT/build-decisions.txt"
log close
