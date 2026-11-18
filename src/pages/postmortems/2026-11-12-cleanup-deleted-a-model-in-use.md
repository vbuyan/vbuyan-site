---
layout: ../../layouts/Page.astro
title: "The cleanup that deleted a model still in use"
kind: Postmortem
date: "2026-11-12"
description: "Intermediate training checkpoints looked safe to delete. One of them was the default model of a live pipeline, reached through a symlink, and the backup had saved only the link."
---

| | |
|---|---|
| Date | 2026-11-12 |
| Impact | A production pipeline lost its default fine-tuned model (a LoRA). Recovered the same day; four older experimental checkpoints were lost for good. No customer work affected. |
| Severity | Medium |
| Status | Resolved; delete procedure changed, backup scope still open |

## Summary

A disk cleanup removed intermediate checkpoints of a training run: files named like `model_s250`,
`model_s500` … `model_s1500`. The final model had its own file, so the intermediate steps looked like
leftovers. But the image tool loaded models from its own folder, and that folder held **symlinks** into the
training output. One of the "intermediate" files, the last step, was the default model in two scripts. After
the delete, the links pointed at nothing.

The backup did not help. It covered the image tool's folder, where it dutifully stored the
symlinks, not the files they pointed to. The training output folder was not in the backup at all.

## Timeline

| Time | Event |
|---|---|
| 11-12 | Cleanup approved: training checkpoints and other large leftovers. |
| 11-12 | Checkpoints deleted by name pattern. |
| 11-12 | The default model of a pipeline turns out to be a dangling link in the models folder. |
| 11-12 | The backup has only the link. The final step of training was byte-identical to the "final" file, so it was restored as a hard link to it. Earlier steps are gone. |
| 11-12 | Delete procedure changed. |

## Root cause

1. **"Intermediate" by name is not "unused".** Nothing checked whether anything referenced the files.
2. **Symlinks hide dependencies.** A plain listing of the models folder shows names, not targets.
3. **The backup scope followed folders, not data.** Backing up a link is not backing up the data behind it.

## What changed

A delete now goes through three checks before anything is removed:

```bash
# 1. is the name used anywhere in code or config?
grep -rn "NAME" ~/ai --include=*.py --include=*.json --include=*.sh --exclude-dir=venv
# 2. does any symlink point at it (and are any links already broken)?
find ~/ai /srv -lname '*NAME*'
find ~/ai /srv -xtype l
# 3. is it registered in the shared resource library?
```

- Deletes go to a 14-day bin first, and every delete is logged to a journal.
- **Still open:** the backup scope has to follow the data that links point into, not only the folders the
  tools read from. Until that is done, the bin and the checks above are the safety net.

## Lessons

- Before deleting, ask "who uses this?", not "what is it called?".
- Back up data, not paths. Check how your backup tool treats symlinks.
- A recycle bin with a timer turns a permanent mistake into a recoverable one.
