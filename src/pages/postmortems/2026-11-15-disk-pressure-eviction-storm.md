---
layout: ../../layouts/Page.astro
title: "209 pods evicted, zero alerts: a disk-pressure eviction storm"
kind: Postmortem
date: "2026-11-15"
description: "A percentage default on a large shared disk evicted every pod three times in one evening, and monitoring went down with them."
image: /img/eviction-storm.png
---

| | |
|---|---|
| Date | 2026-11-15 |
| Duration | 16:27 to 22:04 PST (5 h 37 min of `DiskPressure`), found at 22:09, fixed at 23:11 |
| Impact | 209 pods evicted, mostly Argo CD (178) and monitoring (29). Argo CD and Prometheus restarted repeatedly, so syncs were delayed and metrics have gaps. No impact on the studio, the GPU queue or remote access. |
| Severity | Medium for the platform, none for its users |
| Status | Resolved; new alerts added |

## Summary

![Free disk space vs the eviction threshold during the incident](/img/eviction-storm.png)


kubelet evicted every pod on the node, in three waves, because the root filesystem had less free space
than `nodefs.available: 5%`. On a large disk 5 % is far more than the pods need, and the studio keeps the disk
just above 5 % free, so the node sat right on the threshold. The pods came back each time, got evicted
again, and nobody was told: there was no alert for node pressure or evictions.

## Timeline (PST)

| Time | Event |
|---|---|
| 15.11 16:27 | Free space on `/` drops under 5 %. Node condition `DiskPressure=True`; kubelet taints the node and starts evicting. |
| 16:00-17:00 | First wave: 169 pods evicted and recreated in one hour. |
| 17:00-18:00 | Second wave: 4 pods. |
| 21:00-22:00 | Third wave: 35 pods. |
| 22:04 | Free space rises back over the threshold; `DiskPressure=False`. |
| 22:09 | While adopting Argo CD into Terraform, `kubectl get pods -n argocd` shows hundreds of `Evicted` pods. |
| 22:12 | Every evicted pod has the same message: `The node was low on resource: ephemeral-storage. Threshold quantity: <5 % of the disk>`. Memory is ruled out: available RAM stayed well above the eviction line. |
| 22:20 | Threshold changed to an absolute floor in the installer; 209 failed pods deleted. |
| 23:11 | Operator reruns the always-on installer; live kubelet config shows `nodefs.available: 20Gi`. |

## Root cause

The kubelet configuration used a relative disk threshold that made sense for small nodes, not for a
large disk shared with a studio that stores renders and models on it. Pods on this node need a few
GiB; 5 % of a large disk was never about them.

## Contributing factors

- The studio keeps the disk nearly full; free space moved just above and below 5 % that day.
- The stage 1 installer copied the common `5%` default without checking it against the disk size.
- The alert rules covered host disk, memory, the GPU and Argo CD, but not kubelet's own view: node
  pressure conditions and evictions.

## Detection

By accident, about 5 h 40 min after it started. The `ArgoAppNotHealthy` alert did not fire because
the applications recovered between waves.

## What went well

- The always-on design held: evictions only touched the cluster, never the studio.
- Argo CD and the controllers recreated everything by themselves after each wave.
- Prometheus history was enough to rebuild the exact timeline afterwards.

## What went badly

- Five and a half hours without a signal.
- The first guess was memory, because memory eviction had been tuned the day before. The eviction
  message said otherwise; reading it first would have saved a few minutes.

## Action items

| Item | Status |
|---|---|
| Absolute disk thresholds: `nodefs.available` and `imagefs.available` as absolute values (ADR-011) | Done |
| Alert `KubeNodeUnderPressure`: any node pressure condition for 5 min | Done |
| Alert `PodsEvicted`: more than 3 evicted pods present | Done |
| Disk cleanup on the studio side (renders, model caches) | Open, owned by the studio |
