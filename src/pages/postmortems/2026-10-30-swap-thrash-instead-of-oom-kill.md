---
layout: ../../layouts/Page.astro
title: "The machine froze instead of killing one process"
kind: Postmortem
date: "2026-10-30"
description: "Two full hangs of a shared workstation in ten hours. Memory ran out, the kernel never fired its OOM killer, and the daemon that should have was looking at the wrong cgroup."
---

| | |
|---|---|
| Date | 2026-10-29 and 2026-10-30 |
| Duration | Hang 1: 15:38, recovered in minutes by a reboot. Hang 2: 01:04 to 07:20 PDT (6 h 16 min, unresponsive overnight) |
| Impact | Both times every running job on the machine was lost, for both teams, plus all interactive sessions. Remote access was down until a manual power cycle. |
| Severity | High (whole machine, both teams) |
| Status | Resolved; memory guard on the system slice, protected services list, kill notifications |

## Summary

The machine runs two kinds of memory-hungry work at once: a model-serving process that keeps large models
resident in RAM, and batch jobs, some started by cron. On the evening of 29 October and again after
midnight they added up to more than the available RAM. A few weeks earlier swap had been enlarged to protect long jobs from being killed, and that
removed the kernel's last-resort behaviour: instead of one process dying, the machine paged for hours and stopped
answering SSH.

`systemd-oomd` was running the whole time. It was configured, by default, to manage only user sessions
(`user@.service`). It did kill things: the desktop audio daemons, which used almost no memory. The model server,
the local LLM runtime and cron jobs all live in `system.slice`, which it was not watching.

## Timeline (PDT)

| Time | Event |
|---|---|
| 10-29 15:38 | Last journal entry. Machine unresponsive. |
| 10-29 15:42 | Rebooted by hand. Cause not yet understood. |
| 10-30 01:04 | Second hang, same pattern. Nobody is awake. |
| 10-30 07:20 | Power cycled by hand. Investigation starts. |
| 10-30 morning | `journalctl -b -1 -u systemd-oomd` shows kills only in `user.slice`. `sar -r` and `sar -S` from the previous boot show RAM at 100 % and swap climbing for the last hour. The GPU queue log shows which jobs were running. Root cause found. |
| 10-30 08:49 | Fix applied (below). |

## Root cause

1. **Several large consumers at once, with no memory budget between them.** Each was fine alone.
2. **Large swap turned "kill one job" into "lose the whole machine".** With enough swap the kernel OOM killer
   does not trigger; the box thrashes instead.
3. **The userspace OOM daemon watched the wrong slice.** Its defaults protect desktop sessions, not services.

## What changed

```ini
# /etc/systemd/system/system.slice.d/50-memory-guard.conf
[Slice]
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=50%     # tasks stalled on memory >50% of the time for 20 s

# /etc/systemd/system/-.slice.d/50-memory-guard.conf
[Slice]
ManagedOOMSwap=kill                   # swap >90% used: kill the largest swap user, machine-wide
```

- **A "never kill" list** via `ManagedOOMPreference=omit`: SSH, the VPN, networking, journald, logind, D-Bus,
  the GPU queue dispatcher and its gatekeepers, the monitoring service and the alert bot. The machine may lose a job;
  it must never lose the ability to be reached and diagnosed.
- **Every kill is announced.** A small reader follows the `systemd-oomd` journal with a cursor and posts each kill
  (which unit, when) to the team chat, so a lost job is a message, not a mystery.
- **A rollback flag** (`--otkat`, Russian for "rollback") ships with the change, like every step of the machine's setup.
- Services restart on their own (`Restart=always` / `on-failure`); only the job that was running needs a rerun.

## Results after 18 days

- **0** memory hangs.
- **19** targeted kills by `systemd-oomd`. Each one cost a single job and produced a message.
- The trade-off is visible: the swap rule picks the *largest* swap user, which has been an interactive session
  and once our own job dispatcher. **Open action:** add the dispatcher to the protected list and give each team
  a fixed memory cap (`MemoryMax`) so they cannot starve each other.

## Lessons

- Swap size is a reliability decision, not a capacity one. More swap moves the failure from "a process dies" to
  "the host disappears".
- Check what your OOM daemon actually manages. Defaults are written for laptops.
- Decide in advance what must survive memory pressure (remote access, the scheduler, monitoring) and write it down
  in configuration, not in a runbook.
