---
name: maintainability
argument-hint: "[<path> | list | update | double-check <ID> | crosscut | archive-clear]"
description: "Audit and track code maintainability: duplication, dead code, complexity, oversized files, inconsistent patterns, coupling, cohesion, boundary violations, architecture drift, test redundancy, config sprawl, and unnecessary comments. Use for code-health or architecture reviews, French « audit de maintenabilité » or « dette technique », zonal or cross-project sweeps, listing or refreshing findings, deep-checking an ID, and archive cleanup. Excludes security, performance, accessibility, and stack selection."
---

# Maintainability skill

## Frontière

Diagnostiquer et suivre la maintenabilité sans modifier le code audité pendant l'audit. Ne pas utiliser pour la sécurité, la performance, l'accessibilité ou le choix de stack.

## Références

Ce SKILL.md est un **routeur mince** : il fixe le mode, les conventions transverses et la doctrine, puis renvoie vers le playbook du mode. Les détails normatifs vivent dans `references/`, chargées **à la demande** (un mode ne paie pas le contexte des autres) :

**Playbooks de mode** (un par mode — lire et exécuter celui du mode courant) :

- `references/mode-audit.md` — inventaire des zones, sélection auto, exécution de l'audit, proposition de double-check autonome, action post-proposition batch.
- `references/mode-crosscut.md` — sélection de la dimension transverse, sweep whole-project, proposition post-crosscut.
- `references/mode-list.md` — tableau de bord lecture seule, détection des batches groupables.
- `references/mode-update.md` — re-vérification des pendings, self-heal des stales, détection intra-session, invariants *Résolution intra-session*.
- `references/mode-double-check.md` — deep-dive d'un finding (blast radius, faisabilité, verdict).
- `references/mode-archive-clear.md` — purge de l'archive des résolus.

