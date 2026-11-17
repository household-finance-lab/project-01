# Study Workflow

How Project 1 runs, from the two public-use source files to the two things that came out the other end.

## The pipeline, as files

Which file does what, and where each artifact lives in the repository.

![ETL pipeline for Household Finance Lab Project 1. Source data from the 2024 FINRA NFCS Investor Survey (N = 2,861) and State-by-State Survey (N = 25,539) feeds code/01_build.do, which merges on NFCSID, runs a validation gate against FINRA published figures, and freezes an analytic sample of 2,797. code/02_analyze.do runs the survey-weighted multinomial logit and marginal effects in Stata. The handoff to Python is output/nfcs_p1_built_analytic.csv, a gitignored respondent-level export of 2,797 rows by 265 columns. Three Python scripts — 03_nested_prediction, 04_symmetric_comparison and 05_nonquiz_dk_sensitivity, with support modules paths.py, wmnl.py and audit_spec.py — produce aggregate result tables in output/tables/, which feed the Empirically Yours write-up. Documentation, metadata and infrastructure files are listed beneath.](etl-pipeline.svg)

**The handoff is the part worth reading twice.** What crosses from Stata to Python is
`output/nfcs_p1_built_analytic.csv` — respondent-level, 2,797 rows, gitignored and never
published. It is not `stata_primary_results.csv`, which is a summary of marginal effects
and an *output* of the study rather than an input to anything.

## The pipeline, as analysis

The same study seen as questions and estimands rather than as files.

```mermaid
flowchart TD
    A["<b>2024 NFCS Investor Survey</b><br/>N = 2,861"]
    B["<b>2024 NFCS State-by-State Survey</b><br/>N = 25,539"]
    C["<b>01_build.do</b><br/>Merge 1:1 on NFCSID<br/>Validation gate vs FINRA published figures<br/>Construct quiz tallies and outcome"]

    A --> C
    B --> C

    C --> D["Full built data<br/>N = 2,861"]
    C --> E["Strict analytic data<br/>N = 2,797<br/><i>quiz refusals dropped</i>"]

    D -.->|loose-sample robustness| F
    E --> F["<b>02_analyze.do</b><br/>Survey-weighted multinomial logit<br/>Average marginal effects<br/>Item audit, robustness, heterogeneity"]
    E --> G["Python common sample<br/>N = 2,783"]
    E --> H["<b>05_nonquiz_dk_sensitivity.py</b><br/>Measurement sensitivity of the<br/>auxiliary non-quiz DK control"]

    G --> I["<b>03_nested_prediction.py</b><br/>Repeated stratified 5-fold CV × 10"]
    G --> J["<b>04_symmetric_comparison.py</b><br/>Equal-sized model comparison"]

    F --> K["<b>Inferential result</b><br/>At a fixed number correct,<br/>substituting DK for a wrong answer is<br/><i>associated with</i> a lower probability<br/>of accepting G43"]
    I --> L["Out-of-sample evidence"]
    J --> L
    L --> M["<b>Predictive result</b><br/>The wrong-answer count alone captures<br/>most of the discrimination added by<br/>the full correct/DK composition"]
    H --> N["<b>Sensitivity result</b><br/>The P(Yes) association is stable across<br/>every non-quiz DK construction<br/>(30-item, 69-item, battery-balanced)"]

    K --> O["Joint interpretation"]
    M --> O
    N --> O

    O --> P["<b>Wrong and DK both score zero,<br/>but they do not carry the same information<br/>for subsequent judgment</b>"]

    P --> Q["<i>Empirically Yours</i><br/>Two Ways to Get a Zero"]
    P --> R["Next study<br/>Preregistered experiment"]

    classDef source fill:#e8eef5,stroke:#1f3a5f,stroke-width:1px,color:#12263a
    classDef code fill:#eaf0e6,stroke:#4a6b3a,stroke-width:1px,color:#22331a
    classDef data fill:#ffffff,stroke:#8a94a0,stroke-width:1px,color:#12263a
    classDef result fill:#f7f0e0,stroke:#8a6d1f,stroke-width:1px,color:#3d2f08
    classDef headline fill:#1f3a5f,stroke:#1f3a5f,stroke-width:1px,color:#ffffff
    classDef output fill:#ffffff,stroke:#1f3a5f,stroke-width:2px,color:#12263a

    class A,B source
    class C,F,H,I,J code
    class D,E,G data
    class K,L,M,N,O result
    class P headline
    class Q,R output
```

**Reading it.** Blue is source data, green is code, white with a grey outline is a frozen dataset, sand is a result, and the dashed line is the one place the analysis reaches back to the full built file — the loose-sample robustness check, which needs the 64 respondents the strict rule drops.

**Sample sizes.** 2,861 respondents in the Investor Survey → 2,797 after dropping anyone with a refusal on the 11 quiz items → 2,796 in models requiring valid G43 → 2,783 in models also requiring valid self-assessed knowledge, which is the common sample the nested predictive comparison uses so that every specification is scored on identical respondents.

**Not shown.** The validation gate inside `01_build.do` halts the run if the reconstruction drifts from FINRA's published figures; the analysis never starts if it fails. See `ANALYTICAL-DECISIONS.md` §7 and §7a.

---

*This diagram renders natively on GitHub. To use it elsewhere — slides, a poster, LinkedIn — paste the code block into [mermaid.live](https://mermaid.live) and export SVG or PNG.*
