---
layout: ../../layouts/Page.astro
title: "A production line of AI agents on one machine"
kind: Case study
date: "2026-11-18"
description: "About fifteen AI agents with roles, quality gates and a dispatcher, sharing one GPU. What held up, what failed, and how it compares with what Anthropic and recent research recommend."
---

This is a case study of a system I helped run in late 2026: a small "company" of AI agents that produces
short videos and other media on a single workstation with one GPU. I write it up as a reliability problem,
because that is what it turned out to be. The interesting parts are not the prompts. They are queues,
state, gates, timeouts, alerts and postmortems, the same things that keep any production system honest.

Names of products and channels are left out on purpose. The engineering is the point.

## The shape of the system

```
topic ─► script ─► voice ─► launch vote ─► storyboard ─► frames ─► video ─► cover ─► publish
  │        │         │           │              │           │         │        │         │
  └──── each stage: one author agent, a DIFFERENT agent or a program accepts it ────────────┘
                     state lives in one JSON "passport" per video, not in any agent's memory
```

- **Roles.** About fifteen long-lived agents, each with a role: scout, scriptwriter, director, sound,
  quality control, designer, publisher and so on.
- **A passport per video.** A command-line program owns the stage machine. Agents call it to hand in work
  (`sdat`), to score someone else's work (`ocenka`) or to return it (`vernut`). It refuses self-grading.
- **Gates.** Each stage has an acceptance check: a program (duration, loudness, resolution, silence
  longer than 0.8 s) or a scoring agent with a threshold of 80 out of 100.
- **A publication lock.** Nothing can be uploaded without a complete card, an accepted cover and the owner's
  explicit yes.
- **A dispatcher.** A scheduled agent wakes whoever owns the next step. After three wake-ups without
  progress it sends one message to the human instead of nagging forever.
- **One GPU, one queue.** Every GPU job, from any agent, goes through the same fair queue as everything else
  on the machine (see [gpu-platform](/projects/gpu-platform/)).
- **Shared memory.** A journal of experiments (327 entries of "what we tried and how it ended", searched
  before every new attempt), a resource library of about 1,100 reusable assets with licences, and a
  shared lessons file every agent reads before work.

## What held up

| Practice | Why it worked |
|---|---|
| State in a file, order in code | Agents forget between sessions. A JSON passport and a stage machine do not. Any agent can pick up any video cold. |
| Author never accepts their own work | Cheap separation of duties. It caught rework that the author would have waved through. |
| Programs before models | Duration, loudness, resolution and silence checks are deterministic and never argue. |
| Lock plus a human yes before anything public | Nothing reached the public that the owner had not seen. |
| One launcher for background jobs, with a time limit | After a [runaway ffmpeg](/postmortems/2026-11-05-ffmpeg-wrote-for-2-5-days/) wrote 137 GB, `fon` made every job expire. |
| A GPU queue every agent must use | Agents never fought over the card; the queue decided. |
| Escalate after N attempts | Three wake-ups, then one message to a human. No infinite nagging. |

## What failed

**The quality gate measured the wrong thing.** Two finished videos scored 83 and 85 and were rejected by the
owner on sight. Production stopped. Full write-up:
[The quality gate passed 83 and 85](/postmortems/2026-11-17-quality-gate-measured-the-wrong-thing/).

**The automated frame checker missed too much.** The quality-control agent was calibrated against frames the
owner had judged by hand. On the first set it missed 17.6 % of defects with 15 % false alarms. Counting only
the owner's own labels the miss rate was much worse, 59 %, mostly "meaning" errors such as an object that
contradicts the script. Adding a check of the frame against the script line brought it down to 27 %. Still
far from the target of under 10 %. Finger counts and an extra body in a crowded frame were not caught by any
vision model tried, including a larger one with reasoning enabled.

**Pull-based coordination stalled.** The first design asked agents to check for their own tasks. They do not
wake up on their own: two videos waited more than four hours at one stage. The fix was push: every hand-off
prints the exact one-line message for the next agent, and the dispatcher delivers it.

**Rework loops cannot fix a tool ceiling.** When the image tools could not reach the required look, the
pipeline kept returning work for another round. More rounds did not help. Now two failed rounds stop the stage.

**Too many long-lived roles for a sequential chain.** Each stage depends on the previous one, yet every role
was a separate long-running agent with its own context, waking the next one up. It worked, but it was slow,
hard to follow, and expensive in tokens.

## Checked against the research

After the gate failed I read what the people who build these systems recommend, and compared.

| Recommendation | Source | Here |
|---|---|---|
| Start with the simplest thing; use fixed code paths where the steps are known | Anthropic, *Building effective agents* | Opposite: a known sequence was run by agents messaging each other |
| Split work by task under one lead that keeps the whole picture, not by job title | Anthropic, *multi-agent research system* | Opposite: split by job title |
| Multi-agent setups do badly when steps depend on each other and need shared context | Anthropic; Cognition, *Don't build multi-agents* | This chain is exactly that |
| Keep state in files and git, never in the model's memory | Anthropic, *harnesses for long-running agents* | Matches: the passport |
| Calibrate an AI judge against human labels; one judge per criterion; allow "unknown" | Anthropic, *Demystifying evals for AI agents* | Was missing; now added |
| A supervisor agent on the same model shares the worker's blind spots | Anthropic, *Project Vend, phase two* | Matches the gate failure exactly |
| Many failures are in verification; a checker agent can give false confidence | Cemri et al., *Why do multi-agent LLM systems fail?* (2025) | Matches |

The honest summary: the reliability engineering (state, gates, queue, limits, escalation, postmortems) was
sound. The organisational design, an org chart of agents, was the part the research warns against.

## What changed

- A rebuilt quality scale: a picture-level criterion with a veto, one question per pass, a `?` answer that
  goes to a human, and a control set of known-bad and known-good examples. Known-bad videos dropped from
  83/85 to 55/65; reference videos stayed at 85–95.
- A limit of two rework rounds per stage.
- New topics need external demand numbers, not only a vote of agents that share one model.
- The dispatcher runs hourly instead of every 20 minutes and cleans up after itself.
- Production stays paused until the owner approves the new gate.

## Next

1. One approved style frame per series before any heavy GPU work: the human look moves to where it is cheapest.
2. 40–60 owner verdicts with reasons as the judge's ground truth, with a held-out part and a second judge
   from another model vendor.
3. Replace long-lived role agents with short agents launched by the passport for one step each; roles
   become reusable instructions instead of standing processes.
4. Event-driven hand-offs instead of a timer, and cost per accepted video as the main metric.

## Takeaways for platform work

- An agent system is a distributed system with unreliable workers. Give it the same things you would give
  any fleet: a scheduler, idempotent hand-offs, time limits, dead-letter escalation and metrics.
- Treat every automated judge as a classifier with a measured error rate. Without labelled data it is a guess
  with a number on it.
- Put the human where a look is cheapest and the blast radius is smallest: before the expensive work, not after.