**Doctrine et formats** (chargées quand on produit un finding ou écrit l'état) :

- `references/file-formats.md` — format des trois fichiers d'état (`maintainability_history.md`, `maintainability_findings.md`, `maintainability_resolved_archive.md`), compteur d'IDs, cycle de vie d'un finding, cap Resolved.
- `references/cascade.md` — algorithme détaillé de la re-vérification en cascade post-fix.
- `references/templates.md` — templates normatifs des sorties chat (un par usage, e.g. `audit:summary`, `list:dashboard`, `resolution:confirm`). **Lire avant chaque sortie chat** d'un mode pour garder la forme stable d'une invocation à l'autre.
- `references/dimensions.md` — catalogue des 12 dimensions seed (`DUP`, `CPX`, `SIZ`, `DED`, `INC`, `IDM`, `BND`, `DRF`, `TST`, `CFG`, `DOC`, `ARC`), frontières entre dimensions voisines, outils de détection opportunistes, référentiel paradigmatique (évaluation multi-paradigme), et cadrages des dimensions `IDM`, `ARC` et `CPX`. **Lire avant la production d'un finding** quand le préfixe ou le cadrage de la dimension n'est pas immédiatement évident.
- `references/quality.md` — grille de sévérité (HIGH/MED/LOW), garde-fous anti-bruit (*"Quand ne PAS produire de finding"*), et convention `Δ LoC`. **Lire avant la production d'un finding** : ces calibrations conditionnent la décision même d'écrire ou pas.

## Dispatch des modes

Déduire le mode de la requête utilisateur, indépendamment de la syntaxe d'invocation de l'agent :

| Intention de la requête | Mode | Playbook | Entrée attendue |
|---|---|---|---|
| Afficher le tableau de bord | **list** | `references/mode-list.md` | Aucune ; lecture seule. |
| Re-vérifier les pendings | **update** | `references/mode-update.md` | Aucune. |
| Vérifier en profondeur un finding | **double-check** | `references/mode-double-check.md` | ID tel que `DUP-007`. |
| Purger l'archive | **archive-clear** | `references/mode-archive-clear.md` | `--all`, `--keep N`, `--older-than <dur>` ou défaut > 6 mois. |
| Auditer un chemin fourni | **audit forcé** | `references/mode-audit.md` | Chemin existant. |
| Auditer sans chemin | **audit auto** | `references/mode-audit.md` | Inventorier, proposer une zone, la faire valider, puis auditer. |
| Balayer une dimension transverse | **crosscut** | `references/mode-crosscut.md` | Dimension proposée parmi `DUP`, `INC`, `DRF`, `DED`, `BND`, `ARC`. |

Accepter comme aliases de compatibilité `/maintainability`, `/maintainability-list`, `/maintainability-update`, `/maintainability-double-check`, `/maintainability-archive-clear` et `/maintainability-crosscut`. Avec Codex, utiliser le texte qui accompagne `$maintainability` pour choisir le même mode. Si le skill est invoqué explicitement sans précision, choisir **audit auto**.

**Procédure de dispatch** : (1) vérifier le root projet ; (2) résoudre `<STATE_DIR>` ; (3) valider l'entrée restante de la requête — demander une clarification uniquement pour un ID invalide, un chemin inexistant ou un flag inconnu ; (4) lire et exécuter le playbook du mode. Ne jamais dépendre d'une variable propre à un agent telle que `$ARGUMENTS`.

## Détection du root projet

Avant tout dispatch de mode, le skill confirme que `cwd` est la racine d'un projet :

1. Cherche un des marqueurs suivants dans le `cwd` : `.git/`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `composer.json`, `Gemfile`, `pom.xml`, `build.gradle`, `.hg/`, `.svn/`.
2. **Si trouvé** → continue.
3. **Si absent**, remonter dans les parents jusqu'à trouver un marqueur (ou la racine du filesystem).
4. **Si trouvé dans un parent** : annoncer *"Le root projet semble être `<chemin-parent>`, mais le `cwd` est `<cwd>`. Relance depuis `<chemin-parent>` ou confirme l'opération ici (l'état sera créé dans le projet confirmé)."* et attendre.
5. **Si aucun marqueur trouvé nulle part** : abort avec *"Aucun marqueur de projet détecté (.git, package.json, pyproject.toml, …). Lance la commande depuis la racine d'un projet."*

Ce check ne s'applique pas si l'utilisateur passe un `<path>` en argument (absolu, ou relatif résolu vs `cwd`) — dans ce cas, le path lui-même est le scope et l'état est rattaché au marqueur de root le plus proche du path.

## Résolution du répertoire d'état

Résoudre une seule fois `<STATE_DIR>` après `<PROJECT_ROOT>` afin que Claude Code et Codex partagent le même historique :

1. Si des fichiers `maintainability_*.md` existent **dans les deux répertoires**, arrêter avant toute écriture, signaler l'historique scindé et demander lequel conserver ou migrer. Ne jamais fusionner automatiquement.
2. Sinon, si l'un des fichiers `<PROJECT_ROOT>/.code-quality/maintainability_*.md` existe, utiliser `<PROJECT_ROOT>/.code-quality`.
3. Sinon, si l'un des fichiers legacy `<PROJECT_ROOT>/.claude/maintainability_*.md` existe, utiliser `<PROJECT_ROOT>/.claude` pour toute l'invocation et annoncer : *"État legacy `.claude/` conservé pour éviter de scinder l'historique."*
4. Sinon, utiliser `<PROJECT_ROOT>/.code-quality`; le créer uniquement lorsqu'un mode doit écrire.

Ne jamais lire dans un répertoire puis écrire dans l'autre pendant la même invocation. Le mode `list` ne crée aucun répertoire.

Dans toutes les références de ce skill, un nom de fichier d'état non qualifié tel que `maintainability_findings.md` désigne toujours `<STATE_DIR>/maintainability_findings.md`.

## Conventions transverses (tout mode qui écrit l'état)

Deux règles s'appliquent à **chaque** écriture des fichiers d'état, quel que soit le mode. Elles ne sont pas répétées dans chaque playbook — elles sont supposées partout.

1. **Date courante déterministe.** Toute date `YYYY-MM-DD` écrite dans l'état (ligne history, `Détecté:`, `(résolu …)`, section `Double-check (…)`, `Status: stale (…)`) ou comparée à une date stockée (seuil « > 6 mois » d'`archive-clear`) doit être obtenue via `date +%F`, **jamais supposée de mémoire**. Cohérent avec l'usage déjà fait de `git log`/`git diff` pour les autres datations. Si l'environnement ne permet pas d'exécuter `date` : le signaler en chat plutôt que d'inventer une date.

2. **Écritures en delta, jamais de régénération.** Les modes lisent l'état tôt et écrivent tard. Avant d'écrire `maintainability_findings.md` ou `maintainability_history.md`, **relire le fichier juste avant l'écriture**, puis **insérer / déplacer uniquement le(s) bloc(s) ciblé(s)** (le nouveau finding, la ligne history préfixée, le move Pending → Resolved). Ne **jamais** régénérer le fichier entier de mémoire : cela peut perdre des entrées existantes et écraser une édition manuelle faite entre-temps (le skill assume explicitement l'édition humaine de ces fichiers, cf. `references/file-formats.md`). L'écriture en delta réduit aussi la surface d'erreur sur les gros fichiers.

## Doctrine d'évaluation

Trois cadrages normatifs vivent dans `references/` et **doivent être consultés au moment de produire un finding** :

