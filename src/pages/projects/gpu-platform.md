---
layout: ../../layouts/Page.astro
title: gpu-platform
kind: Project · 2026
description: A Kubernetes platform built next to production work on one workstation. One GPU, two teams and a cluster share a single fair queue, and nothing is allowed to slow production down.
image: /img/gpu-platform-overview.png
---

**Code and write-ups:** [github.com/vbuyan/gpu-platform](https://github.com/vbuyan/gpu-platform)

![One GPU, two teams and a Kubernetes cluster, one fair queue](/img/gpu-platform-overview.png)

## The problem

Companies share expensive GPUs between teams with Kueue, Run:ai or MIG slices on data-center cards. I had a
smaller version of the same problem: one workstation with one consumer GPU, two teams already using it
around the clock through a host-level queue, and a request to add a Kubernetes platform on top without
slowing anyone down and without ever going around the queue.

## What I built

- **A full kubeadm cluster on a shared, remote host.** Kubernetes, containerd and Cilium. The whole cluster
  lives in one memory-capped cgroup, runs all the time, and is the first thing to give memory back
  under pressure. Every install arms a dead man's switch: a broken install rolls itself back.
- **GPU pods take turns in the existing queue instead of using a device plugin.** A pod joins the same
  dispatcher the teams use, as its own participant. In a live test it waited behind a 3D render,
  ran a benchmark at the card's full speed and handed the card on two seconds after exiting.
- **An admission policy that makes bypassing the queue impossible.** A CEL ValidatingAdmissionPolicy (no
  webhook) rejects any GPU pod that is not wrapped in the queue client. Ten bypass attempts are tested in CI.
- **GitOps end to end.** Argo CD (app of apps) applies everything from Git and upgrades itself. Terraform
  covers the two things Argo CD cannot: its own bootstrap and the GitHub repository with branch protection.
- **Monitoring that respects the GPU.** Prometheus, Grafana and Alertmanager with alerts tuned to this
  host's history. GPU and queue metrics come from what the queue already publishes, never from NVML,
  so monitoring can never hold the card.
- **CI that has caught real problems:** a vulnerable base image (Trivy), shell bugs in code that already
  ran in production, and every chart validated as rendered.
- **A nightly GPU workload:** a CronJob that subtitles new videos with Whisper, through the same queue.

## How it maps to production

| Here | On a managed cloud cluster |
|---|---|
| kubeadm on one node | EKS / GKE managed control plane, node groups |
| GPU via CDI + RuntimeClass, no device plugin | NVIDIA GPU Operator, `nvidia.com/gpu` resource |
| Shared host queue | Kueue, Volcano or Run:ai |
| Whole card per job | MIG slices or time-slicing |
| CEL ValidatingAdmissionPolicy | Same, or Kyverno / OPA Gatekeeper |
| One memory-capped cgroup, eviction, oomd | Dedicated GPU node pools, taints, Karpenter |
| Textfile exporter from queue state | DCGM exporter, Kueue metrics |
| Terraform state in a Kubernetes Secret | S3 backend with locking |
| Images on GHCR, scanned by Trivy | ECR scan on push, same Trivy gate |

The GitOps layout, the admission policy, the alert rules, the CI pipeline and the workloads would carry
over unchanged. The control plane, the GPU access layer and the queue would be replaced by managed services.

## Read more

- [Architecture](https://github.com/vbuyan/gpu-platform/blob/main/docs/architecture.md): every layer, the GPU job sequence, failure modes
- [13 architecture decision records](https://github.com/vbuyan/gpu-platform/blob/main/docs/decisions.md)
- [Postmortems](/postmortems/) and the [build log](https://github.com/vbuyan/gpu-platform/blob/main/docs/build-log.md)
- Methods that came out of it: [Yield-first cluster](/methods/yield-first-cluster/), [Shared GPU queue](/methods/shared-gpu-queue/)
