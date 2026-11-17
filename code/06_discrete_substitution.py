"""
06_discrete_substitution.py
Household Finance Lab, Project 1

PURPOSE
  The primary estimate (02_analyze.do, `margins, dydx(n_dk) predict(outcome(3))`)
  is an average DERIVATIVE of P(G43 = Yes) with respect to the DK count, holding
  the correct count fixed. The plain-language claim is a discrete swap: one wrong
  answer becomes one "don't know." This script estimates that swap directly.

  Among respondents for whom the swap is feasible (at least one incorrect answer),
  it reports the weighted average of
      P(Yes | C_i, D_i + 1, X_i) - P(Yes | C_i, D_i, X_i)
  from the same primary weighted multinomial logit, with a delta-method SE.
  For comparison it also reports the average derivative on the full sample (the
  primary AME, which should match Stata's -0.0467) and on the feasible subsample.

INPUT   output/nfcs_p1_built_analytic.csv   (written by code/01_build.do)
OUTPUT  output/tables/discrete_substitution_results.csv
RUN     python code/06_discrete_substitution.py   (from the repository root)
"""
import numpy as np
import pandas as pd
from scipy import stats

from wmnl import fit_wmnl, ame
from paths import TABLES, require_analytic_csv

CSV = require_analytic_csv()
d = pd.read_csv(CSV, low_memory=False, keep_default_na=False)
d.columns = [c.strip() for c in d.columns]
d = d[d['g43_3'].isin(['No', "Don't know", 'Yes'])].copy()
for c in ['n_correct', 'n_dk', 'wgt1']:
    d[c] = d[c].astype(float)
d['n_incorrect'] = 11 - d['n_correct'] - d['n_dk']   # analytic sample has no refusals
y = d['g43_3'].map({'No': 0, "Don't know": 1, 'Yes': 2}).values
w = d['wgt1'].values

# Same design as the primary model in 05_nonquiz_dk_sensitivity.py
parts = [np.ones((len(d), 1)), d[['n_correct', 'n_dk']].values]
names = ['_cons', 'n_correct', 'n_dk']
for var, base in [('agecat', '18-34'), ('educ', 'Some college or less'),
                  ('income', '<$50K'), ('sex', 'Male'), ('ethnicity', 'White non-Hispanic')]:
    for c in [c for c in sorted(d[var].unique()) if c != base]:
        parts.append((d[var] == c).values.astype(float).reshape(-1, 1)); names.append(f'{var}={c}')
X = np.hstack(parts)
J = names.index('n_dk')
K, YES = 3, 2

fit = fit_wmnl(X, y, w, [0, 1, 2])
b, V, p = fit['b'], fit['V'], fit['p']
# BFGS with gtol=1e-10 often reports precision loss rather than success (as in
# 05_nonquiz_dk_sensitivity.py). The real check: the primary AME must reproduce
# Stata's published -0.0467.
assert abs(ame(fit, J, YES)[0] - (-0.0467)) < 5e-5, "primary AME does not reproduce Stata's -0.0467"


def probs(bvec, Xm):
    B = bvec.reshape(K - 1, p)
    eta = np.hstack([np.zeros((Xm.shape[0], 1)), Xm @ B.T])
    m = eta.max(1, keepdims=True); e = np.exp(eta - m)
    return e / e.sum(1, keepdims=True)


def delta_se(fun):
    g = np.zeros_like(b)
    for i in range(len(b)):
        h = 1e-6 * max(1.0, abs(b[i])); bp = b.copy(); bm = b.copy()
        bp[i] += h; bm[i] -= h
        g[i] = (fun(bp) - fun(bm)) / (2 * h)
    return float(np.sqrt(g @ V @ g))


feasible = (d['n_incorrect'] >= 1).values
XF, wF = X[feasible], w[feasible]
XF1 = XF.copy(); XF1[:, J] += 1          # one incorrect becomes one DK; correct unchanged


def swap(bvec):
    return np.sum(wF * (probs(bvec, XF1)[:, YES] - probs(bvec, XF)[:, YES])) / np.sum(wF)


def deriv(bvec, Xm, wm):
    P = probs(bvec, Xm)
    B = bvec.reshape(K - 1, p)
    beta = np.concatenate([[0.0], B[:, J]])
    return np.sum(wm * P[:, YES] * (beta[YES] - P @ beta)) / np.sum(wm)


rows = []
e_full, s_full = ame(fit, J, YES)
rows.append(('Average derivative, full sample (primary AME)', len(d), e_full, s_full))
rows.append(('Average derivative, feasible subsample', int(feasible.sum()),
             deriv(b, XF, wF), delta_se(lambda bv: deriv(bv, XF, wF))))
rows.append(('Discrete swap: one incorrect -> one DK, feasible subsample', int(feasible.sum()),
             swap(b), delta_se(swap)))

out = pd.DataFrame(rows, columns=['Estimand', 'N', 'Estimate', 'SE'])
out['CI low'] = out['Estimate'] - 1.96 * out['SE']
out['CI high'] = out['Estimate'] + 1.96 * out['SE']
out['p'] = 2 * (1 - stats.norm.cdf(np.abs(out['Estimate'] / out['SE'])))
out.to_csv(TABLES / 'discrete_substitution_results.csv', index=False)
print(f"Analytic sample with valid G43: N = {len(d):,}; feasible (n_incorrect >= 1): {feasible.sum():,}")
print(out.round(4).to_string(index=False))
