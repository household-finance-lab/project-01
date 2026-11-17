# Two Ways to Get a Zero

**Why "wrong" and "I don't know" may not mean the same thing**

Household Finance Lab · Lena Gan & Sara Kay · August 2026

---

Wrong answer: zero.

Don't know: zero.

Same score. But are they really telling us the same thing?

## The question

Two people take an 11-question investment quiz. Both get 5 right.

One gets the other six wrong.

The other says "I don't know" six times.

Same financial knowledge score. We wanted to know whether that made sense.

## What we did

We used the 2024 FINRA Investor Survey — 2,861 people who own investments and make the decisions about them. Instead of one score, we kept three piles: right, wrong, and don't know.

Then we needed something for it to matter *for*.

The same survey asks whether respondents would invest in an opportunity promising a guaranteed, risk-free 25% annual return for five years. There is no such thing. That's the point. People could answer yes, no, or don't know.

So the question became testable: among people who got the same number right, does it matter whether the rest were wrong answers or don't-knows?

Before running anything, we checked our reconstructed measures against FINRA's published numbers. They matched. Then we modeled.

## What happened

It mattered.

For people with the same number of correct answers, each additional "don't know" in place of a wrong answer came with about a **4.7 percentage-point lower probability** of accepting the implausible proposition.

Same number right. Different mix of wrong answers and don't-knows. Different answers to the investment offer.

Then we tried to make the result disappear.

We controlled for how knowledgeable people thought they were. We accounted for people's general tendency to click "don't know" elsewhere in the survey. We changed the sample rules, the demographic controls, and the shape of the outcome.

The result barely moved.

## Then Sara ruined my favorite finding

I had a great result.

We had built the models in layers — demographics first, then the number of right answers, then the number of don't-knows. Adding the don't-knows improved prediction about **four times as much** as adding the number correct.

I liked that result. I had already written the sentence.

There was one problem, and I wasn't the one who found it. A reviewer who read a draft asked whether the result depended on which variable went in first. Sara reran the models in reverse order. Four-to-one became six-to-five.

Right answers and don't-knows move together — knowing one tells you a lot about the other. So how much each one seems to add depends on what the model already knows when it goes in. Change the order, and you change what each one is measured against.

My favorite sentence was a fact about the order we typed things in.

So Sara stopped asking which variable added more when it went second, and built a comparison that gave each one the same chance.

Wrong answers won.

| What the model knows | Macro AUC |
|---|---|
| Demographics only | .620 |
| \+ how many right | .624 |
| \+ how many don't-knows | .629 |
| **\+ how many wrong** | **.639** |
| \+ right and don't-knows together | .642 |

Higher is better. A score of .50 would be no better than chance.

The number of wrong answers, all by itself, captured about 90% of what the full right/wrong/don't-know combination added over demographics. None of these models predicts especially well, so the differences are small.

That wasn't where we expected to end up.

Here's the strange part. Knowing how many questions someone got wrong told the model almost as much as knowing the full split between right answers and don't-knows. For predicting this one answer, a right answer and a "don't know" carried similar information. The count that mattered most was the wrong answers.

So, in this model and for this one judgment, "don't know" lined up much more with right answers than with wrong ones. That is a statement about prediction, not a claim that the two responses mean the same thing.

That doesn't mean "don't know" deserves credit as knowledge. A knowledge score is meant to count what people demonstrably know, and it still does that. But for this judgment, a score that only counts right answers throws away useful information: whether the rest were wrong, or "don't know."

## What we don't know

We still don't know why.

Maybe people who choose "don't know" are less willing to guess. Maybe they handle uncertainty differently. Maybe something else is going on that we didn't measure.

Our data can't tell us. Nobody was randomly assigned to say "I don't know," so this isn't a causal result.

There's also an oddity in our outcome: nearly half the sample accepted the guaranteed-return proposition. Maybe that's alarming. Maybe some respondents simply treated the guarantee as part of the hypothetical rather than as a red flag. We can't tell those apart.

We also can't say much about the people who rejected the proposition outright. Our models spot the accepters and the undecided reasonably well, and the rejecters barely at all. Whatever makes someone say "absolutely not" is mostly not in this survey.

That's why the next question needs an experiment.

## So what?

Financial knowledge scores usually ask one question:

How many did you get right?

Our results suggest there may be another question worth keeping:

What happened when you didn't know?

A wrong answer and "I don't know" may both earn zero points.

**That doesn't mean they contain zero information.**

---

**Where this goes next.** What happens if we change the opportunity to say "I don't know" in the first place? That's an experiment, and we're designing one.

**We didn't get here first.** Political scientists were asking questions about don't-know responding decades ago, and financial-literacy researchers have since examined whether wrong and DK responses should be treated alike. The repository includes the papers that shaped our thinking, what each established, and what we think remains unanswered.

**Want the machinery?** The data construction, validation checks, Stata models, Python cross-validation, robustness tests, and our analytical-decisions log are all in the GitHub repository, including the things that didn't work.

*Exploratory analysis of observational data. Not peer reviewed. The association was approximately 4.0 to 4.7 percentage points across the primary and auxiliary-measure sensitivity specifications; a separate Yes-versus-No analysis, excluding outcome "don't know" responses, produced a smaller association of approximately 2.9 points. Predictive results use repeated cross-validation on 2,783 respondents. Full methods, code, and results are in the repository.*
