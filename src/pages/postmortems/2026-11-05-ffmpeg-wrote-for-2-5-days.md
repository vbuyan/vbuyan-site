---
layout: ../../layouts/Page.astro
title: "One ffmpeg, 2.5 days, 137 GB: the job that never ended"
kind: Postmortem
date: "2026-11-05"
description: "An infinite input, a killed parent, an orphaned child and a relaunch. Four ordinary steps that added up to a runaway process nobody noticed for 60 hours."
---

| | |
|---|---|
| Date | 2026-11-03 to 2026-11-05 |
| Duration | ~60 h of runaway writing; found and stopped 2026-11-05 |
| Impact | One output file grew to 137 GB on the shared disk; two processes held ~2.5 CPU cores the whole time. No data lost. |
| Severity | Medium (disk headroom on a shared machine is everybody's problem) |
| Status | Resolved; launcher `fon` and process beacons added |

## Summary

A video assembly script built each clip with ffmpeg, mixing in a silent audio track from
`-f lavfi anullsrc`. Without a `d=` duration that source is infinite, and `-shortest` did not stop
the encode. The job looked stuck, so the parent Python script was killed, but its ffmpeg had been started in its own
session and kept running as an orphan. The job was then launched again, producing a second endless
ffmpeg writing to the same file. Nothing on the machine was watching for this, so it ran for two and a half days.

The script was being driven by an AI coding agent, and every step it took was a reasonable step on its own.
That is the interesting part: no single mistake, just a missing guardrail at each layer.

## Timeline (PST)

| Time | Event |
|---|---|
| 11-03 | Assembly job started in the background with `setsid nohup python3 assemble.py`. The ffmpeg for one clip never finishes. |
| 11-03 | The job is judged hung. The Python parent is killed; ffmpeg is not. It is re-parented to PID 1 and keeps writing. |
| 11-03 | The job is relaunched without checking for the old process. A second ffmpeg starts on the same output. |
| 11-03 to 11-04 | Memory and swap run near full on the machine; the out-of-memory daemon kills six unrelated processes. Correlation with the runaway was suspected, not proven. |
| 11-04 | The duration bug is fixed in the script (`anullsrc=...:d=SECONDS`). The two running processes are not noticed. |
| 11-05 | A disk cleanup finds a 137 GB `.mov` in `/tmp` that is still growing. Both ffmpeg processes stopped, space reclaimed. |
| 11-05 evening | `fon` launcher, process beacons and a daily `/tmp` cleanup deployed. |

## Root cause, in layers

1. **Infinite input.** `anullsrc` without `d=`, `-loop 1` without `-t`, and `-stream_loop -1` are all endless sources.
   `-shortest` is not a reliable stop for them.
2. **Wrong unit of control.** Killing a parent does not kill its children when they are in another process group.
   The thing to stop is the group, not the PID.
3. **No idempotency on relaunch.** Nothing prevented a second copy of the same job with the same output.
4. **No detection.** There was no alert for orphans, long-running encoders, or a single file growing past a sane size.

## What changed

**One way to run background jobs.** A small launcher, `fon`, is now the only allowed way to run long jobs on the machine:

```bash
fon start NAME [-h HOURS] COMMAND...   # own process group, hard time limit (default 6 h), log ~/fon/NAME.log
fon stop  NAME                         # TERM, then KILL, the whole group: script, ffmpeg, blender
fon status                             # what is running, for how long, last log line
fon zhdat NAME [-m MINUTES]            # bounded wait ("zhdat" is Russian for "wait"), then the tail of the log
```

Design choices worth noting:

- **The watchdog lives inside the group.** GNU `timeout` was rejected because it moves the command into its own
  process group, where `fon stop` could no longer reach it. Instead a sleeper inside the same group sends TERM to the
  whole group at the deadline, then KILL 60 s later.
- **The same name cannot run twice.** A second `fon start` on a live job is refused with how long the first one has
  been running. Relaunching now forces a decision instead of happening by accident.
- **Every exit is recorded.** The last log line is always `FON_KONEC code N` ("konec" means "end"); code 124 means the time limit fired.
- **Background polling loops are banned** (`until ...; do sleep; done` and similar), because they are the same failure
  in a smaller form: seven of them were found waiting 1 to 3 days for a log line that would never appear.

**Beacons.** A cron job every 5 minutes reports to the team chat: orphaned encoders or renderers, processes running
far longer than usual, any file over 30 GB that is still growing, and background waiters older than 12 h.
One message per problem, a reminder every 12 h, and a single "fixed" message when it clears.

**Rules for ffmpeg.** Every infinite input gets an explicit duration. This went into the shared lessons file that
every agent reads before starting work.

## Results after 12 days

- **1,176** background jobs launched through `fon`; **16** were stopped by their time limit instead of running on.
- **0** orphaned or endless encoders reported by the beacons. The one "growing huge file" alert was a legitimate
  34 GB download; it cleared itself 35 minutes later.

## Lessons

- A process tree is not a unit of work. A process group (or a cgroup) is.
- "Every job has an expiry date" is cheaper than any amount of debugging after the fact.
- Guardrails belong in the tool, not in the instructions. The agent had the right advice in its notes;
  what fixed the problem was a launcher that makes the wrong thing hard to do.
