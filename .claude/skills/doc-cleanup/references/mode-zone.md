# Mode : zone (un path, ou sélection auto)

Playbook chargé par SKILL.md sur `/doccleanup [path]`. Nettoyage chirurgical d'une zone unique. Charger `references/doctrine.md` avant d'exécuter (et `references/orchestration.md` seulement si la zone est grosse). Conventions transverses : cf. SKILL.md.

## A. Bootstrap

Si `<PROJECT_ROOT>/.claude/doccleanup_coverage.md` absent : le créer avec `# Doc-cleanup coverage\n\n` et l'annoncer. Chemin **toujours** relatif au root projet résolu (cf. SKILL.md > *Détection du root projet*), jamais au `cwd` brut — en zone forcée, le root est celui le plus proche du `<path>`. (Même bootstrap que `mode-project.md > A`.)

## B. Déterminer la zone

**Avec `<path>` (zone forcée)** :
1. Vérifier que le path existe. Sinon → demander une clarification, ne pas deviner.
2. C'est le scope. (Fichier unique ou dossier.)

**Sans arg (zone auto)** :
1. Inventaire des zones (cf. `references/mode-project.md > B`).
2. Lire `.claude/doccleanup_coverage.md`, construire `zones_couvertes` (lignes `project`/`zone`).
3. Choisir : une zone **jamais couverte** en priorité ; à défaut, la moins récemment couverte. Départage déterministe par ordre alphabétique du chemin.
4. **Annoncer la zone choisie** (template `zone:selection`) avec 1-2 alternatives, et attendre la validation utilisateur (accepter / autre zone / path imposé).

## C. Exécution

1. **Taille** : mesurer les LoC source de la zone.
   - **Petite (≲ 1500 LoC, ou fichier unique)** → traiter en **main-loop** directement : lire, appliquer les 3 verbes (cf. `references/doctrine.md`).
   - **Grosse** → **fan-out** : déléguer à un ou plusieurs sous-agents de zone (sous-découper en sous-dossiers cohérents), cf. `references/orchestration.md`. Sérialiser si plusieurs.
2. **Appliquer la doctrine** : SUPPRIMER le bruit, RENOMMER pour supprimer (grep des références dans tout le projet **avant** chaque rename, mise à jour de tous les sites), GARDER + dé-drifter les survivants.
3. **Refus si > 5000 LoC** en zone forcée : proposer des sous-scopes plutôt qu'un nettoyage superficiel, et demander confirmation avant de forcer.

## D. Validation

Si la zone a été déléguée à un sous-agent (cas gros, étape C.1), **vérifier l'intégrité du résumé** avant de valider (cf. `references/orchestration.md > Vérification d'intégrité`). Puis lancer la validation (cf. `references/orchestration.md > Validation`) **une fois la zone entièrement appliquée**. KO → reporter, ne pas marquer la zone propre, laisser l'utilisateur arbitrer.

## E. Écriture + sortie

1. **Ligne de couverture** (delta, en tête de `<PROJECT_ROOT>/.claude/doccleanup_coverage.md`) : mode `zone`. Cf. `references/file-formats.md`.
2. **Sortie** via `zone:summary` : commentaires supprimés, renames (liste), docs dé-driftées, résultat de validation, rappel non commité.

## Invariants de fin de mode

- Ligne de couverture écrite (mode `zone`).
- Validation lancée et reportée (ou dégradation annoncée).
- Renames listés.
- Aucun `git add`/`commit`.
- Zone forcée inexistante / trop grosse → clarification demandée, pas de nettoyage à l'aveugle.
