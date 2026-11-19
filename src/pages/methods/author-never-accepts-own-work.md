---
layout: ../../layouts/Page.astro
title: The author never accepts their own work
kind: Method
date: "2026-11-19"
description: Separation of duties for automated pipelines and AI agents. Whoever produced a step cannot mark it done; a program or a different reviewer must, and the rule lives in code, not in a prompt.
---

## The problem

In a pipeline of automated workers, human or AI, the cheapest way to finish a step is to declare it
finished. Authors are also the worst judges of their own blind spots. Code review, four-eyes approval for
payments and change advisory boards all exist for this reason. Automated pipelines often drop it, because
"the same script that produced it can also check it."

## The method

- **State lives outside the workers.** Each unit of work has a record (a JSON "passport") with its stages,
  who submitted each one, and who accepted it.
- **Submitting and accepting are different commands.** `submit` records the author; `accept` refuses if the
  caller is that author. The rule is enforced by the program, so no prompt or convention can skip it.
- **Programs accept first.** Anything checkable by code (duration, format, loudness, resolution, schema)
  is checked by code. A reviewer only judges what code cannot.
- **A different reviewer, not just a different instance.** For AI reviewers, a second agent on the same model
  shares the author's blind spots. Anchor reviews on code, external data or human decisions
  ([what happens otherwise](/postmortems/2026-11-17-quality-gate-measured-the-wrong-thing/)).
- **A limit on rework.** After two failed reviews the step stops and goes to a human, instead of looping.

## How to check it works

- Every accepted step has an acceptor different from its author. This is a query over the records, so it
  can run as a test.
- Track how often reviews send work back. Zero returns means the reviewer is not reviewing.

## What it costs

A second actor per step and some waiting. In the pipeline this came from, the first version relied on
workers checking for their own tasks; they did not, and work sat for hours. Hand-offs had to become push
messages printed by the passport program itself.

Related: [A production line of AI agents](/projects/agent-production-line/).
