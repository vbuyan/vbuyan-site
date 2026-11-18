---
layout: ../../layouts/Page.astro
title: "The quality gate passed 83 and 85. The owner said: not even close."
kind: Postmortem
date: "2026-11-17"
description: "An AI judge scored two finished videos above the acceptance threshold. A human looked once and stopped production. The gate was measuring the wrong thing, and it was calibrated on the very cases it was supposed to catch."
---

| | |
|---|---|
| Date | 2026-11-17 |
| Impact | Two finished videos accepted by every automated gate were rejected by the owner on sight. Production stopped for all new work. Nothing was published. |
| Severity | High for the pipeline (its main safety check was not working), none for the public |
| Status | Gate rebuilt and validated on a control set; production stays paused until the owner lifts it |

## Context

A pipeline of AI agents produces short videos. Each video moves through nine stages, from topic to publication.
Every stage has an owner, and a different agent accepts it: the author never accepts their own work. The
final cut is scored by an AI judge on a 100-point scale with nine criteria. A score of 80 or more is accepted
automatically. The owner was meant to be involved only at the very end.

## What happened

Two videos went through every stage and scored **83** and **85**. The owner watched them and rejected both
outright: the picture looked like a cheap game, people looked like mannequins, water looked like a cartoon,
and the last seconds repeated nearly identical shots. Production was paused the same day with a lock file
that the stage machine checks before handing out any new task.

## Root cause

1. **The scale did not have the criterion that mattered.** Nine criteria covered the hook, pacing, the match
   between narration and picture, sound and length. "Visual quality" was one criterion worth 10 points, and
   it was being scored by brightness and readability, not by materials, people or overall level. A video
   could be ugly and still collect 80+ points from everything else.
2. **A sum hides a veto.** A 0-100 total lets strong scores on easy criteria buy back a fatal flaw. Some
   defects are not "minus 10", they are "no".
3. **The judge shared the producer's blind spots.** The judge was the same model family as the agents that
   made the frames. What looked fine to one looked fine to the other.
4. **The scale was tuned on the cases it should have caught.** It was checked against a handful of the
   pipeline's own videos, with their view counts known in advance. There was no held-out set and no
   human verdicts to compare with.
5. **The human checkpoint had been removed.** To save the owner's time, the only human look was at the very
   end, after hours of GPU work. A one-minute look at a single frame on day one would have stopped it.

## What changed

- **Picture level first, with a stop.** The new scale opens with "picture level compared with the best
  videos in the genre", worth 20 points. If it scores zero, the total is capped at 79, so the video cannot
  pass however good the rest is.
- **One question per pass.** Each criterion is judged in its own call with one question, not one prompt for
  everything.
- **"Not sure" is an answer.** The judge can return `?`, and a `?` is never auto-accepted; it goes to a human.
- **A control set.** The two rejected videos are now the "must fail" examples, and three strong videos from
  the genre are the "must pass" ones. Result of the new scale:

  | | Old scale | New scale |
  |---|---|---|
  | Rejected videos | 83, 85 | **55, 65** |
  | Strong reference videos | 92–95 | 85–95 |

- **A limit on rework.** Two scores under 80 in a row stop the stage and call a human, instead of looping
  forever on a problem that more rework cannot fix.
- **Videos accepted under the old scale are re-scored** before anything is published.

## What did not work

Code-only checks were tried first. Frame-to-frame motion and similarity (SSIM) did not separate "game-like"
from "good": the repeated end shots scored 0.6–0.7, the same as the reference videos. Some judgments still
need a model, and the model needs a human-labelled reference.

## Lessons

- A quality gate is a classifier. Measure it like one: on labelled examples it has not seen, with a
  known miss rate, before trusting it with production.
- Put vetoes in front of points. Some properties are pass/fail, and a weighted sum will quietly trade them away.
- An AI checker of the same model family is not an independent check. Anchor it on code, external data,
  or human decisions.
- Move the human look to where it is cheapest. One approved style frame at the start costs a minute;
  a rejected finished video costs a day.
