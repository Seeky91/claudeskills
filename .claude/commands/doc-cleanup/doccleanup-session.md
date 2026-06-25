---
description: Aggressively clean up comments in the files touched during the current session (git working-tree diff)
argument-hint: "[--touched]"
---

Invoke the doc-cleanup skill in **session** mode. Arguments: $ARGUMENTS

Selection = source files changed in the git working tree (`git status --porcelain`). Default scope is the whole file of each touched file; `--touched` restricts to the modified hunks (partial scope — warn accordingly). Read `references/doctrine.md` first, then follow "Mode : session" (`references/mode-session.md`) in the skill.
