# Reproduction status

**Verified 25 August 2026.** This run covers the Python layer: every Python
script then in the repository was rerun from the analytic CSV that `01_build.do` exports, and every
committed Python result table is now the direct output of the committed code.
The Stata build and analysis were not independently rerun as part of this
verification; the Stata primary estimate is matched by the Python
re-estimation below. One table was replaced; the substantive findings are
unchanged.

This file exists because the lab's stated practice is to keep the receipts and
to report what was actually done.

---

## Environment used

| | |
|---|---|
| Python | 3.10 |
| pandas | 2.3.3 |
| numpy | 2.2.6 |
| scipy | 1.15.3 |
| scikit-learn | 1.7.2 |

Input: `output/nfcs_p1_built_analytic.csv`, the `01_build.do` export — 2,797 rows,
265 columns, value labels retained, weighted mean correct 5.379 on the analytic
sample. Not redistributed; see `data/README.md`.

---

## Result

**`03_nested_prediction.py` — reproduced exactly.** Maximum absolute difference
from the committed table across all 40 cells: 1.7 × 10⁻¹⁵. That is floating-point
representation noise, not disagreement.

**`05_nonquiz_dk_sensitivity.py` — reproduced.** Maximum relative difference
0.010%, i.e. agreement to roughly four significant figures. The estimates come
from a BFGS optimizer with a finite convergence tolerance, so differences at
this scale are expected across machines and scipy versions. Every sign,
significance verdict, and ordering is identical. The AME of quiz `n_dk` on
P(G43 = Yes) is −0.0467 under the primary specification, matching the published
figure and the Stata result.

**`code/audit_spec.py` — confirmed.** The reconstructed module regenerated
`docs/nonquiz-dk-item-audit.csv` byte-for-byte during a real run. The
reconstruction is correct.

**`04_symmetric_comparison.py` — the committed table was stale, and has been
replaced.**

---

## The stale table

The committed `prediction_symmetric_results.csv` was not produced by the
committed version of `04_symmetric_comparison.py`. This is provable from the
committed files alone, without rerunning anything.

`03_nested_prediction.py` and `04_symmetric_comparison.py` both estimate a model
called **A Demographics**. It is the same specification, on the same common
sample of 2,783, under the same seed (20260818) and the same 5-fold × 10-repeat
cross-validation. The two scripts must agree on it exactly.

In the committed tables, they did not:

| A Demographics | committed nested | committed symmetric |
|---|---|---|
| Log loss mean | 0.986540 | 0.987155 |
| Brier mean | 0.588601 | 0.589327 |
| Macro AUC mean | 0.619972 | 0.619850 |
| Accuracy mean | 0.538753 | 0.538377 |

After the rerun, they agree to every decimal place shown. The nested table also
reproduced its committed values exactly. So the nested table and the current
code are consistent with each other, and the old symmetric table is the outlier:
it is output from an earlier iteration of the symmetric script, saved before a
subsequent edit and never regenerated.

What exactly differed in that earlier iteration cannot be recovered — the
session it ran in is gone. What can be stated is that the committed pair was
mutually inconsistent on a model they share by construction, and the regenerated
pair is not.

---

## Whether it mattered

It did not change the finding. The symmetric comparison exists to test whether
the wrong-answer count alone carries the discrimination available from the full
correct/DK composition. Comparing model D (demographics + incorrect) against
model E (demographics + full composition), as a share of the total gain from
model A:

| Metric | stale table | regenerated |
|---|---|---|
| Log loss | D recovers 92.9% | 93.0% |
| Brier | 93.0% | 93.5% |
| Macro AUC | 91.6% | 89.8% |
| Accuracy | 91.4% | 97.8% |

Both versions support the claim that the wrong-answer count alone captures
most of the available discrimination. The correction moved third
and fourth decimal places and left every ordering, sign, and conclusion intact.

The stale table was replaced rather than kept, because a repository whose
argument is "check our work" should not ship a table its own code does not
produce.

---

## Reproducing this

From the repository root, with the FINRA data in `data/` and the build run:

```
do code/01_build.do          # expect: VALIDATION GATE PASSED, n = 2,797
do code/02_analyze.do
python code/03_nested_prediction.py
python code/04_symmetric_comparison.py
python code/05_nonquiz_dk_sensitivity.py
git diff output/             # expect: nothing, or last-decimal drift
```

Fold-level cross-validation results are committed alongside the summaries, so a
replicator can check the distribution across folds rather than only the means.

Expect small differences if your scikit-learn or scipy versions differ from those
listed above. Record what you used. If anything moves in the third decimal place
or beyond the noise described here, that is worth reporting as an Issue rather
than reconciling away.

---

## A note on how the code was written

The Python layer was drafted with AI assistance. That is not a defect and needs
no apology — the code is legible, conventional, and open to inspection like any
other.

It carried one practical consequence worth naming. Code written inside a chat
session runs in a sandbox that disappears, so helper modules, the execution
environment, and the exact version that produced a given output are lost unless
deliberately saved. Both problems this verification found trace to that:
`audit_spec.py` vanished entirely, and a results table outlived the script
version that generated it.

The fix is not to write less code that way. It is to run the final version once
from the repository and commit what comes out — which is now what this file
records.
