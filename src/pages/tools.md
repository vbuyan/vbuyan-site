---
layout: ../layouts/Page.astro
title: Tools
description: Small, focused tools from my projects. All open source.
---

| Tool | What it does |
|---|---|
| [turn](https://github.com/vbuyan/gpu-platform/blob/main/gpu-queue/turn) | Queue client for GPU pods: joins the host GPU queue, waits for its turn and free VRAM, execs the job, releases the card on exit. |
| [gpu_queue_exporter](https://github.com/vbuyan/gpu-platform/blob/main/gitops/monitoring/extras/gpu_queue_exporter.py) | Prometheus textfile exporter for queue state, GPU time and waits per owner. Reads what the queue publishes, never touches NVML. |
| [gpu-through-queue policy](https://github.com/vbuyan/gpu-platform/blob/main/gitops/platform/gpu-policy.yaml) | CEL ValidatingAdmissionPolicy that rejects GPU pods which try to skip the queue, with ten bypass tests. |
| [validate-manifests](https://github.com/vbuyan/gpu-platform/blob/main/ci/validate-manifests.sh) | Renders every Helm chart and Kustomize overlay the way Argo CD would and validates the result with kubeconform. |
| [install-kubernetes](https://github.com/vbuyan/gpu-platform/blob/main/bootstrap/install-kubernetes.sh) | kubeadm installer for a shared remote host with a dead man's switch: unconfirmed installs roll themselves back. |
| [subtitles](https://github.com/vbuyan/gpu-platform/tree/main/images/subtitles) | Nightly GPU CronJob that subtitles new videos with Whisper, through the shared queue. |

More on [GitHub](https://github.com/vbuyan).
