---
layout: ../../layouts/Page.astro
title: Every background job has an expiry date
kind: Method
date: "2026-11-19"
description: Run every background job in its own process group with a hard time limit, stop the group as a unit, and refuse to start a second copy. Runaways become impossible instead of merely unlikely.
---

## The problem

Long-running background work (encoders, renders, training, batch scripts) fails in quiet ways. A source
that never ends, a parent killed while its children keep running, a relaunch on top of the old run. None of
these crash. They just keep going, burning CPU and disk, until someone notices. On one shared machine an
`ffmpeg` process wrote a single file for 2.5 days and reached 137 GB
([postmortem](/postmortems/2026-11-05-ffmpeg-wrote-for-2-5-days/)).

## The method

Every background job gets four properties, enforced by the launcher, not by the person starting it:

1. **Its own process group.** The job and everything it spawns share one group ID.
2. **A hard deadline.** A watchdog inside the same group sends `TERM` to the whole group at the limit, then
   `KILL` a minute later. The default is generous (hours), but it is never infinite.
3. **Stop means the group.** `stop NAME` signals the group, not a PID, so children cannot outlive the parent.
4. **One copy per name.** Starting a job whose name is already running is refused, with how long the first
   one has been running. A relaunch becomes a decision, not an accident.

```bash
fon start encode-ep12 -h 3 python3 assemble.py ep12   # group, 3 h limit, log in ~/fon/encode-ep12.log
fon status                                           # what runs, for how long, last log line
fon stop  encode-ep12                                # the whole group: script, ffmpeg, everything
```

The last log line is always the exit code, so "did it finish, fail, or hit the limit" is one `tail` away.

## Why not `timeout`, `nohup` or systemd?

- `timeout` puts the command in a new process group, so a later group-wide stop no longer reaches it.
- `nohup ... &` and `setsid` detach the job but give it no deadline and no owner.
- A systemd transient unit (`systemd-run --scope` with `RuntimeMaxSec`) is a fine alternative where you have
  the rights; the point is the four properties, not the tool.

## How to check it works

- Count jobs stopped by their limit. They are the runaways you did not have. On the machine above: 1,176
  jobs in 12 days, 16 stopped by the deadline, zero runaway processes reported afterwards.
- Alert on what still slips through: processes whose parent is PID 1, and any single file over a size
  threshold that is still growing.

## What it costs

A wrapper on every command, and occasionally a legitimate job hitting its limit. That is the right failure:
loud, early, and fixed by raising one number.
