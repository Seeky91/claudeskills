---
description: Purge the resolved-findings archive (default - older than 6 months) - confirms before writing
argument-hint: "[--all | --keep <N> | --older-than <duration>]"
---

Invoke the maintainability skill in **archive-clear** mode. Arguments: $ARGUMENTS

Parse the flags (`--all`, `--keep N`, `--older-than <duration>`) per the skill's dispatch table. Default (no flag) drops entries resolved more than 6 months ago. Always confirm with the user before writing.

See "Mode : archive-clear" in the skill's `SKILL.md`.
