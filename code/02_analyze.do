*==============================================================================*
*  Household Finance Lab — Project 1 | 02_analyze.do                     v2.0
*  Response behavior under uncertainty and an implausible investment proposition
*
*  INPUT  : nfcs_p1_built_analytic.dta produced by 01_build.do
*  OUTCOME: G43 — guaranteed, risk-free 25% annual return for 5 years
*  DESIGN : EXPLORATORY. This file estimates the substantive and robustness
*           analyses only; all data construction and validation occur in build.do.
*==============================================================================*

version 19.0
clear all
set more off
set linesize 100

*------------------------------------------------------------------------------*
* 0. PATHS
*
*  Run from the repository root, after 01_build.do:
*      cd "/path/to/project-01"
*      do code/02_analyze.do
*------------------------------------------------------------------------------*
global REPO "`c(pwd)'"
global OUT  "$REPO/output"
global LOGS "$REPO/logs"

capture confirm file "$OUT/nfcs_p1_built_analytic.dta"
if _rc {
    display as error "output/nfcs_p1_built_analytic.dta not found."
    display as error "Run code/01_build.do first, from the repository root."
    exit 601
}

capture mkdir "$LOGS"

capture log close _all
log using "$LOGS/hfl_p1_analysis.log", replace text

capture file close dec
file open dec using "$OUT/analysis-decisions.txt", write replace

use "$OUT/nfcs_p1_built_analytic.dta", clear

quietly count
assert r(N) == 2797
assert analytic == 1
assert n_correct + n_incorrect + n_dk + n_pnts == 11
svyset [pweight = wgt1]

*==============================================================================*
*  BLOCK C — ANALYSIS
*==============================================================================*

display _newline(2) as text "{hline 78}"
display as result "BLOCK C — ANALYSIS"
display as text "{hline 78}"

*------------------------------------------------------------------------------*
* C1. Descriptives and the item audit
*------------------------------------------------------------------------------*
display _newline as result "  C1. DESCRIPTIVES AND ITEM AUDIT"

svy: mean n_correct n_incorrect n_dk
estat sd

tabulate g43_3 [aw=wgt1]
tabulate sex agecat [aw=wgt1], row nofreq

* --- The item audit -----------------------------------------------------------
* This exists because the battery is NOT format-homogeneous. Guess probability
* ranges from 0.20 (the five-option item) to 0.50 (the two-option items), so an
* attempt on one item is not evidentially equivalent to an attempt on another.
*
* Accuracy among ATTEMPTS is correct / (correct + incorrect), excluding DK.
* Against the chance rate 1/(options) it asks: do the people who choose to answer
* this item know anything?
*
* EXPECTED (accuracy among attempts minus chance, percentage points):
*   G44 +54.1   G4 +53.5   G5 +53.3   G8 +49.9   G6 +35.3   G7 +33.8
*   G22 +16.6   G11 +11.0  G13 +4.7   G21 -3.9   G12 -6.5
*
* G21 (past performance) and G12 (margin loss arithmetic) come out BELOW chance
* among those who attempt them.
*
* LANGUAGE CAUTION, and it is a real one. "Below chance among attempts" does not
* establish that respondents are guessing randomly, nor that any distractor is
* definitively a misconception. It establishes that attempts on those two items
* carry no positive information about knowledge — a property of the items. That
* is a legitimate and undocumented item-level finding for this instrument, and it
* stays a secondary methodological note. It does not overtake the DK/G43
* question that Project 1 exists to ask.


*------------------------------------------------------------------------------*
* C1b. Item audit
*------------------------------------------------------------------------------*

* Re-create local macros because sections are being run separately
local qitems  g4 g5 g6 g7 g21 g8 g44 g22 g11 g12 g13
local qkeys   1  2  2  1  2   1  3   2   3   3   4
local qopts   4  4  3  2  2   5  3   3   3   3   4

display _newline as text "  item  opts   %corr   %inc    %DK   acc|attempt  chance   diff"

local i = 0

