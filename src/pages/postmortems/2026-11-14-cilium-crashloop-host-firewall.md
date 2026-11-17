---
layout: ../../layouts/Page.astro
title: "Cilium crash loop: the host firewall dropped Service traffic"
kind: Postmortem
date: "2026-11-14"
description: "A healthy control plane, a CNI that never became ready, and a firewall rule written long before Kubernetes arrived."
---

| | |
|---|---|
| Date | 2026-11-14 |
| Duration | 10:15 to 13:25 PST (first install to confirmed working cluster) |
| Impact | Cluster not usable for ~3 h during its first install. No impact on the studio or on remote access. |
| Severity | Low (new system, not yet serving anything) |
| Status | Resolved; fix is part of the installer (ADR-007) |

## Summary

The second install attempt brought up a healthy kubeadm control plane, but Cilium never became ready:
its agent and operator crash-looped with `dial tcp 10.96.0.1:443: i/o timeout`. Without the CNI the
node stayed `NotReady` and CoreDNS stayed `Pending`. The cause was the host's own firewall: a rule that
keeps the workstation from reaching devices on the home network also dropped the node's traffic to
its own API server once kube-proxy rewrote the Service address.

## Timeline (PST)

| Time | Event |
|---|---|
| 10:10 | First install fails in `apt-get` on an unrelated broken NVIDIA kernel-module package; rolled back. Installer now refuses to start on a dirty package database. |
| 10:15 | Second install starts. kubeadm init succeeds; control plane `Running`. |
| 10:16 | Helm installs Cilium 1.20.4 and waits for it. |
| 10:26 | `helm --wait` times out after 10 min. Installer stops; the 45-min auto-rollback timer stays armed. |
| 10:28 | Cilium logs: `Unable to contact k8s api-server ... 10.96.0.1:443: i/o timeout`. |
| 10:30 | Host curl to `https://10.96.0.1` also times out, while `https://<node-ip>:6443` answers. The problem is the Service path, not the API server. |
| 10:31 | kube-proxy's NAT rules are correct: `10.96.0.1:443 -> <node-ip>:6443`. |
| 10:32 | Packet counters before and after one request: `ufw-user-output -d 192.168.0.0/16 -o eno1 -j DROP` grows by 3 (the SYN and two retries). Root cause found. |
| 10:34 | Installer gets tagged firewall exceptions; ADR-007 written. |
| 11:00 | Dead man's switch rolls the half-installed cluster back on its own. |
| 13:13 | Operator reruns rollback + install. |
| 13:16 | Node `Ready`, 10 system pods running, DNS smoke test passes. |
| 13:25 | Operator confirms over SSH; auto-rollback cancelled. |

## Root cause

The host firewall (ufw) forbids outbound traffic to private ranges on the LAN interface, so the
workstation cannot reach home devices. A process on the node that connects to the Service IP
`10.96.0.1` gets a route lookup first: `10.96.0.1` is not local, so the route is via the gateway on
`eno1`. kube-proxy's DNAT then rewrites the destination to the node's own address `<node-ip>:6443`,
and the filter table sees "output on `eno1` to `192.168.0.0/16`", which matches the DROP rule.

The control plane itself was unaffected because its components talk to `127.0.0.1` or `<node-ip>`
directly, with no Service IP and no rewrite. Cilium is the first component that uses the Service.

## Detection

Manual: `helm --wait` timed out and the installer printed where to look. Diagnosis took about 15
minutes; the decisive evidence was the iptables packet counter on the DROP rule.

## Resolution

Narrow exceptions, tagged `gpu-platform` so the rollback removes exactly these:
node to itself and to the Service and pod ranges on the LAN port, pods to the host, pods to the
internet. Explicit denies keep pods away from the home LAN, `172.16/12` and the tailnet. Verified
later from a pod: internet reachable, the home router and Argo CD blocked.

## What went well

- The dead man's switch did its job twice: a broken install never stayed on the remote host.
- Comparing packet counters before and after a single request turned a guess into proof in minutes.

## What went badly

- The host firewall was not part of the preflight; the installer assumed default networking.
- `--confirm` after a failed install printed "no pending auto-rollback" because it only looked at the
  post-install timer. Fixed: it now reports an unfinished install.

## Action items

| Item | Status |
|---|---|
| Tagged ufw exceptions in the installer, removed by `--rollback` (ADR-007) | Done |
| Installer refuses to start on a dirty dpkg database | Done |
| `--confirm` reports an unfinished install | Done |
| Network policy test from a pod (internet yes, LAN no) | Done |
