---
layout: ../../layouts/Page.astro
title: Measure an AI judge like an alert
kind: Method
date: "2026-11-19"
description: An automated quality check is a classifier. Before it gates production, measure its miss rate and false-alarm rate on examples a human has labelled, the same way you would tune an alert.
---

## The problem

Teams add an AI reviewer to a pipeline ("score this output 0-100, accept at 80") and trust the number. Without
labelled data, that number is a guess. SREs already know this failure from alerting: a check that never
fires looks exactly like a check that works.

## The method

Treat the judge as an alert and measure the same two things:

| Alerting | AI judge |
|---|---|
| Missed incident | Defect accepted (miss rate) |
| False page | Good work rejected (false-alarm rate) |
| Alert tuned on past incidents | Judge calibrated on human-labelled examples |
| Alert fatigue | Reviewers ignoring a noisy judge |

1. **Collect human verdicts.** Start with 20-50 real examples the owner has judged, with a reason for each
   rejection. Keep part of them aside as a held-out set.
2. **Measure before you trust.** Run the judge on the labelled set, compute both rates, and write them down
   next to the threshold.
3. **One question per check.** A separate pass per criterion, each with a yes / no / not sure answer, instead
   of one prompt producing a total.
4. **Vetoes before points.** Some properties are pass/fail. Put them in front of the sum so strong scores on
   easy criteria cannot buy back a fatal flaw.
5. **"Not sure" goes to a human.** It is the judge's equivalent of an alert routed to a person instead of
   an automatic action.
6. **Re-measure when anything changes:** the model, the prompt, or the kind of work being judged.

## Evidence

- A frame checker calibrated against the owner's own verdicts missed 59 % of defects at first, mostly
  "meaning" errors. Adding a check of each frame against its script line brought that to 27 %, still far
  from the 10 % target. Without the labelled set, nobody would have known either number.
- A video judge passed two rejected videos at 83 and 85. Rebuilt with a veto, one question per pass and a
  control set, it scored the same videos 55 and 65, while reference videos stayed at 85-95
  ([postmortem](/postmortems/2026-11-17-quality-gate-measured-the-wrong-thing/)).

## What it costs

Human labelling time up front, and a judge that says "not sure" more often. Both are cheaper than a gate that
waves defects through with a confident number.
