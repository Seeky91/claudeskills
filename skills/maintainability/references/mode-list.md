# Mode : list

Référence chargée par SKILL.md en mode **list**. **Pas d'audit, pas de re-vérification, aucune écriture de fichier.** Lecture seule des deux fichiers projet.

## Flux

1. Lire `maintainability_findings.md` et `maintainability_history.md`.
2. Compter les pending par sévérité. Lister les IDs avec un one-liner descriptif (extrait de l'observation, ~50 chars).
3. **Compter et lister à part les findings stale** (pending dont la bullet `Status` est `stale ...` ou `stale-after-<ID> ...`) — distincts des actifs car ils nécessitent une action utilisateur (relocaliser, marquer résolu, ou archiver) avant de pouvoir être traités. Ils restent inclus dans le total Pending.
4. Lister les résolus des 30 derniers jours (filtrer par la date dans le titre Resolved).
5. Lister les entrées du rolling actif zonal (les `N` premières lignes **non `crosscut:*`** de history, cf. `references/file-formats.md > Lignes crosscut`).
6. **Rolling crosscut** : lister les `Nx` lignes `crosscut:*` les plus récentes de history (`Nx = 6` par défaut, override `<!-- crosscut_rolling_size: M -->`). Même format de ligne que le rolling zonal : `<date> — crosscut:<DIM> — <N findings (status)>`. Omettre la section si aucune ligne crosscut.
7. Détecter les batches groupables parmi les pending **actifs uniquement** (les stale sont exclus du batching, cf. *Batches suggérés*).

## Sortie

Utiliser le template `list:dashboard`. Cas dégénérés :

- Zéro pending actif (peut-être stale) : afficher `Pending actifs (0) : aucun finding actionnable.` La section Stale reste affichée si non vide.
- Zéro stale : omettre entièrement la section Stale (ne pas afficher `Stale (0)`).
- Zéro audit : afficher `Aucun audit dans l'historique. Invoque maintainability en mode audit pour commencer.`

## Batches suggérés

**Détection** (lecture seule, pas d'analyse de code) :

1. Pour chaque pending, extraire ID, dimension prefix, path (le *primaire* du titre pour les findings multi-fichiers), audit_origin (date `Détecté:`), et contenu de la dernière section `Double-check` si présente.
2. **Signaux explicites** (haute priorité) dans le Double-check, regex insensibles à la casse : `bundle`/`bundler`, `sequencing`/`étape \d+`, `après <ID>`/`avant <ID>`, `couplé avec <ID>`. Chaque mention d'un autre `<ID>` connu crée une arête ; composantes connexes = batches.
3. **Signaux heuristiques** (fallback) : même path exact ; sinon même path parent + même dimension prefix ; sinon même audit_origin. Les findings crosscut du même run partagent l'audit_origin (date du crosscut) — ils peuvent batcher entre eux via cette voie sans cas spécial.
4. Garder seulement les batches de 2 à 5 findings. Lister explicites en premier, compléter avec heuristiques. Max 3 affichés.
5. Si aucun batch valide : afficher *"Pas de batch évident détecté — les pendings sont indépendants."* et **omettre** le prompt de sélection.

**Format d'affichage** : intégré dans le template `list:dashboard` (section *Batches suggérés*).

**Recommandation** : marquer un batch `★ recommandé` selon ces critères, dans l'ordre :

1. **Scope minimal** : préférer 1 fichier > module > multi-modules (blast radius bas).
2. **Signal explicite** : préférer un batch issu d'un signal explicite sur un batch heuristique.
3. **`|Δ LoC|` le plus faible** (changement le plus contenu).
4. **Tie-break** : ID le plus petit (`B1` > `B2` > …).

La raison courte affichée à côté du `★` reprend le critère qui a tranché (ex. `1 fichier, blast radius bas`, `co-design explicite`, `Δ LoC contenu`).

Si aucun batch ne se distingue (≥ 2 batches strictement équivalents sur les 4 critères) : ne pas marquer `★`. Le prompt d'action devient *"Plusieurs batches équivalents — choisis selon ta priorité (`double-check B<n>`, `fix B<n>`, `rien`)."*

**Action selon la réponse utilisateur** :

- **`double-check B<n>`** : exécuter le flux de `references/mode-double-check.md` sur chaque finding du batch dans l'ordre. Sortie agrégée via `double-check:autonomous-batch`, suivie de `double-check:autonomous-batch-proposition`. Action selon choix utilisateur : cf. `references/mode-audit.md > I. Action post-proposition batch`.
- **`fix B<n>`** (l'exécution applique systématiquement les checkpoints décrits ci-dessous — l'utilisateur n'a pas à le préciser) :
  1. Plan par finding (1-3 lignes : fichiers touchés, ordre, Δ LoC attendu) — réutilise `Reco affinée` si présente, sinon `Reco`.
  2. Afficher le plan global, demander un OK explicite. Si OK, exécuter dans l'ordre.
  3. **Avant** chaque marquage `Resolution`, lancer la suite de tests (détectée via marqueurs : `cargo test`, `npm test`, `pytest`, `go test ./...`, etc. ; sinon demander la commande). Tests OK → flux résolution intra-session. Tests KO → arrêt, ne pas marquer, annoncer ; pas de revert auto.
  4. **Cascade re-check** automatique après chaque résolution du batch (cf. `references/cascade.md`) — sans nouveau prompt puisque l'OK plan global de l'étape 2 couvre.
  5. Récap final via le template `cascade:recap-batch`.
- **`rien`** : terminer sans rien faire.

**Cas dégénérés** : batch ID invalide ("B5" alors que seuls B1/B2 listés) → demander relance de `list`. Finding déjà résolu entre `list` et action → skip avec annonce.

## Cas du projet sans state

Si `<STATE_DIR>/maintainability_*.md` n'existent pas, **ne pas bootstrapper** (mode list est lecture seule). Annoncer : *"Aucun audit de maintenabilité sur ce projet. Invoque le skill `maintainability` en mode audit pour bootstrapper."*

## Invariants de fin de mode (list)

Aucune écriture attendue — vérifier qu'aucun fichier projet n'a été modifié pendant le mode (read-only strict). Si l'utilisateur a déclenché `double-check B<n>` ou `fix B<n>`, les invariants des flux correspondants (`references/mode-audit.md > I` ou *Résolution intra-session* de `references/mode-update.md`) s'appliquent.
