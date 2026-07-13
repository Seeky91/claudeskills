# Mode : zone (un path, ou sélection auto)

Playbook chargé par SKILL.md en mode **zone**, avec un chemin éventuel. Nettoyage chirurgical d'une zone unique. Charger `references/doctrine.md` avant d'exécuter (et `references/orchestration.md` seulement si la zone est grosse). Conventions transverses : cf. SKILL.md.

## A. Bootstrap

Si `<STATE_DIR>/doccleanup_coverage.md` est absent : le créer avec `# Doc-cleanup coverage\n\n` et l'annoncer. Résoudre `<STATE_DIR>` depuis le root projet, jamais depuis le `cwd` brut — en zone forcée, le root est celui le plus proche du `<path>`. (Même bootstrap que `mode-project.md > A`.)

## B. Déterminer la zone

**Avec `<path>` (zone forcée)** :
1. Vérifier que le path existe. Sinon → demander une clarification, ne pas deviner.
2. C'est le scope. (Fichier unique ou dossier.)

**Sans arg (zone auto)** :
1. Inventaire des zones (cf. `references/mode-project.md > B`).
2. Lire `<STATE_DIR>/doccleanup_coverage.md`, construire `zones_couvertes` (lignes `project`/`zone`).
3. Choisir : une zone **jamais couverte** en priorité ; à défaut, la moins récemment couverte. Départage déterministe par ordre alphabétique du chemin.
4. **Annoncer la zone choisie** (template `zone:selection`) avec 1-2 alternatives, et attendre la validation utilisateur (accepter / autre zone / path imposé).

## C. Exécution

1. **Taille** : mesurer les LoC source de la zone.
   - **Petite (≲ 1500 LoC, ou fichier unique)** → traiter en **main-loop** directement : lire, appliquer les 3 verbes (cf. `references/doctrine.md`).
   - **Grosse** → sous-découper en sous-dossiers cohérents. Déléguer à des sous-agents s'ils sont disponibles et autorisés ; sinon traiter les sous-zones en main-loop segmentée. Sérialiser toute mutation.
2. **Appliquer la doctrine** : SUPPRIMER le bruit, RENOMMER pour supprimer (grep des références dans tout le projet **avant** chaque rename, mise à jour de tous les sites), GARDER + dé-drifter les survivants.
3. **Refus si > 5000 LoC** en zone forcée : proposer des sous-scopes plutôt qu'un nettoyage superficiel, et demander confirmation avant de forcer.

## D. Validation

Pour toute grosse zone, déléguée ou non, **vérifier l'intégrité du résumé** avant de valider (cf. `references/orchestration.md > Vérification d'intégrité`). Puis lancer la validation (cf. `references/orchestration.md > Validation`) **une fois la zone entièrement appliquée**. KO → reporter et laisser l'utilisateur arbitrer ; la ligne de couverture s'écrit **quand même** avec `tests KO (<détail>)` — elle trace la passe mais ne compte pas comme couverture (la zone restera pending, cf. `references/file-formats.md`).

## E. Écriture + sortie

1. **Ligne de couverture** (delta, en tête de `<STATE_DIR>/doccleanup_coverage.md`) : mode `zone`. Cf. `references/file-formats.md`.
2. **Sortie** via `zone:summary` : commentaires supprimés, renames (liste), docs dé-driftées, résultat de validation, rappel non commité.

## Invariants de fin de mode

- Ligne de couverture écrite (mode `zone`).
- Validation lancée et reportée (ou dégradation annoncée).
- Renames listés.
- Aucun `git add`/`commit`.
- Zone forcée inexistante / trop grosse → clarification demandée, pas de nettoyage à l'aveugle.