foreach v of local qitems {

    local ++i
    local k : word `i' of `qkeys'
    local o : word `i' of `qopts'

    quietly summarize wgt1
    local tot = r(sum)

    quietly summarize wgt1 if `v' == `k'
    local wc = cond(r(N)==0, 0, r(sum))

    quietly summarize wgt1 if !inlist(`v', `k', 98, 99)
    local wx = cond(r(N)==0, 0, r(sum))

    quietly summarize wgt1 if `v' == 98
    local wd = cond(r(N)==0, 0, r(sum))

    local acc    = 100 * `wc' / (`wc' + `wx')
    local chance = 100 / `o'

    display as text "  " %-4s "`v'" %5.0f `o' ///
        as result %8.1f 100*`wc'/`tot' ///
        %7.1f 100*`wx'/`tot' ///
        %7.1f 100*`wd'/`tot' ///
        %11.1f `acc' ///
        %8.1f `chance' ///
        %8.1f `acc'-`chance'
}


svy: mlogit g43_3 ///
    c.n_correct c.n_dk ///
    i.agecat i.educ i.income i.sex i.ethnicity, ///
    baseoutcome(1)

estimates store mA_mlogit

**Marginal Effects**
margins, dydx(n_correct n_dk) predict(outcome(3))
margins, dydx(n_correct n_dk) predict(outcome(2))
margins, dydx(n_correct n_dk) predict(outcome(1))


*------------------------------------------------------------------------------*
* C3a. ROBUSTNESS — adjust for prior self-assessed investment knowledge (G2)
*------------------------------------------------------------------------------*

display _newline as result "  C3a. ADD SELF-ASSESSED INVESTMENT KNOWLEDGE (G2)"

svy: mlogit g43_3 ///
    c.n_correct c.n_dk c.g2_scale ///
    i.agecat i.educ i.income i.sex i.ethnicity, ///
    baseoutcome(1)

estimates store mB_g2


margins, dydx(n_correct n_dk g2_scale) predict(outcome(3))


***Compare common sample Model A vs Model B**
gen byte esample_B = !missing(g2_scale, g43_3, n_correct, n_dk, agecat, educ, income, sex, ethnicity)

quietly count if esample_B
display as text "  Common estimation sample for A vs B: " as result r(N)

svy, subpop(esample_B): mlogit g43_3 ///
    c.n_correct c.n_dk ///
    i.agecat i.educ i.income i.sex i.ethnicity, ///
    baseoutcome(1)

estimates store modelA

margins, dydx(n_dk) predict(outcome(3))

*------------------------------------------------------------------------------*
* C3b. ROBUSTNESS — general non-quiz DK propensity
*------------------------------------------------------------------------------*

display _newline as result "  C3b. ADD GENERAL NON-QUIZ DK PROPENSITY"

svy: mlogit g43_3 ///
    c.n_correct c.n_dk c.nonquiz_dk_share ///
    i.agecat i.educ i.income i.sex i.ethnicity, ///
    baseoutcome(1)

estimates store mC_dkprop


***
margins, dydx(n_correct n_dk nonquiz_dk_share) predict(outcome(3))


*------------------------------------------------------------------------------
* C3c. ROBUSTNESS — G2 + general non-quiz DK propensity together
*------------------------------------------------------------------------------

display _newline as result "  C3c. ADD G2 + GENERAL NON-QUIZ DK PROPENSITY"

svy: mlogit g43_3 ///
    c.n_correct c.n_dk c.g2_scale c.nonquiz_dk_share ///
    i.agecat i.educ i.income i.sex i.ethnicity, ///
    baseoutcome(1)

estimates store mD_g2_dkprop

***
margins, dydx(n_correct n_dk g2_scale nonquiz_dk_share) predict(outcome(3))

*------------------------------------------------------------------------------
* C4a. BINARY SENSITIVITY — YES VS NO ONLY
*------------------------------------------------------------------------------

display _newline as result "  C4a. BINARY: YES VS NO ONLY"

svy: logit g43_yes_no ///
    c.n_correct c.n_dk ///
    i.agecat i.educ i.income i.sex i.ethnicity

estimates store mE_yesno


***
margins, dydx(n_correct n_dk)

***------------------------------------------------------------------------------
* C4b. BINARY SENSITIVITY — YES VS NO + DK
*------------------------------------------------------------------------------

display _newline as result "  C4b. BINARY: YES VS NO + DK"

svy: logit g43_yes_all ///
    c.n_correct c.n_dk ///
    i.agecat i.educ i.income i.sex i.ethnicity

estimates store mF_yesall


********************
margins, dydx(n_correct n_dk)


**
summarize nonquiz_dk_share nonquiz_dk_n, detail

correlate n_dk nonquiz_dk_share

*------------------------------------------------------------------------------*
* C5b. Alternative sample rule — loose sample
*------------------------------------------------------------------------------*

display _newline as result "  C5b. LOOSE SAMPLE RULE"

preserve

    use "$OUT/nfcs_p1_built_full.dta", clear
    svyset [pweight = wgt1]

    quietly count
    display as text "  Full loose-rule dataset: " as result r(N) ///
        as text "  (expected 2,861)"

    quietly count if !missing(g43_3)
    display as text "  G43 model-eligible observations: " as result r(N) ///
        as text "  (expected 2,854)"

    svy: mlogit g43_3 ///
        c.n_correct c.n_dk ///
        i.agecat i.educ i.income i.sex i.ethnicity, ///
        baseoutcome(1)

    estimates store mRob_loose

    margins, dydx(n_correct n_dk) predict(outcome(3))

restore


*------------------------------------------------------------------------------
* C5c. ROBUSTNESS — finer State-by-State covariates
*------------------------------------------------------------------------------

display _newline as result "  C5c. FINER DEMOGRAPHIC CONTROLS"

svy: mlogit g43_3 ///
    c.n_correct c.n_dk ///
    i.a3ar_w_sbs i.a5_2015_sbs i.inc_fine ///
    i.sex i.ethnicity, ///
    baseoutcome(1)

estimates store mRob_fine


****
margins, dydx(n_correct n_dk) predict(outcome(3))

*------------------------------------------------------------------------------
* C6. HETEROGENEITY BY GENDER
*------------------------------------------------------------------------------

display _newline as result "  C6. HETEROGENEITY BY GENDER"

svy: mlogit g43_3 ///
    c.n_correct c.n_dk##i.sex ///
    i.agecat i.educ i.income i.ethnicity, ///
    baseoutcome(1)

estimates store mHet_sex


***
margins sex, dydx(n_dk) predict(outcome(3))


***
**Testing Male vs Female AME**
margins sex, dydx(n_dk) predict(outcome(3)) post

lincom _b[2.sex] - _b[1.sex]


***
estimates restore mHet_sex

margins sex, dydx(n_dk) predict(outcome(2)) post

lincom _b[2.sex] - _b[1.sex]


*------------------------------------------------------------------------------*
* C7. Measurement validation — DK against self-assessed knowledge
*------------------------------------------------------------------------------*
display _newline as result "  C7. MEASUREMENT VALIDATION: DK vs G2"

* LABEL THIS CORRECTLY. This reproduces a table FINRA has already published. It
* establishes that our DK tally behaves as the published measure does, which is a
* validation step. It is not a finding and must not be presented as one.
*
* It also cannot establish what DK "means". A monotone relationship between DK
* count and self-assessed knowledge is consistent with several mechanisms, and
* these data cannot separate them without an independent confidence measure.

tabstat n_correct n_incorrect n_dk [aw=wgt1], by(g2_band) statistics(mean) format(%5.2f)
svy: mean n_dk, over(g2_band)
svy: regress n_dk i.g2_band
correlate n_dk g2_scale


***
estimates dir

*------------------------------------------------------------------------------
* C8a. RESULTS TABLE — store AME from primary model
*------------------------------------------------------------------------------

estimates restore mA_mlogit

margins, dydx(n_dk) predict(outcome(3)) post

estimates store ame_primary


*------------------------------------------------------------------------------
* C8b. RESULTS TABLE — G2-adjusted AME
*------------------------------------------------------------------------------

estimates restore mB_g2

margins, dydx(n_dk) predict(outcome(3)) post

estimates store ame_g2


*------------------------------------------------------------------------------
* C8c. RESULTS TABLE — non-quiz DK propensity adjusted AME
*------------------------------------------------------------------------------

estimates restore mC_dkprop

margins, dydx(n_dk) predict(outcome(3)) post

estimates store ame_dkprop


*------------------------------------------------------------------------------
* C8d. RESULTS TABLE — G2 + non-quiz DK propensity adjusted AME
*------------------------------------------------------------------------------

estimates restore mD_g2_dkprop

margins, dydx(n_dk) predict(outcome(3)) post

estimates store ame_g2_dkprop


*------------------------------------------------------------------------------
* C8e. RESULTS TABLE — loose sample rule AME
*------------------------------------------------------------------------------

preserve

    use "$OUT/nfcs_p1_built_full.dta", clear
    svyset [pweight = wgt1]

    svy: mlogit g43_3 ///
        c.n_correct c.n_dk ///
        i.agecat i.educ i.income i.sex i.ethnicity, ///
        baseoutcome(1)

    margins, dydx(n_dk) predict(outcome(3)) post

    estimates store ame_loose

restore

*------------------------------------------------------------------------------
* C8f. RESULTS TABLE — finer demographic controls AME
*------------------------------------------------------------------------------

estimates restore mRob_fine

margins, dydx(n_dk) predict(outcome(3)) post

estimates store ame_fine

*------------------------------------------------------------------------------
* C8g. RESULTS TABLE — binary Yes vs No AME
*------------------------------------------------------------------------------

estimates restore mE_yesno

margins, dydx(n_dk) post

estimates store ame_yesno

*------------------------------------------------------------------------------
* C8h. RESULTS TABLE — binary Yes vs No + DK AME
*------------------------------------------------------------------------------

estimates restore mF_yesall

margins, dydx(n_dk) post

estimates store ame_yesall

***
estimates dir

*------------------------------------------------------------------------------*
* C8i. FINAL RESULTS TABLE — AME of quiz DK on probability of G43 acceptance
*------------------------------------------------------------------------------*

display _newline as result "  C8. RESULTS ACROSS SPECIFICATIONS"

estimates table ///
    ame_primary ///
    ame_g2 ///
    ame_dkprop ///
    ame_g2_dkprop ///
    ame_loose ///
    ame_fine ///
    ame_yesno ///
    ame_yesall, ///
    b(%9.4f) se(%9.4f) stats(N) ///
    title("Average marginal effect of quiz DK on probability of accepting G43")

*------------------------------------------------------------------------------*
* Final analytical decisions log
*------------------------------------------------------------------------------*

file write dec "BLOCK C" _n ///
  "C1 Descriptives and item audit use the strict analytic sample (no quiz refusals)." _n ///
  "C2 Primary model is survey-weighted multinomial logit of G43 (No / DK / Yes), with No as base." _n ///
  "C3 Primary quantities reported are average marginal effects on P(G43=Yes), not raw multinomial coefficients." _n ///
  "C4 Self-assessed knowledge (G2) and general non-quiz DK propensity are evaluated as additional adjustments." _n ///
  "C5 Non-quiz DK propensity is based on 30 universally asked non-quiz items; it is not labeled response style or satisficing." _n ///
  "C6 Robustness checks include loose sample rule, finer demographic controls, and two binary outcome specifications." _n ///
  "C7 Gender heterogeneity is evaluated on the probability scale; no evidence of differential DK effects by gender." _n ///
  "C8 DK/G2 analysis is measurement validation against the published FINRA pattern, not a new substantive finding." _n ///
  "C9 Final results table reports AMEs of quiz DK on P(G43=Yes) across specifications." _n _n

file write dec ///
  "OPEN ITEM: reconcile the 30-item non-quiz DK index against the earlier 26-item version before final manuscript reporting." _n

file close dec

display _newline(2) as result "RUN COMPLETE."
display as text "Analysis decisions: $OUT/analysis-decisions.txt"

log close
