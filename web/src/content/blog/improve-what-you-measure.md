---
title: "You can only improve what you measure"
description: "A 140-year-old idea, a 20,000-person meta-analysis, and the quiet principle behind every design decision in Cronwatch."
date: "2026-05-14T10:00:00-04:00"
author: "Konrad Gnat"
tags: ["philosophy", "product", "research"]
cover: "/blog/improve-what-you-measure/cover.png"
coverAlt: "Cronwatch app icon — a quiet amber clock face on cream."
---

There is a sentence that gets pinned to office walls and quoted in every productivity podcast: *what gets measured gets managed*. It's almost always credited to Peter Drucker.

Drucker never said it.

The Drucker Institute itself debunked the attribution more than a decade ago, in a piece by Paul Zak called [*Measurement Myopia*](https://medium.com/centre-for-public-impact/what-gets-measured-gets-managed-its-wrong-and-drucker-never-said-it-fe95886d3df6). The earliest documented version of the idea traces to a 1956 paper by V.F. Ridgway in *Administrative Science Quarterly* — and Ridgway wrote it as a *warning*, not an endorsement.

The original, careful version of the idea is older still. In 1883 Lord Kelvin gave a lecture on electrical units of measurement that has been quietly carried by scientists and engineers ever since:

> When you can measure what you are speaking about, and express it in numbers, you know something about it; but when you cannot measure it, when you cannot express it in numbers, your knowledge is of a meagre and unsatisfactory kind.

That is the spirit of Cronwatch. Not a slogan. A working hypothesis: *if you can see your time, you can use it on purpose.* Without measurement, the day is a blur of impressions and good intentions. With measurement — quietly, gently, accurately — the day becomes something you can hold in your hand and adjust.

## The science is unusually clean

This is one of the rare cases where a piece of folk wisdom actually has serious empirical support behind it.

In 2016, a team of psychologists at the University of Sheffield ran a meta-analysis of **138 randomized experiments involving 19,951 participants**. The question was simple: does monitoring your progress toward a goal actually help you reach it? The answer, published in *Psychological Bulletin*, was yes — with a pooled effect size of *d = 0.40*, which in behavioral science is a real and useful effect:

> Interventions that increase the frequency of progress monitoring are likely to promote behavior change.
> — [Harkin et al. (2016)](https://pubmed.ncbi.nlm.nih.gov/26479070/)

The same meta-analysis also found that effects were *larger* when progress was physically recorded and *larger still* when it was visible to other people. The mechanism is exactly what a time tracker does: observe → record → notice → adjust.

The Sheffield result is not a one-off. Self-monitoring of behavior is one of the 93 techniques formally cataloged in Susan Michie's [Behavior Change Technique Taxonomy](https://pubmed.ncbi.nlm.nih.gov/23512568/) — the canonical reference for what actually works in behavior-change interventions. In digital health, a 2021 meta-analysis in *Obesity Reviews* found that digital self-monitoring of diet and activity produced an average weight loss of [−2.87 kg versus controls](https://onlinelibrary.wiley.com/doi/10.1111/obr.13306). The story is consistent across decades and domains: recording the thing changes the thing.

## People are terrible at guessing where their hours went

Here is the part that makes the case for a time tracker, specifically.

The U.S. Bureau of Labor Statistics runs two parallel surveys about work. The Current Population Survey *asks people to remember* how much they worked from home last week. The American Time Use Survey *gives people a diary* and asks them to record it as they go. The two methods are measuring the same population in the same year. They produce different numbers.

The recall method: about 5.6 hours of work-from-home per week.
The diary method: about [9.1 hours per week](https://www.bls.gov/opub/mlr/2025/article/a-comparison-of-hours-of-work-at-home-estimates-between-the-current-population-survey-and-the-american-time-use-survey.htm).

That's a ~60% gap, in a high-stakes federal statistic, on a behavior people are highly motivated to remember accurately. If you cannot tell yourself, with any precision, how much time you spent on work from home last week, you certainly cannot tell yourself how much time you spent in deep work versus shallow work, on the project you care about versus the one that's loud, with your kid versus on your phone next to your kid.

This is the thing measurement gives you that intuition cannot: ground truth.

## What this means for how Cronwatch is built

Almost every design choice in the app falls out of two convictions:

**1. The measurement has to be honest, or it isn't worth anything.**

A tracker that's annoying to use will not get used, and a tracker that doesn't get used will produce a fiction of your week instead of a record of it. So the bar we hold ourselves to is: *can you record an entry in the time it takes to say one sentence?* That's why Cronwatch is voice-first. You hold the mic, you talk like a person, and the app turns "I just spent forty minutes on the React refactor, then took the dog out for fifteen" into two structured entries. The friction is approximately zero. If we ever ship a feature that makes capture slower, we have failed our own thesis.

**2. AI should do the boring measurement work so you can do the interesting living work.**

The cost of self-monitoring used to be paying attention to your own behavior — a real cognitive tax. Modern speech-to-text plus a small amount of structured reasoning collapses that tax to nearly zero. Cronwatch uses AI for three things and three things only:

- Turning a sentence into a structured entry (category, duration, note).
- Filling in the gaps you didn't capture — "you had a 35-minute gap between 2:10pm and 2:45pm; was that lunch?" — and asking before assuming.
- Reading back what your week actually looked like, so you can decide what to do with that information.

We are not here to optimize you. We are not here to tell you that 4 hours of deep work is the right number, or that 90 minutes of social time is too much. The app's job is to give you a clean mirror. What you do with the reflection is the part of life we have no business touching.

## The honest caveat

There is a famous counterweight to all of this, and it would be dishonest to leave it out. It's called Goodhart's Law, and anthropologist Marilyn Strathern's [1997 formulation](https://pmc.ncbi.nlm.nih.gov/articles/PMC7901608/) is the one everyone repeats:

> When a measure becomes a target, it ceases to be a good measure.

This is true. The moment "hours of deep work" becomes a number you're trying to maximize, you will start gaming it — coding for forty straight minutes with no real thought in it, just to log the block. Donald Campbell warned about [exactly this dynamic](https://psychsafety.com/goodharts-law-campbells-law-and-the-cobra-effect/) in social statistics, and it ruined a generation of school accountability metrics.

The way out of the Goodhart trap is not to stop measuring. It's to be very careful what role the measurement plays. Cronwatch deliberately does not have a daily score, a streak, or a "productivity number." It has time spent and the categories you chose to put time into. The metric is the thing itself — not a proxy for it. We'd rather show you that you spent six hours in meetings on Tuesday than tell you whether that was good or bad. You already know.

## Why we keep coming back to this

Drucker, who didn't say the famous sentence, [did say a less famous one](https://www.druckersociety.at/files/Hesselbein-Druckerontheprofession.pdf): *the most important things in an organization — relationships, trust, the development of community — are precisely the things metrics miss.* He's right. There are parts of a life that should never be tracked. A long lunch with a friend, the half-hour you sat on the steps and watched the light change, the conversation that went somewhere you didn't expect.

But the parts that *can* be measured — the hours that quietly get away from you, the projects that never quite get the time you swore they would, the meetings that always run twenty minutes long — those parts respond to attention. A 140-year-old physicist had it right. So did 19,951 people in a meta-analysis. So, we think, will you, when you can finally see where your day actually went.

That's the whole pitch. We're building a quiet mirror. We hope it helps.

---

**References**

1. Harkin, B., Webb, T. L., Chang, B. P. I., Prestwich, A., Conner, M., Kellar, I., Benn, Y., & Sheeran, P. (2016). Does monitoring goal progress promote goal attainment? A meta-analysis of the experimental evidence. *Psychological Bulletin*, 142(2), 198–229. [pubmed.ncbi.nlm.nih.gov/26479070](https://pubmed.ncbi.nlm.nih.gov/26479070/)
2. Michie, S., et al. (2013). The Behavior Change Technique Taxonomy (v1) of 93 Hierarchically Clustered Techniques. *Annals of Behavioral Medicine*. [pubmed.ncbi.nlm.nih.gov/23512568](https://pubmed.ncbi.nlm.nih.gov/23512568/)
3. Berry, R., et al. (2021). Effectiveness of digital self-monitoring of weight, dietary intake, and physical activity for weight loss: a systematic review and meta-analysis. *Obesity Reviews*. [onlinelibrary.wiley.com/doi/10.1111/obr.13306](https://onlinelibrary.wiley.com/doi/10.1111/obr.13306)
4. McCambridge, J., Witton, J., & Elbourne, D. R. (2014). Systematic review of the Hawthorne effect. *Journal of Clinical Epidemiology*. [pmc.ncbi.nlm.nih.gov/articles/PMC3969247](https://pmc.ncbi.nlm.nih.gov/articles/PMC3969247/)
5. Locke, E. A., & Latham, G. P. (2002). Building a practically useful theory of goal setting and task motivation. *American Psychologist*. [med.stanford.edu — PDF](https://med.stanford.edu/content/dam/sm/s-spire/documents/PD.locke-and-latham-retrospective_Paper.pdf)
6. U.S. Bureau of Labor Statistics. (2025). A comparison of hours of work at home estimates between the CPS and the ATUS. *Monthly Labor Review*. [bls.gov/opub/mlr/2025](https://www.bls.gov/opub/mlr/2025/article/a-comparison-of-hours-of-work-at-home-estimates-between-the-current-population-survey-and-the-american-time-use-survey.htm)
7. Zak, P. (2013). Measurement Myopia. *The Drucker Institute*. [medium.com — archived](https://medium.com/centre-for-public-impact/what-gets-measured-gets-managed-its-wrong-and-drucker-never-said-it-fe95886d3df6)
8. Manheim, D., & Garrabrant, S. (2018). Categorizing Variants of Goodhart's Law. [pmc.ncbi.nlm.nih.gov — applications survey](https://pmc.ncbi.nlm.nih.gov/articles/PMC7901608/)