- `references/dimensions.md` — catalogue des 12 dimensions seed, référentiel paradigmatique (haute cohésion / faible couplage évalués contre les idiomes du langage ET les conventions du codebase, jamais contre un dogme unique), et cadrages stricts de `IDM`, `ARC` et `CPX`. Indique aussi le hors-scope du skill (sécurité, performance, accessibilité, choix de stack) et les outils de détection opportunistes. Préfixes inédits autorisés (3 lettres) si un problème réel ne colle à aucune dimension.
- `references/quality.md > Grille de sévérité` — HIGH/MED/LOW = impact × exposition. La sévérité est mutable (un double-check peut la reclasser, sans changer l'ID).
- `references/quality.md > Quand ne PAS produire de finding` — contrepoids au biais structurel de sur-production. Une zone à 0 finding est un audit *réussi*. Trade-off check obligatoire en amont (performance, sécurité, scalabilité, lisibilité paradoxale). Garde-fou *Dogme ≠ défaut* pour les dimensions de jugement (`ARC`, `IDM`, `CPX`) : un écart à un paradigme sans symptôme concret de friction n'est pas un finding.
- `references/quality.md > Estimation Δ LoC` — convention `~±N`, méthode d'estimation, raffinement au double-check, mesure réelle à la résolution.

## Sorties chat — conventions

Les sorties chat des modes suivent des templates normatifs définis dans `references/templates.md`. Lire ce fichier **avant chaque sortie chat** pour garder la forme stable d'une invocation à l'autre.

**Conventions transverses** (résumé) :
- **Header** des modes écrivant : `<Mode> terminé — <scope>`. Mode list utilise `Maintainability board — <projet>`.
- **Trailer** « Files mis à jour : … » : présent à chaque mode qui écrit (audit, update, double-check, archive-clear, résolution intra-session). Absent du mode list (read-only).
- Les blocs de proposition d'action utilisateur (post-audit, post-double-check single, post-double-check batch, post-list) sont distincts du récap — bloc séparé en fin de message.

**Liste des templates disponibles** (cf. `references/templates.md` pour le format de chacun) :

| Template | Quand l'utiliser |
|---|---|
| `selection:proposition` | Annonce de la zone candidate en mode audit auto. |
| `audit:summary` | Audit qui produit ≥ 1 finding. |
| `audit:clean` | Audit qui produit 0 finding (zone propre). |
| `audit:proposition` | Proposition de double-check autonome post-audit (3 options a/b/c). |
| `audit:proposition-min` | Variante post-audit pour 1 ou 2 findings. |
| `list:dashboard` | Tableau de bord en mode list. |
| `update:summary` | Récap en mode update. |
| `double-check:output` | Sortie standard d'un double-check. |
| `double-check:autonomous-batch` | Sortie agrégée d'un panel quick-wins ou batch fix. |
| `double-check:proposition` | Proposition d'action après un double-check simple (filtrée selon verdict). |
| `double-check:autonomous-batch-proposition` | Proposition d'action après un batch double-check (filtrée selon mix de verdicts). |
| `resolution:confirm` | Confirmation intra-session (variante simple ou avec cascade). |
| `resolution:done` | Confirmation finale après résolution intra-session. |
| `cascade:recap-batch` | Récap final d'un `fix B<n>` (mode list). |
| `archive-clear:confirm-all` | Confirmation purge totale (cas `--all`). |
| `archive-clear:confirm-partial` | Confirmation purge partielle (autres cas). |
| `archive-clear:done` | Récap après purge. |

## Invariants de fin de mode

Avant de rendre la main à l'utilisateur, l'agent **doit** valider que toutes les écritures attendues du mode courant ont eu lieu. Garde-fou cognitif contre le drift sur les flux multi-écritures (résolution intra-session, update batch, cascade) — une étape secondaire peut être silencieusement omise après l'étape principale.

**La checklist d'invariants de chaque mode vit en fin de son playbook** (`references/mode-<X>.md > Invariants de fin de mode`). Lire et cocher celle du mode courant avant de terminer. Règles transverses :

- Une case **non applicable** au cas courant (ex. cap Resolved pas dépassé donc pas d'archivage, pas de reclassification donc pas de titre amendé) est considérée cochée — la liste cible les omissions silencieuses, pas les opérations toujours requises.
- **Si une case n'a pas pu être cochée** : si une condition empêche une écriture attendue (tests KO, fichier en lecture seule, conflit de merge dans le findings file), **annoncer en chat** ce qui n'a pas pu être fait et pourquoi, plutôt que rendre la main silencieusement. L'utilisateur doit savoir qu'un état partiel existe.

## Edge cases

### Reclassification

Si un finding s'avère mal catégorisé (e.g. `DUP-007` est en réalité un problème de complexité, pas de duplication) :

- **Garder l'ID.** `DUP-007` reste `DUP-007`.
- Ajouter une bullet `Note: Reclassifié sémantiquement vers CPX, ID conservé pour traçabilité`.
- Optionnel : ajuster la dimension dans la bullet `Dimension`.

### Fichier déplacé / refactoré entre audits

La logique stale du mode update (`references/mode-update.md` étape 2.b et étape 4) s'applique aussi en `double-check` quand l'ID référencé pointe vers un fichier disparu.

### Doublons potentiels

Si un audit produit un finding qui ressemble fortement à un finding pending existant (même fichier, même pattern) :

- Ne pas créer de doublon. Référencer l'ID existant dans le résumé chat : *"DUP-007 toujours présent — pas re-comptabilisé."*
- Rafraîchir éventuellement la date de détection sur l'entrée existante.

### Conflit de prefix

Si l'utilisateur a manuellement utilisé un préfixe inhabituel (e.g. `XXX-001`) dans le findings file, le skill le respecte et continue à incrémenter dans cette série si pertinent. Aucun "rebasage" automatique.
