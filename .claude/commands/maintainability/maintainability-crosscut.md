---
description: Run a cross-zone maintainability sweep on one transverse dimension (DUP/INC/DRF/DED/BND) - dimension auto-proposed
---

Invoke the maintainability skill in **crosscut** mode. No arguments.

The skill auto-proposes a dimension from `{DUP, INC, DRF, DED, BND}` based on history (jamais crosscutée → priorité haute, sinon signal préliminaire), validates with the user, then sweeps the whole project on that dimension. Findings produced have multi-file `Localisation` and follow the same lifecycle as zonal audit findings.

See "Mode : crosscut" in the skill's `SKILL.md`.
