---
layout: ../../layouts/Page.astro
title: How do you share one expensive GPU between two teams?
kind: Note
date: "2026-11-16"
description: Companies solve this with Kueue, Run:ai or MIG. I had a smaller version of the same problem.
image: /img/gpu-platform-overview.png
---

Companies solve this with Kueue, Run:ai or MIG on H100s. I had a smaller version of the same problem:
one workstation, one consumer GPU, production work already running on it around the clock. So I built a
Kubernetes platform that had to fit around that work instead of replacing it.

![One GPU, two teams and a Kubernetes cluster, one fair queue](/img/gpu-platform-overview.png)

What it does:

- GPU pods wait in the same queue as the other teams' jobs. An admission policy rejects any pod that tries to skip it.
- Quotas and limits per team, and the cluster steps back first when production work needs the memory.
- Argo CD, Terraform, Prometheus with alerts, CI with Trivy scanning.
- 13 written decisions, 3 postmortems, and a table that maps every piece to its EKS equivalent
  (GPU Operator, Kueue, Karpenter, DCGM).

More: [the project page](/projects/gpu-platform/) and [the method behind the queue](/methods/shared-gpu-queue/).
