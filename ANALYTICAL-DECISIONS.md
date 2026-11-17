# Analytical Decisions

This document records the consequential analytical choices made in Household Finance Lab Project 1, why we made them, what alternatives we considered, and how later diagnostics changed our interpretation. It is a decision record, not a results section.

**Revision 2 — August 2026.** Describes `code/01_build.do` and `code/02_analyze.do` (split from the original single do-file), plus the Python scripts in `code/`. This revision incorporates the non-quiz DK measurement audit, corrects an error in how the P(G43 = Don't know) result was characterized, replaces the gender wording with the estimated contrasts, and adds a validation-gate incident that the earlier version omitted.

---

## 1. Status of the study

**Decision:** Treat the project as exploratory observational research.

The working expectation was formalized after a related result was already known. We therefore do not describe the analysis as preregistered or confirmatory. The NFCS is cross-sectional, and no respondent was assigned to select "don't know" (DK), so all Stata results are described as **associations**, not causal effects.

The Python layer is also exploratory. Repeated cross-validation evaluates out-of-sample predictive stability; it does not convert the observational design into causal evidence.

**Language rules adopted for all project outputs:**

- use "associated with," not causal verbs;
- use "prediction" only for out-of-sample prediction, because G43 is asked before the quiz in the survey;
- do not label DK as confidence, calibration, metacognition, uncertainty recognition, or another latent construct without an independent measure of that construct;
- state attenuation on the **average marginal effect scale**, because that is the study's stated estimand (see §16a).

## 2. Use the Investor Survey as the study population and merge State-by-State data

**Decision:** Use all 2,861 respondents in the 2024 NFCS Investor Survey as the starting population and merge the companion 2024 State-by-State file 1:1 on `NFCSID`.

**Why:** The Investor Survey contains the 11-item investment-knowledge battery, G43, self-assessed investment knowledge, and the appropriate Investor Survey weight. The State-by-State file supplies additional demographic variables used for verification and finer-control robustness analyses.

Every Investor Survey respondent matched a State-by-State record. The Investor respondents are a screened subset of the State-by-State respondents.

**Implementation decision:** Suffix every State-by-State variable with `_sbs` before merging, rather than renaming only known collisions.

**Why:** The two files reuse variable names for different questions. Suffixing all State-by-State variables makes provenance explicit and prevents unnoticed future collisions.

## 3. Use `WGT1` as the analysis weight

**Decision:** Use the Investor Survey weight `WGT1`, not State-by-State weights.

**Why:** The analysis population is the 2,861 Investor Survey respondents. State-by-State weights apply to the larger State-by-State sample and do not carry the Investor Survey subsampling correction.

**Limitation retained in interpretation:** `WGT1` post-stratifies on age and education only. It does not post-stratify on sex, income, or ethnicity. FINRA does not release PSU or stratum identifiers sufficient to reconstruct a clustered survey design, so the Stata analysis uses the available probability weight under the design information supplied.

## 4. Freeze the investment-knowledge battery at 11 items

**Decision:** Define the knowledge battery as `G4 G5 G6 G7 G21 G8 G44 G22 G11 G12 G13`, and exclude `G23`.

**Why:** FINRA's 2024 documentation defines the Investor Survey quiz as 11 items, including the new inflation item `G44`. `G23`, the call-option question, is a bonus item and is not counted in FINRA's 11-item score.

Correct-answer keys and option counts were taken from the survey instrument and encoded explicitly in the build script.

## 5. Preserve three response states rather than only a conventional score

**Decision:** Construct `n_correct`, `n_dk`, `n_pnts` (code 99), and `n_incorrect = 11 − n_correct − n_dk − n_pnts`.

**Why:** The research question concerns whether incorrect and DK responses contain different information. Collapsing them at construction would remove the distinction before it could be studied.

## 6. Define incorrect responses strictly and exclude refusals from `n_incorrect`

**Decision:** Do **not** count code 99 ("prefer not to say") as an incorrect response in the primary measure.

**Why:** This was empirically validated against FINRA's published gender means. Under the strict definition, male and female incorrect counts were approximately 3.31 and 3.33, both reproducing FINRA's published 3.3 after rounding. Folding refusals into incorrect produced approximately 3.36 and 3.41, which round to 3.4 and fail that validation.

**Alternative retained:** `n_incorrect_loose = 11 − n_correct − n_dk` is retained only for the loose-sample robustness analysis.

## 7. Validate the reconstruction before restricting the sample

**Decision:** Run the FINRA validation gate on the full 2,861 respondents before applying the analytic-sample refusal rule.

**Why:** Reproducing published statistics and defining the estimation sample answer different questions. Restricting first breaks specific validation targets: on the restricted sample the weighted female mean correct rises from **4.54 to 4.59**, which rounds to 4.6 against FINRA's published 4.5, and the G40 contrast becomes 5.63 / 5.28 against a published 5.6 / 5.2. Gating on the analytic sample would therefore fire a failure at a correctly built pipeline.

The build is designed to stop if the reconstructed weighted means drift beyond the specified tolerances.

## 7a. Validation-gate incident: the G43 distribution target

**What happened:** The gate initially specified the G43 response distribution as 50 / 21 / 30, taken from FINRA's published figures, with a tolerance of 0.06. The computed Yes share was 49.58. The gate failed by 0.42 and halted the run. The targets were then rewritten to 49.6 / 20.6 / 29.6 and the gate passed. Both events are visible in the run log.

**Why this needed a decision rather than a silent edit:** Changing a target so that a failing check passes is the single move a validation gate exists to prevent. Recording it is the point of having this file.

**The underlying problem is real.** FINRA publishes that distribution rounded to whole percentages. A tolerance of 0.06 cannot accommodate a target rounded to the nearest point — any true value in [49.5, 50.5) is consistent with a published 50, and 49.58 is one of them. The gate was mis-specified, not the data.

**The correct fix, adopted going forward:** tolerance is set to match the precision at which the target was published. Targets published to one decimal keep the 0.06 tolerance; targets published to whole percentages get a 0.5 tolerance. This preserves the gate's purpose — catching drift — without failing on rounding.

**What we did not do:** we did not re-specify a target to match a computed value elsewhere in the gate. Every other target in `01_build.do` is FINRA's published figure as published.

## 8. Use a strict primary analytic sample

**Decision:** Primary Stata analyses exclude respondents with one or more refusals on the 11 quiz items. This yields **n = 2,797** from the full 2,861.

**Why:** On the strict analytic sample, `n_correct + n_incorrect + n_dk = 11`. Keeping quiz refusals while using the residual incorrect count would mix refusals with substantive incorrect answers.

**Robustness decision:** Re-estimate the primary model on the looser sample rather than treating the strict rule as beyond question.

## 9. Treat the three knowledge counts as compositional

**Decision:** Never enter `n_correct`, `n_incorrect`, and `n_dk` simultaneously.

**Why:** They sum to 11 on the strict analytic sample and are therefore linearly dependent.

The primary Stata specification is `f(n_correct, n_dk, covariates)`. At fixed `n_correct`, an additional DK necessarily replaces an incorrect response. The marginal association of `n_dk` is therefore interpreted as an **incorrect-to-DK substitution at fixed demonstrated knowledge**, not as an unconstrained increase in DK responses.

This compositional interpretation is load-bearing for the study.

## 9a. Two estimands for the substitution, both reported

**Decision:** The full-sample AME is the primary quantity. The AME restricted to respondents with `n_incorrect > 0` is reported as a **complementary** estimand, not as a correction.

**Why:** A one-unit increase in `n_dk` at fixed `n_correct` means one fewer incorrect answer. For a respondent already at zero incorrect there is nothing left to substitute, so the full-sample average includes cases where the contrast is not literally feasible.

The two answer different questions on different populations: the full-sample AME is the population-level association; the restricted AME describes the subpopulation where the substitution is feasible for everyone. The difference between them indicates how much the full-sample estimate rests on boundary cases.

**Alternative rejected:** reporting only the restricted version as the "cleaner" contrast. That silently redefines the population the claim is about.

## 9b. The compositional identity constrains figures as well as models

**Decision:** Any predicted-probability figure that varies `n_dk` holds `n_correct` fixed at a value where the plotted DK range is feasible.

**Why:** Varying `n_dk` from 0 to 8 while leaving `n_correct` at observed values asks the model to evaluate respondents who cannot exist — someone with 10 correct answers cannot have 8 don't-knows. Predictions there lie outside the compositional support.

At `n_correct = 5`, DK can validly run 0 to 6. A three-stratum version at `n_correct` = 3, 5, 7 uses a common DK range of 0 to 4, which is feasible at all three levels.

## 10. Keep G43 as a three-category outcome in the primary model

**Decision:** Primary outcome coded 1 = No (base), 2 = Don't know, 3 = Yes, with G43 refusals set missing.

**Why:** The project questions whether DK is substantively interchangeable with another response state. Collapsing G43 DK with No in the primary model would impose the same kind of equivalence the study is examining.

**Secondary outcomes:** Yes versus No (dropping G43 DK) and Yes versus No + DK, retained as robustness. Neither replaces the three-category primary outcome.

## 11. Use survey-weighted multinomial logistic regression for the primary inferential analysis

**Decision:** Estimate survey-weighted multinomial logistic regression with `n_correct`, `n_dk`, age, education, income, sex, and ethnicity.

**Why:** G43 has three substantive response categories, and the primary estimand concerns the probability of accepting the proposition while retaining DK as a separate outcome.

Ethnicity is included as an adjustment, not interpreted as a substantive finding. It is a coarse binary collapse and is not a post-stratification dimension of `WGT1`.

## 12. Report average marginal effects rather than lead with multinomial coefficients

**Decision:** Make the average marginal effect (AME) of quiz DK on `P(G43 = Yes)` the primary reported quantity.

**Why:** Raw multinomial coefficients are log-odds relative to a base outcome and are difficult to translate substantively. AMEs express the result directly as a change in predicted probability.

**Primary estimate:** −0.0467 (SE 0.0064).

**Across the six comparable multinomial specifications** — with G2, with non-quiz DK propensity, with both, loose sample rule, finer covariates, and the Yes-versus-No+DK binary — the estimate ranges from **−0.0419 to −0.0468**.

**One specification sits outside that band and is reported separately.** The Yes-versus-No binary, which drops the 989 respondents who answered DK on G43, gives −0.0294 (SE 0.0082). This is expected rather than anomalous: it estimates a different quantity on a different sample (n = 1,828), conditioning on having taken a position at all. It is reported with that explanation rather than folded into the range.

The AME is an association, not a causal effect.

**What the AME is, precisely.** `n_dk` enters the model as a continuous term, and `margins, dydx(n_dk)` returns the average derivative of P(G43 = Yes) with respect to the DK count, holding `n_correct` fixed. Because the three tallies sum to 11, that is the instantaneous rate of trading an incorrect response for a DK. The plain-language phrase "each additional 'don't know' in place of a wrong answer" approximates this derivative; it is not the average finite change from one answer to the next. Section 12a reports that discrete-substitution estimate.

## 13. Add self-assessed knowledge as a robustness adjustment, not as a mediator claim

**Decision:** Add `g2_scale` as an additional adjustment in a secondary specification.

**Interpretive boundary:** G2 is measured before the quiz and is not treated as a mediator of quiz response behavior. Its inclusion asks whether the DK association persists conditional on self-assessed knowledge.

**Sample-comparability decision:** G2 has DK and refusal responses that go missing, so Model A is refit on Model B's estimation sample (n = 2,783). Otherwise coefficient movement between the two would partly reflect a change in who is in the model rather than the effect of adding G2.

## 14. The non-quiz DK measure — construction, audit, and revision

**What the measure is:** a count of how often a respondent selected code 98 on Investor Survey items unrelated to the knowledge quiz, used as a partial check on whether quiz DK merely reflects a general tendency to select DK elsewhere.

**Original construction (30 items).** The measure used in the published Stata run counts DK across 30 universally-asked non-quiz items, excluding G43, the 11 quiz items, G2/G40/G41, and items behind skip patterns.

**Why it was revised.** The 30-item list was not generated from a fully specified, exhaustive eligibility rule. The do-file states the reason for its scope explicitly: the list was trimmed *"to keep the index close to the earlier 26-item version."* That is anchoring on a prior list rather than a conceptual criterion, and it is the kind of choice that invites the suspicion that the measure was selected to protect a result.

A separate concern: an earlier project iteration used a 26-item index correlating .389 with quiz DK, while the 30-item index correlates .526. **The 26-item list could not be reconstructed from available materials and has not been guessed at.** It is documented as superseded rather than compared.

**The frozen eligibility rule.** An item is eligible iff, per the instrument's documented skip logic and the data dictionary:

1. it is administered to every continuing respondent — established from routing, **not** from patterns of nonmissing data;
2. it offers code 98 = "Don't know" as a substantive response option;
3. it is not a quiz item, not G23, not the outcome G43, not a variable used as a model covariate elsewhere (G2, G40, G41), and not an eligibility screener where selecting DK terminated the interview (A1, A3);
4. it is not an ID, weight, or demographic.

Eligibility was determined without reference to G43 or to any outcome result. Applied to all 105 variables: **69 eligible, 36 excluded.** The item-by-item audit is in `docs/nonquiz-dk-item-audit.csv`.

**What the audit revealed about the 30-item list.** It omitted 39 eligible items across four grid blocks: B2 ownership (11), F30 reliance (11), F31 platforms (11), G30 motives (6).

**DK opportunity is not one thing.** Among the 69 eligible items: behavioral self-report 27, factual/account knowledge 21, attitudinal/self-description 14, recollection 7. A DK on "does your account permit margin" is a different act from a DK on "how much do you rely on podcasts."

**Battery balancing, specified before running.** Six blocks are grids (47 rows total); the remaining 22 items are their own blocks. The balanced index is the unweighted mean across all 28 blocks of the within-block DK rate, so an 11-row grid carries the same weight as one stand-alone question.

**Naming decision retained:** this is **general non-quiz DK propensity**, never response style, satisficing, confidence, or metacognition. Several component items ask about facts respondents may genuinely not know about their own accounts.

**Limitation:** the index is measured with error and is a partial control, not a solution to unobserved response tendencies.

## 14a. The specification hierarchy after the audit

| Level | Specification |
|---|---|
| Primary inferential model | No non-quiz DK control |
| Original robustness | 30-item non-quiz DK measure |
| Preferred measurement-sensitivity specification | 69-item rule-derived measure |
| Additional sensitivity | Battery-balanced 69-item version |
| Exploratory measurement diagnostics | Four DK-opportunity sub-indices |

The word "primary" belongs to the model with no non-quiz control. The non-quiz measure is auxiliary robustness throughout, and no version of it is promoted to primary.

The 30-item measure is retained because the published Stata results were computed with it; removing it would break the correspondence between the log and the write-up.

## 15. Use several robustness specifications rather than one preferred alternative

The robustness set was deliberately heterogeneous: self-assessed knowledge; general non-quiz DK; both together; loose refusal/sample rule; finer age, education and income controls; and two binary outcome specifications.

**Decision rule:** look for stability in the probability-scale estimate rather than select the specification with the largest or smallest coefficient.

## 16. Measurement sensitivity of the non-quiz DK control

**Decision:** Re-estimate the targeted G43 sensitivity analysis under every defensible construction of the auxiliary measure, changing nothing else, and report whatever results.

**AME of quiz `n_dk` on P(G43 = Yes):**

| Non-quiz adjustment | AME | SE | 95% CI |
|---|---:|---:|---|
| None (primary model) | −.0467 | .0064 | [−.0592, −.0342] |
| 30-item (original robustness) | −.0423 | .0070 | [−.0560, −.0286] |
| 69-item rule-derived | −.0411 | .0068 | [−.0545, −.0278] |
| 69-item battery-balanced | −.0417 | .0070 | [−.0555, −.0279] |

Including the four sub-indices, the full range across eight specifications is −.0403 to −.0467, every interval excludes zero, and every p < .001. **The association between quiz DK and acceptance of G43 does not materially depend on how the auxiliary non-quiz DK control is constructed.**

**Battery weighting:** item-weighted and balanced versions differ by .0006 on P(Yes) and .0042 on P(Don't know), both smaller than one standard error. Balancing raises the correlation with quiz DK from .497 to .539 because down-weighting the two large social-media and reliance grids concentrates the measure on account-knowledge items. The concern is legitimate in principle and immaterial here.

**No item was dropped or added to weaken or strengthen a result.** Eligibility was fixed before any outcome model was run.

## 16a. Correction: the P(G43 = Don't know) result

**The earlier version of this file, and commentary written from it, mischaracterized this result.** The error was reading a coefficient as if it were a marginal effect.

Both of these are true and they answer different questions:

- In the **Don't-know-versus-No equation**, the coefficient on `n_dk` falls from +.1007 to +.0286 (p = .519) when the 30-item index is added.
- The **AME on P(G43 = Don't know)** falls from +.0377 to +.0266 and remains significant at p < .001.

**Correct wording:** adjustment for non-quiz DK responding **attenuates the association between quiz DK and subsequently selecting DK on G43, but does not eliminate it.** Under the 30-item measure the AME declines from 3.77 to 2.66 percentage points, roughly one-third.

| Non-quiz adjustment | AME on P(DK) | SE | 95% CI |
|---|---:|---:|---|
| None | +.0377 | .0054 | [+.0271, +.0482] |
| 30-item | +.0266 | .0058 | [+.0152, +.0380] |
| 69-item rule-derived | +.0297 | .0057 | [+.0185, +.0410] |
| 69-item battery-balanced | +.0255 | .0059 | [+.0140, +.0371] |

The attenuation is generally larger for P(Don't know) than for P(Yes). General non-quiz DK behavior explains **some, but clearly not all**, of the relationship with withholding judgment.

**Standing rule adopted from this error:** attenuation claims are made on the AME scale, because that is the study's stated estimand. A coefficient in one equation of a multinomial model is not a probability-scale association and must not be reported as one.

## 16b. Sub-index diagnostics — exploratory only

The 69 eligible items split into four DK-opportunity types whose correlations with quiz DK range from .174 to .464, and which correlate only .20 to .64 with one another. The whole-index measures are consistently associated with selecting DK on G43; the sub-indices differ substantially, and the attitudinal (p = .128) and behavioral self-report (p = .265) sub-indices are not.

**Interpretation, deliberately limited:** the heterogeneous sub-index patterns caution against treating non-quiz DK as a unitary response-style construct and strengthen the case for measuring the underlying mechanisms directly in a future experiment.

This is suggestive evidence of heterogeneity rather than a falsification of a single latent tendency. Multiple noisy indicators of one underlying disposition can diverge because of domain, item format, reliability, base rates, and measurement error. None of it was prespecified, and it is reported as a measurement observation rather than a finding.

## 17. Treat the G2/DK relationship as measurement validation, not a new finding

**Decision:** Compare quiz DK counts across self-assessed knowledge bands to reproduce the known FINRA pattern.

**Observed:** weighted mean DK declines from 4.06 (low self-assessed knowledge) to 2.58 (neutral) to 1.41 (high); `corr(n_dk, g2_scale) ≈ −0.468`.

**Interpretation:** this supports that our reconstructed DK tally behaves as expected. It does **not** establish what DK means psychologically and is not presented as a novel substantive finding.

## 18. Audit items against their actual chance rates

**Decision:** Evaluate each quiz item's accuracy among attempters against the chance rate implied by its number of substantive answer options.

**Why:** The 11 items vary from two to five options, so chance accuracy varies from .50 to .20. A single total score hides this item-format heterogeneity.

The audit identified two items answered below chance among attempters — G21 (−3.7 points) and G12 (−6.3). Error concentration on particular distractors was treated as a separate diagnostic rather than equated with below-chance performance; the two properties coincide in only one item.

**Language boundary:** among respondents who attempted these items, weighted accuracy was below the uniform-random-choice benchmark implied by the number of answer options. This warrants investigation of distractor selection, wording, and item functioning; it does not by itself establish the item's relationship with latent knowledge or how well it discriminates between respondents. Nor does it establish that respondents are guessing randomly or that any distractor is definitively a misconception. Where errors concentrate on one distractor, the defensible phrasing is "consistent with systematic misunderstanding rather than uniform random responding."

This item audit became important for designing a future experiment, but it remains descriptive in Project 1.

## 19. Test gender as heterogeneity, not as a rediscovery of a main effect

**Decision:** Evaluate whether the DK-to-G43 association differs by gender using an interaction and probability-scale contrasts.

**Why:** A significant main effect of gender would not answer the heterogeneity question. The relevant test is whether the marginal association of `n_dk` differs between men and women.

**Subgroup AMEs on P(Yes):** men −4.82 percentage points (95% CI −6.54 to −3.10); women −4.56 (95% CI −5.99 to −3.13). The association is present in both groups.

**The contrast:** the estimated female-minus-male difference in the DK AME on P(Yes) was **+0.27 percentage points (95% CI −1.67 to +2.20)**. The interval included zero. This analysis therefore **did not resolve** whether the DK association differs by gender; it should not be interpreted as evidence that the associations are equivalent. The interval is wide enough to accommodate a difference of roughly two percentage points in either direction.

The corresponding difference on P(Don't know) was **+0.75 percentage points (95% CI −0.79 to +2.29)**, with the same interpretation.

Because `WGT1` does not post-stratify on gender, subgroup interpretation remains cautious.

## 20. Separate the Stata inferential layer from the Python predictive layer

**Decision:** Do not use Python merely to reproduce the Stata regressions.

**Why:** That would add computational duplication but little scientific value. The Python extension instead asks a distinct question: whether response composition improves prediction for held-out respondents. The predictive sample is **n = 2,783**, complete on all variables required across the compared models.

## 21. Do not make accuracy the main predictive metric

**Decision:** Emphasize macro AUC, log loss, and Brier score; treat classification accuracy as secondary.

**Why:** Across folds, the probability-quality and discrimination improvements were substantially more stable than the small accuracy improvement. Fold-paired, the DK-augmented model beat the correct-only model on AUC in 48 of 50 folds and on log loss in 49 of 50, but on accuracy in only 36 of 50, with a standard deviation across folds larger than the mean gain.

## 22. Reject the first nested-model interpretation after detecting order dependence

**Initial observation:** In the nested predictive sequence, adding `n_correct` after demographics improved macro AUC only modestly (+.0042), whereas adding `n_dk` next produced a much larger increment (+.0175). An early interpretation was that the "discarded" DK variable carried roughly four times the predictive value of the conventional correct count.

**Decision:** Do not retain that interpretation.

**How the problem was identified — provenance.** This was raised in **external review of a draft**, not by our own internal diagnostics. We record that because the value of this file depends on it being an accurate account of how conclusions arrived, and a correction that came from outside is more informative to a reader than one that appears to have come from inside.

**Why the interpretation failed:** `n_correct` and `n_dk` correlate at −.68. The increment for each variable depends on which predictors are already in the model. Reversing the entry order changes the baseline against which its added predictive value is measured, so nested increments cannot be treated as an order-invariant allocation of importance. Reversing the order gave +.0098 for DK entering first and +.0119 for correct entering second — four-to-one became roughly six-to-five. The original ratio was a property of the **sequence**; it did not identify an intrinsic ranking of the variables. Sara Kay then ran the reverse-order models and built the symmetric comparison in Section 23.

This was a substantive analytical correction, not a presentation change.

## 23. Add a symmetric predictive comparison

**Decision:** Compare equal-sized models in which demographics are augmented separately by `n_correct`, `n_dk`, or `n_incorrect`, alongside the full `n_correct + n_dk` composition model.

**Why:** This removes the entry-order advantage and asks each one-dimensional summary to predict under the same validation architecture.

| Model | Macro AUC |
|---|---:|
| Demographics | .620 |
| + correct | .624 |
| + DK | .629 |
| + incorrect | .639 |
| + correct + DK | .642 |

**Interpretive consequence:** `n_incorrect` alone captures most of the incremental discrimination available from the two-dimensional composition: about 89.8% of the full model's macro-AUC improvement over demographics (see `docs/REPRODUCTION-STATUS.md`). The full composition improved macro AUC by approximately .0022 beyond the incorrect-count model, favoring the fuller model in 34 of 50 folds. Overall discrimination remains modest; the full model's gain over demographics is about .022 macro AUC.

This replaced the earlier "DK adds four times as much" story.

**Basis-relativity caveat:** because the three tallies sum to 11, "the incorrect count" is one linear combination among several. The claim that survives scrutiny is dimensional — the battery's predictive content is essentially one-dimensional, and the dimension that captures it aligns with the incorrect count.

## 24. Distinguish the inferential and predictive conclusions

**Stata question:** at a fixed number correct, does substituting DK for an incorrect response correspond to a different probability of accepting G43?

**Python question:** which compact summary of the quiz responses best predicts held-out G43 responses?

The Stata analysis indicates that DK and incorrect responses are not behaviorally equivalent conditional on the number correct. The symmetric Python analysis indicates that, for this particular prediction task, the incorrect count alone captures most of the useful response-composition signal.

**Decision:** Do not claim that Python "validates" a causal interpretation of the Stata result. It provides an out-of-sample predictive extension and a diagnostic that sharpened the substantive interpretation.

## 25. Do not infer linearity from one failed flexible model

**Decision:** A preliminary gradient-boosting model was not promoted as evidence that the underlying signal is linear.

**Why:** One untuned flexible model performing worse than multinomial logistic regression establishes only that this particular implementation did not improve prediction. The defensible statement is that it provides **no evidence that added model flexibility improves prediction in this dataset**. No further tuning was pursued because the goal of the Python layer was targeted diagnostic prediction, not a model-selection competition.

## 26. Report weak prediction of outright rejection as a finding, not a footnote

**Decision:** Retain class-specific discrimination rather than report only macro AUC.

One-vs-rest AUC for the No class was .546 in the incorrect-count model, against .695 for Don't know and .683 for Yes.

**Interpretation:** the variables in this study say much more about acceptance and withholding judgment than about what produces active rejection of the proposition. We do not infer a psychological explanation for rejection from this feature set. This also shapes future experimental design: a study intended to explain active rejection needs measures constructed for that outcome.

## 27. Treat the high G43 acceptance rate as an outcome-interpretation limitation

**Decision:** Do not assume every Yes response necessarily reflects gullibility, fraud susceptibility, or failure to recognize an implausible return.

Nearly half the sample (49.6%) accepted the guaranteed, risk-free 25% proposition. One interpretation is substantive susceptibility; another is that some respondents treated the guarantee as a stipulated premise of the hypothetical. The NFCS item cannot distinguish those readings. G43 is therefore described narrowly as **acceptance of the proposition**, not as a validated measure of fraud susceptibility or decision quality.

## 28. Keep literature positioning conservative

**Decision:** Do not claim that Project 1 discovered that DK and incorrect responses differ. Prior political-knowledge, financial-literacy, measurement, and experimental literatures already establish important parts of that ground.

The project's narrower contribution is framed around the 11-item NFCS Investor Survey, the fixed-correct incorrect-versus-DK substitution, the linked G43 judgment item, item-format heterogeneity, and a fully reproducible Stata/Python workflow.

Claims whose source records or exact findings have not yet been verified remain flagged in `LITERATURE.md` rather than being silently upgraded to established facts.

## 29. Separate build, analysis, and prediction into reproducible stages

**Decision:** Split the original single do-file into `code/01_build.do` (raw data, merge, construction, validation gate, analytic flags, frozen datasets) and `code/02_analyze.do` (descriptives, item audit, inferential models, robustness, heterogeneity, results), with the Python scripts operating on the frozen analytic export.

**Why:** Data construction should be deterministic and reusable. Analysis should begin from a frozen validated dataset rather than repeatedly rebuilding or mutating raw data. The split also removed an awkward save-and-reload that the loose-sample robustness check previously required.

Respondent-level `.dta` and `.csv` files are not committed to GitHub. The build script recreates them from source data obtained through FINRA.

## 30. Data-integrity note: label export and pandas

**What we found:** `01_build.do` exports the analytic file with `export delimited`, which writes value **labels** rather than numeric codes. One legitimate response label is the string `"None"` (B3 = no trades in the past 12 months, 772 respondents). Pandas converts `"None"` to missing under default settings.

**Decision:** any Python reading item-level responses from the labeled export must use `keep_default_na=False`. This is documented in `data/README.md` and implemented in `code/05_nonquiz_dk_sensitivity.py`.

**Scope of the problem:** the existing prediction scripts were checked and are unaffected — they use only numeric derived variables and the G43 labels, none of which are NA-like strings.

## 31. Preserve decisions that changed the story

A core reproducibility rule for this project is that the repository documents not only successful analyses but also analytical turns that changed interpretation. Three are recorded here:

- the nested predictive comparison and its order dependence (§22);
- the P(G43 = Don't know) coefficient-versus-AME error (§16a);
- the non-quiz DK index scope and its revision (§14).

Each belongs in the record because it demonstrates what the diagnostic was for and prevents a future reader from resurrecting a discarded interpretation from the surviving output.

## 32. What Project 1 ultimately supports

The project supports a deliberately narrow conclusion:

> Among Investor Survey respondents with the same number of correct quiz answers, replacing an incorrect response with DK is associated with a lower probability of accepting G43. The association is stable across the examined specifications, including every defensible construction of the auxiliary non-quiz DK control. Out-of-sample prediction further shows that response composition contains information omitted by a conventional correct-count score, with the incorrect count alone capturing most of the predictive signal available from the full correct/DK composition for this particular outcome.

It does **not** establish why respondents select DK, that DK is inherently beneficial, or that changing DK behavior would causally improve judgment.

Those are questions for a prospective experiment.

---

## What remains open

These are unresolved pieces of the reproducibility record. They are not analyses required before Project 1 can be considered complete.

1. **Unweighted secondary predictive run.** The standing requirement specifies an explicit weighted-versus-unweighted decision with one primary chosen in advance. The weighted analysis was run and declared primary; the unweighted secondary has not been produced.
2. **Calibration documentation.** The claim that adding the non-quiz DK measure improves probability quality while slightly reducing classification accuracy rests on log loss and Brier score. Calibration curves would document it directly.
3. **The 26-item non-quiz DK index.** Not reconstructable from available materials. Documented as superseded rather than compared; deliberately not guessed at.
4. **Publisher records for `LITERATURE.md`.** The Mondak works (the study's theoretical spine) and Bucher-Koenen et al. are cited from reading notes. Two claim-level characterizations also need checking against the papers: the direction of the Cucinelli and Soana fraud result, and the Tranfaglia et al. Table 1 and Table 3 figures.
5. **FINRA redistribution permission.** Whether derived respondent-level files may be redistributed has not been confirmed with the FINRA Foundation. Until it is, the repository ships code and instructions rather than data.

---

*This file is the curated decision record. Machine-generated decision logs from the Stata run are retained separately in `output/` as supporting provenance.*
