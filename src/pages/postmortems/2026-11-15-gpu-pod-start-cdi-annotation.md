---
layout: ../../layouts/Page.astro
title: "Near miss: a GPU pod that could not find its own wrapper"
kind: Postmortem
date: "2026-11-15"
description: "The admission policy said yes, containerd said no such file. Pod annotations never reached the runtime."
---

| | |
|---|---|
| Date | 2026-11-15 |
| Duration | 12:27 to 13:05 PST |
| Impact | None outside the test: the smoke-test pod failed before joining the GPU queue. |
| Status | Resolved by design change (RuntimeClass `gpu-queue`, ADR-009) |

## Summary

The first live GPU pod passed admission, pulled its image and then failed to start:
`exec: "/opt/gpu-queue/turn": stat /opt/gpu-queue/turn: no such file or directory`. The design asked
containerd to inject two CDI devices named in a pod annotation; containerd never saw that annotation.

## Root cause

containerd injects CDI devices named in a container's CRI annotations or in its `CDIDevices` field.
kubelet fills `CDIDevices` from device plugins and DRA, and passes pod annotations to the pod sandbox,
not to each container. A pod annotation alone therefore never reaches containerd's CDI injection.
The design relied on a behaviour that was assumed, not checked against the code path.

## Resolution

A dedicated containerd runtime handler for RuntimeClass `gpu-queue`: it copies `cdi.k8s.io/*` pod
annotations into the OCI spec (`pod_annotations`) and runs `nvidia-container-runtime` in CDI mode,
which injects the devices. Pods of every other class keep plain runc. The admission policy now also
requires the runtime class.

Second attempt: the pod joined the shared queue as `kube-gpu`, waited 927 s behind a Blender render,
ran an fp16 matmul and released the card 2 s after exiting.

## What went well

- The risk was named before the test ("the one thing only a real run can check"), and the smoke test
  was built to fail fast and harmlessly.
- The NVIDIA toolkit package had silently enabled a service that runs `nvidia-smi` as root at boot,
  which resets the device permissions the queue relies on. Found during the fix and masked.

## Action items

| Item | Status |
|---|---|
| RuntimeClass `gpu-queue` + containerd handler (ADR-009) | Done |
| Admission policy requires the runtime class (now 10 bypass cases) | Done |
| Mask `nvidia-cdi-refresh` in the installer | Done |
| Admission cases run in CI on a kind cluster | Done (stage 6) |
