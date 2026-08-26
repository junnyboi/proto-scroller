# Agent Collaboration Instructions

## Concurrent Merge Policy

When fast-forward integration or a merge produces conflicts, preserve both feature sets whenever they are technically compatible. Resolve conflicts semantically: integrate both behavioral contracts and supporting tests instead of selecting an entire file with `ours` or `theirs`.

After resolving a conflict, run only a lightweight focused regression pass sufficient to catch obvious integration breakage. Do not run full release gates, repeated upstream stabilization loops, exhaustive screenshot matrices, or equivalent certification unless the user explicitly requests them.

Push the integrated result to the shared default branch (`main` or `master`) without force-pushing or rewriting history. Then create a fresh compatible Godot Web export, synchronize the repository's existing Manus WebDev project with the exact export, save a checkpoint, and deploy.

Before integration, protect local work, run `git fetch --prune`, and fast-forward where possible. If new upstream work arrives during delivery, merge it once under this policy, preserve compatible features, perform the focused regression, and continue to deployment without restarting a full certification cycle.
