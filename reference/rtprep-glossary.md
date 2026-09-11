# Terms used in rtprep

The vocabulary the rest of the documentation assumes, defined once.

## Response times and what contaminates them

- Contaminant:

  A trial not produced by the decision process the experiment is about:
  a response made before the stimulus was read, one delayed by something
  outside the task, one made without using the evidence. The word is
  used for the *trial*, not for the statistical criterion that might
  catch it; "outlier" is kept for the criterion and for literature that
  uses it that way. `rtprep` names three processes, and
  [`r_contaminated()`](https://www.gfrischkorn.org/rtprep/reference/r_contaminated.md)
  generates each: **leading-edge anticipations**, **delayed start-ups**,
  and **informationless responses**.

- Leading edge:

  The fast rising flank of a response time distribution, the short climb
  from the fastest response to the mode. It matters because a
  right-skewed distribution has almost no mass there, so a trial that
  arrives early sits well inside a criterion built around the mean and
  is not removed by one.

## What the package does to them

- Screening:

  Classifying trials, deciding which came from the decision process.
  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
  screens.

- Trimming:

  Screening that then removes what it flagged. Every trimming rule
  screens; not every screening rule trims, since a probability can be
  carried forward as a weight instead.

- Aggregation:

  Turning the surviving trials into summary statistics.
  [`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md)
  aggregates. Kept separate from the two above because a screen and a
  summary fail in different ways, and the choice between them is a real
  one.

## The model the summaries feed

- Evidence accumulation model (EAM):

  A model of choice and response time in which a decision is made by
  gathering evidence over time until enough has arrived to commit. The
  **diffusion model (DDM)** is one member, a racing accumulator another.

- Drift:

  How fast evidence arrives, on average; the rate of the accumulation.
  Higher drift means faster and more accurate responding.

- Bound:

  How much evidence is required before committing, also called boundary
  separation. A wider bound means slower and more accurate responding,
  which is where speed-accuracy trade-offs live.

- Non-decision time (ndt):

  Everything in a response time that is not evidence accumulation:
  encoding the stimulus at one end, executing the movement at the other.

- EZ-diffusion:

  A closed-form inversion from the mean response time, its variance, and
  accuracy to drift, bound and ndt, so no fitting is needed.
  [`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md)
  produces the three inputs and
  [`ez_ddm()`](https://www.gfrischkorn.org/rtprep/reference/ez_ddm.md)
  does the inversion.

## See also

[rtprep-package](https://www.gfrischkorn.org/rtprep/reference/rtprep-package.md)
for what the package is for.
