---
name: maintainability
description: Use when the user invokes `/maintainability`, asks for a maintainability audit on a codebase, wants to identify duplication / DRY violations / dead code / god files / inconsistent patterns / test redundancy / config sprawl / unnecessary comments in a project, asks to list or update or double-check existing maintainability findings, or wants a structured code-health review of a specific module or pipeline.
---

# Maintainability skill

## Quand l'invoquer

Famille de slash commands :

- `/maintainability` — audit (auto si pas d'arg, forcé si `<path>` fourni)
- `/maintainability-list` — tableau de bord, lecture seule
- `/maintainability-update` — re-vérification de tous les pendings
- `/maintainability-double-check <ID>` — deep-dive sur un finding existant
- `/maintainability-archive-clear [--all|--keep N|--older-than <dur>]` — purge de l'archive

Chaque command file invoque ce skill avec un mode pré-déterminé. Ne pas invoquer ce skill pour : audits de sécurité, de performance, d'accessibilité, ou choix de stack — ce sont d'autres revues.

## Dispatch des modes

Le mode est fixé par la slash command utilisée (cf. ci-dessus). La table ci-dessous est la référence canonique de l'argument que chaque mode attend dans `$ARGUMENTS` :

| Command | Mode | `$ARGUMENTS` attendu |
|---|---|---|
| `/maintainability-list` | **list** | (aucun) — affiche le tableau de bord, aucune écriture. |
| `/maintainability-update` | **update** | (aucun) — re-vérifie tous les pendings, met à jour les statuts. |
| `/maintainability-double-check` | **double-check** | `<ID>` (ex. `DUP-007`) — deep-dive sur le finding. |
| `/maintainability-archive-clear` | **archive-clear** | `[--all\|--keep N\|--older-than <dur>]` — défaut : > 6 mois. Confirme avant d'écrire. |
| `/maintainability <path>` | **audit forcé** | chemin existant dans le repo — audite la zone fournie. |
| `/maintainability` (vide) | **audit auto** | (aucun) — inventaire des zones, sélection autonome avec validation user, puis audit. |

Si `$ARGUMENTS` ne respecte pas le format attendu pour la command invoquée (e.g. ID invalide pour double-check, path inexistant pour audit forcé) : le skill **demande une clarification à l'utilisateur** plutôt que de deviner.

Toutes les opérations supposent que le répertoire courant est la racine d'un projet à auditer. Le skill **vérifie ce point avant tout** (voir section *Détection du root projet*). Si `.claude/` n'existe pas dans le projet, le skill bootstrappe (voir section Bootstrap).

## Détection du root projet

Avant tout dispatch de mode, le skill confirme que `cwd` est la racine d'un projet :

1. Cherche un des marqueurs suivants dans le `cwd` : `.git/`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `composer.json`, `Gemfile`, `pom.xml`, `build.gradle`, `.hg/`, `.svn/`.
2. **Si trouvé** → continue.
3. **Si absent**, remonter dans les parents jusqu'à trouver un marqueur (ou la racine du filesystem).
4. **Si trouvé dans un parent** : annoncer *"Le root projet semble être `<chemin-parent>`, mais le `cwd` est `<cwd>`. Relance depuis `<chemin-parent>` ou confirme l'opération ici (le `.claude/` sera créé dans le `cwd`)."* et attendre.
5. **Si aucun marqueur trouvé nulle part** : abort avec *"Aucun marqueur de projet détecté (.git, package.json, pyproject.toml, …). Lance la commande depuis la racine d'un projet."*

Ce check ne s'applique pas si l'utilisateur passe un `<path>` en argument (absolu, ou relatif résolu vs `cwd`) — dans ce cas, le path lui-même est le scope, et le `.claude/` est créé là où se trouve le marqueur de root le plus proche du path.

## Mode : audit

Déclenché par `/maintainability` (auto) ou `/maintainability <path>` (forcé).

### A. Bootstrap (si `.claude/maintainability_*.md` absent)

1. Si `.claude/` n'existe pas dans le projet : créer le dossier.
2. Si `maintainability_history.md` absent : créer avec `# Maintainability audit history\n\n` (rien d'autre).
3. Si `maintainability_findings.md` absent : créer avec `# Maintainability findings\n\n## Pending\n\n## Resolved\n`. Pas de header `<!-- id_counters: ... -->` à ce stade (création paresseuse à la première assignation d'ID). Pas non plus de `maintainability_resolved_archive.md` (création paresseuse au premier débordement du cap Resolved).
4. Annoncer en chat : *"Bootstrap maintainability sur ce projet, aucun historique préalable."*
5. Continuer le flux d'audit normalement (pas de rolling à respecter).

### B. Inventaire des zones

Calculer à chaque audit (jamais persisté). Algorithme :

1. **Walk de l'arbo** depuis la racine du projet.
2. **Pour chaque dossier**, mesurer le total LoC source (exclure `.json`, `.toml`, `.lock`, `.md`, dossiers `node_modules`, `.git`, `dist`, `build`, `vendor`, `target`, `.venv`, et tout ce qui ressemble à du généré).
3. **Règles de découpage** :
  - Dossier 200–2000 LoC → zone candidate.
  - Dossier > 2000 LoC → descendre dans ses sous-dossiers, appliquer la règle récursivement.
  - Dossier < 200 LoC → grouper avec son parent (ne pas le proposer seul).
4. **Fichiers ≥ 600 LoC source** (peu importe leur dossier) → zone autonome additionnelle. Chasse les god files même quand ils sont noyés dans un dossier raisonnable.
5. **Mesure LoC source** : compter les lignes non vides hors lignes-commentaires pures. Approximation acceptable, pas besoin d'AST.
6. **Pipelines candidats** : si en parcourant l'arbo le skill identifie un flux de données traçable (un point d'entrée qui appelle 3-5 fichiers en chaîne), il peut le proposer comme zone `pipeline:<nom>` avec la liste explicite des fichiers. Si le skill n'arrive pas à nommer le pipeline et ses fichiers concrètement, il **n'inclut pas** de pipeline dans les candidats — on n'invente pas de pipeline pour cocher la case.

`Z` = nombre total de zones candidates issu de cet inventaire.

### C. Sélection (mode auto, args vides)

1. **Lire le rolling** dans `maintainability_history.md` (parser les lignes `- YYYY-MM-DD — <zone> — …` et extraire la zone).
2. Calculer `N = clamp(round(Z / 4), 3, 8)` (override possible via `<!-- rolling_size: M -->` en tête de history, voir *Format des fichiers projet*).
3. **Candidats** = `inventaire - rolling` (les `N` derniers).
4. **Pondération** :
  - Zones jamais auditées (n'apparaissant dans aucune ligne du history actuel) → priorité haute.
  - Sinon, sélection aléatoire pondérée parmi les candidats restants.
5. **Visée pipeline ~30%** : si des candidats `pipeline:` existent et qu'on n'a pas audité de pipeline récemment (rolling), augmenter leur pondération pour atteindre approximativement 30% des audits sur la durée.
6. **Annonce en chat** :
  ```
  Je propose : services/billing/refund/ (jamais auditée, ~800 LoC)
  Alternatives : core/api_handler.py (god file, 1842 LoC) ou pipeline:order-processing [api/ingest.py, validators/order.py, enrichers/customer.py, store/orders.py]
  ```
7. **Validation utilisateur** : accepter, demander une alternative listée, ou imposer un autre chemin. Attendre avant de lancer l'audit.

#### Cas dégénérés de la sélection

- **Candidats vides** (typiquement petit projet avec un override `rolling_size` qui exclut tout) : relâcher le rolling, choisir la zone la moins récemment auditée parmi **toutes** les zones de l'inventaire. Annoncer *"Toutes les zones sont dans le rolling — j'ai pris la moins récente : `<zone>` (auditée 2026-04-22)."* Si égalité, aléatoire.
- **Inventaire vide** (`Z = 0`) : abort avec *"Aucune zone auditable détectée (chaque dossier fait < 200 LoC source ou est exclu). Le projet est-il vide, ou veux-tu auditer manuellement un chemin précis via `/maintainability <path>` ?"*
- **Une seule zone candidate après exclusion** : pas d'alternatives à proposer, annoncer la zone unique et demander si on lance.

### D. Audit forcé (mode `<path>`)

0. Si bootstrap nécessaire (`.claude/maintainability_*.md` absent) : suivre la section *A. Bootstrap* avant les étapes ci-dessous.
1. Vérifier que le chemin existe dans le projet courant.
2. Mesurer la taille de la zone (LoC source agrégée).
3. **Si > 5000 LoC** : refuser un audit aveugle. Annoncer la taille, proposer un sous-scope (ex. *"trop large à 6200 LoC. Sous-scopes possibles : `<path>/sub1/`, `<path>/sub2/`"*) et demander confirmation. L'utilisateur peut forcer s'il insiste, en sachant que l'audit sera moins profond.
4. Sinon : audit direct, pas de sélection auto.

### E. Exécution de l'audit

Pour la zone validée :

1. **Lire le code de la zone** intégralement (tous les fichiers source dans le scope).
2. **Examiner systématiquement toutes les dimensions** du catalogue. Pour chacune :
  - Chercher des occurrences concrètes du pattern dans la zone.
  - Pour chaque occurrence : observer (fait vérifiable, fichier:ligne, contexte), évaluer la sévérité (impact × exposition selon la grille), **estimer le Δ LoC** que produirait l'application de la reco (négatif si la reco supprime du code, positif si elle en ajoute, format `~±N`). Voir section *Estimation Δ LoC*.
  - **Ne pas forcer la production de findings.** Une dimension peut très bien produire 0 finding si le code est propre sur cet axe.
3. **Si un problème réel ne colle à aucune dimension** : créer un nouveau préfixe 3 lettres. Documenter brièvement dans le finding pourquoi cette nouvelle catégorie.
4. **Assignation des IDs** : suivre le mécanisme de la section *Compteur d'IDs* (lire le header `<!-- id_counters: ... -->`, incrémenter, mettre à jour la ligne header). Format à 3 chiffres (`DUP-007`).

### F. Écritures

1. **Append des findings** dans `## Pending` de `maintainability_findings.md`. Format strict (voir section *Format des fichiers projet*).
2. **Préfixer une nouvelle ligne en tête** de `maintainability_history.md` :
  ```
  - YYYY-MM-DD — <zone> — N findings (X HIGH, Y MED, Z LOW) (pending)
  ```
3. **Trim** : recalculer la taille rolling et supprimer les lignes en surplus du bas.

#### Cas zone propre (0 findings)

Si l'audit produit zéro finding (zone réellement clean sur toutes les dimensions) :

- **Écrire quand même la ligne history**, format adapté :
  ```
  - YYYY-MM-DD — <zone> — 0 findings (clean)
  ```
- Ne **rien appender** dans `maintainability_findings.md` (pas de pending à créer).
- Sortie en chat : *"Audit terminé — `<zone>`. Aucun finding produit, zone propre sur toutes les dimensions examinées. Files mis à jour : .claude/maintainability_history.md (+1 ligne `0 findings (clean)`)."*

L'écriture de la ligne history est **importante** : sans elle, la zone serait re-proposée trop tôt par le rolling. Une zone propre reste légitimement dans le rolling pour éviter le ressassement.

### G. Sortie en chat

Format type :

```
Audit terminé — services/billing/refund/

6 nouveaux findings (3 HIGH, 2 MED, 1 LOW) :
  DUP-007 (HIGH, Δ ~-40) — duplication logique refund 3×
  SIZ-009 (HIGH, Δ ~+60) — refund_handler.py 1200 LoC, 5 responsabilités
  CPX-012 (HIGH, Δ ~-15) — boucle imbriquée 4 niveaux dans apply_refund
  TST-005 (MED, Δ ~-20) — assertions sur impl plutôt que contrat (4 tests)
  INC-008 (MED, Δ ~±5) — 2 conventions d'erreur dans le même module
  DOC-011 (LOW, Δ ~-3) — docstring obsolète sur process_refund

Δ LoC total estimé si tout est appliqué : ~-23.

Files mis à jour : .claude/maintainability_findings.md (+6 findings), .claude/maintainability_history.md (+1 ligne).
Pour creuser un item à la main : /maintainability-double-check DUP-007.

Tu peux aussi me laisser creuser en autonomie. Sur quoi ?
  (a) un panel de quick-wins : DOC-011, INC-008, TST-005 — 3 findings au fix court et peu de blast radius.
  (b) le finding le plus structurant : SIZ-009 — god file 1200 LoC, 5 responsabilités.
  (c) rien, je verrai plus tard.
```

Le résumé n'inclut pas les Reco — elles sont dans le fichier. Le but est l'orientation, pas la duplication.

### H. Proposition de double-check autonome (post-audit)

Après le résumé en chat, si l'audit a produit ≥ 1 finding, proposer trois options à l'utilisateur (cf. exemple ci-dessus) puis attendre sa réponse.

**Critères de sélection des panels :**

- **(a) Quick-wins** : panel de 3 à 5 findings « bas effort, fix direct ».
  - Sévérité LOW en priorité, complétée par des MED si nécessaire pour atteindre 3.
  - `|Δ LoC|` faible (≤ 30) ou reco mono-fichier sans blast radius identifiable.
  - **Pas de finding HIGH dans ce panel** — un HIGH n'est jamais un quick-win.
- **(b) Heavy finding** : un seul finding, le plus structurant.
  - Sévérité HIGH en priorité (sinon le MED de plus large scope).
  - Plus large scope d'abord : god file > duplication structurante 3+ > drift transverse > complexité locale.
  - Tie-break : `|Δ LoC|` estimé le plus élevé.
- **(c) Rien** : l'utilisateur verra plus tard.

**Cas dégénérés :**

- 0 finding : ne pas afficher cette proposition (déjà couvert par le cas zone propre).
- 1 ou 2 findings : remplacer la proposition à 3 options par une question simple : *"Veux-tu que je fasse un double-check autonome sur `<ID>` ?"*
- Aucun candidat ne tient les critères de quick-win (e.g. tous les findings sont HIGH avec gros blast radius) : ne proposer que (b) et (c).
- Aucun finding HIGH ni MED de gros scope : pour (b), proposer le finding au plus grand `|Δ LoC|` estimé, en avertissant que ce n'est pas un finding « lourd » au sens classique.

**Exécution selon le choix utilisateur :**

- **(a) Quick-wins** : pour chaque finding du panel, exécuter le flux *Mode : double-check* (lecture du fichier, trace, blast radius, Δ LoC affiné, reco affinée, verdict). Écrire la section `Double-check (date)` dans chaque entrée du fichier findings. **Résumer en chat un seul message agrégé** avec un verdict par ID, pas un message par finding. Exemple :
  ```
  Double-check autonome terminé sur 3 quick-wins :
    DOC-011 — GO (Δ -3, fix trivial : suppression docstring + commit unique) — Apport : supprime un commentaire qui décrivait un comportement obsolète et trompait à la lecture.
    INC-008 — GO-après-DUP-007 (Δ ±5, à fusionner avec le refactor de refund pour éviter de toucher 2× le même fichier) — Apport : un seul pattern de pagination dans le module billing, plus de divergence à arbitrer à chaque ajout d'endpoint.
    TST-005 — NO-GO (Δ -20 mais les 4 tests d'impl couvrent un edge case que le contrat ne capture pas — à archiver)

  Files mis à jour : .claude/maintainability_findings.md (+3 sections Double-check).
  ```

- **(b) Heavy finding** : exécuter le flux *Mode : double-check* sur le finding sélectionné. Sortie complète comme un double-check standard (pas d'agrégation).

- **(c) Rien** : terminer la commande. Aucune écriture supplémentaire.

**Cas NO-GO en autonomie** : si une exécution autonome conclut NO-GO sur un finding et que l'utilisateur le confirme dans la foulée, marquer dans Resolved avec `Resolution: archivé après double-check (NO-GO motivé : <raison>)` plutôt que de le laisser en pending indéfiniment.

## Mode : list

Déclenché par `/maintainability-list`. **Pas d'audit, pas de re-vérification, aucune écriture de fichier.** Lecture seule des deux fichiers projet.

### Flux

1. Lire `maintainability_findings.md` et `maintainability_history.md`.
2. Compter les pending par sévérité. Lister les IDs avec un one-liner descriptif (extrait de l'observation, ~50 chars).
3. **Compter et lister à part les findings stale** (pending dont la bullet `Status` est `stale ...` ou `stale-after-<ID> ...`) — distincts des actifs car ils nécessitent une action utilisateur (relocaliser, marquer résolu, ou archiver) avant de pouvoir être traités. Ils restent inclus dans le total Pending.
4. Lister les résolus des 30 derniers jours (filtrer par la date dans le titre Resolved).
5. Lister les entrées du rolling (taille `N` actuelle).
6. Détecter les batches groupables parmi les pending **actifs uniquement** (les stale sont exclus du batching, cf. *Batches suggérés*).

### Sortie type

```
Maintainability board — services/example-project/

Pending (8) :
  HIGH (3) : DUP-007 (duplication refund), SIZ-003 (god file api_handler), INC-002 (3 patterns paginate)
  MED  (4) : CPX-005, TST-001, DRF-002, CFG-003
  LOW  (1) : DOC-006

Stale (2) — à relocaliser, marquer résolu, ou archiver :
  CFG-003 — stale-after-SIZ-009 (fix du 2026-05-04, localisation invalidée)
  TST-005 — stale (config/flags.toml introuvable, update du 2026-04-22)

Recently resolved (30 derniers j.) :
  DUP-005 (MED) — 2026-04-16 — extraction _validate_token
  CPX-002 (HIGH) — 2026-04-10 — flatten boucle imbriquée

Rolling (N=4) :
  2026-05-03 — services/billing/refund/ — 6 findings (résolus DUP-007+SIZ-003)
  2026-05-01 — pipeline:order-processing — 4 findings (pending)
  2026-04-22 — core/api_handler.py — 8 findings (pending)
  2026-04-15 — services/auth/ — 3 findings (résolus tous)

Batches suggérés (2) :

  B1 · core/api_handler.py · Δ ~+45 · 2 findings  ★ recommandé : 1 fichier, blast radius bas
       DUP-007·HIGH + SIZ-003·HIGH — extraire la dup avant le split god file

  B2 · multi-fichiers (3 paths) · Δ ~-30 · 3 findings
       CPX-005·MED + TST-001·MED + DRF-002·MED — sequencing explicite (CPX-005 → DRF-002)

Je propose `double-check B1` (recommandé).
Sinon : `fix B1` direct, un autre batch (`double-check B2` / `fix B2`), ou `rien`.
```

Si zéro pending actif (peut-être stale) : afficher `Pending actifs (0) : aucun finding actionnable.` La section Stale reste affichée si non vide.
Si zéro stale : omettre entièrement la section Stale (ne pas afficher `Stale (0)`).
Si zéro audit : afficher `Aucun audit dans l'historique. Lance /maintainability pour commencer.`

### Batches suggérés

**Détection** (lecture seule, pas d'analyse de code) :

1. Pour chaque pending, extraire ID, dimension prefix, path, audit_origin (date `Détecté:`), et contenu de la dernière section `Double-check` si présente.
2. **Signaux explicites** (haute priorité) dans le Double-check, regex insensibles à la casse : `bundle`/`bundler`, `sequencing`/`étape \d+`, `après <ID>`/`avant <ID>`, `couplé avec <ID>`. Chaque mention d'un autre `<ID>` connu crée une arête ; composantes connexes = batches.
3. **Signaux heuristiques** (fallback) : même path exact ; sinon même path parent + même dimension prefix ; sinon même audit_origin.
4. Garder seulement les batches de 2 à 5 findings. Lister explicites en premier, compléter avec heuristiques. Max 3 affichés.
5. Si aucun batch valide : afficher *"Pas de batch évident détecté — les pendings sont indépendants."* et **omettre** le prompt de sélection.

**Format d'affichage** (deux lignes par batch + une ligne de proposition d'action) :

```
  B<n> · <zone> · Δ ~<±N> · <K> findings  [★ recommandé : <raison courte>]
       <ID·SEV> + <ID·SEV> + … — <rationale 1 ligne>
```

- `<zone>` = path (fichier ou dossier) si tous les findings partagent un path, sinon `multi-fichiers (<K> paths)`.
- `Δ ~<±N>` = somme des `Δ LoC` des findings du batch (estimation initiale ou affinée si Double-check présent).
- `<rationale 1 ligne>` = motif du groupage en une phrase concise. Pour signal explicite : citer brièvement la mention (« reco TST-005 demande DUP-009 d'abord »). Pour heuristique : décrire le pattern (« même module-folder », « sequencing dans Double-checks »).
- `★ recommandé : <raison>` = marqueur inline sur **un seul** batch (cf. *Recommandation*).

**Recommandation** : marquer un batch `★ recommandé` selon ces critères, dans l'ordre :

1. **Scope minimal** : préférer 1 fichier > module > multi-modules (blast radius bas).
2. **Signal explicite** : préférer un batch issu d'un signal explicite sur un batch heuristique.
3. **`|Δ LoC|` le plus faible** (changement le plus contenu).
4. **Tie-break** : ID le plus petit (`B1` > `B2` > …).

La raison courte affichée à côté du `★` reprend le critère qui a tranché (ex. `1 fichier, blast radius bas`, `co-design explicite`, `Δ LoC contenu`).

Si aucun batch ne se distingue (≥ 2 batches strictement équivalents sur les 4 critères) : ne pas marquer `★`. Le prompt d'action devient *"Plusieurs batches équivalents — choisis selon ta priorité (`double-check B<n>`, `fix B<n>`, `rien`)."*

**Prompt d'action** (post-affichage des batches) :

```
Je propose `double-check B<reco>` (recommandé).
Sinon : `fix B<reco>` direct, un autre batch (`double-check B<n>` / `fix B<n>`), ou `rien`.
```

L'utilisateur répond en texte libre.

**Action selon la réponse utilisateur** :

- **`double-check B<n>`** : exécuter le flux *Mode : double-check* sur chaque finding du batch dans l'ordre. Sortie agrégée en un seul message (verdict par ID, avec l'`Apport` repris pour chaque GO / GO-mais-après-X).
- **`fix B<n>`** (l'exécution applique systématiquement les checkpoints décrits ci-dessous — l'utilisateur n'a pas à le préciser) :
  1. Plan par finding (1-3 lignes : fichiers touchés, ordre, Δ LoC attendu) — réutilise `Reco affinée` si présente, sinon `Reco`.
  2. Afficher le plan global, demander un OK explicite. Si OK, exécuter dans l'ordre.
  3. **Avant** chaque marquage `Resolution`, lancer la suite de tests (détectée via marqueurs : `cargo test`, `npm test`, `pytest`, `go test ./...`, etc. ; sinon demander la commande). Tests OK → flux résolution intra-session (move + compaction, cf. *Cycle de vie*). Tests KO → arrêt, ne pas marquer, annoncer ; pas de revert auto.
  4. **Cascade re-check** automatique après chaque résolution du batch (cf. *Re-vérification en cascade*) — sans nouveau prompt puisque l'OK plan global de l'étape 2 couvre. Cascadés et stale-after sont agrégés. Si la cascade résout un item ultérieur du batch : skip cet item avec annonce *"<ID> déjà résolu collatéralement par <ID-primaire>, skip."*
  5. Récap final : *"X/Y résolus, Δ LoC total mesuré : ..., commits : ... ; cascade : N résolus collatéralement, M stale-after"* (la ligne cascade est omise si overlap zéro sur tous les fixes du batch).
- **`rien`** : terminer sans rien faire.

**Cas dégénérés** : batch ID invalide ("B5" alors que seuls B1/B2 listés) → demander relance de `list`. Finding déjà résolu entre `list` et action → skip avec annonce.

### Cas du projet sans state

Si `.claude/maintainability_*.md` n'existent pas, **ne pas bootstrapper** (mode list est lecture seule). Annoncer : *"Aucun audit de maintenabilité sur ce projet. Lance `/maintainability` pour bootstrapper."*

## Mode : update

Déclenché par `/maintainability-update`. **Pas d'audit nouveau.** Re-vérifie tous les pendings contre l'état actuel du code et met à jour les statuts.

### Flux

1. Lire `maintainability_findings.md`. Itérer sur chaque entrée de la section `## Pending`.
2. Pour chaque finding :
  a. Lire le fichier référencé en localisation.
  b. **Si le fichier est introuvable** (déplacé, supprimé, renommé) :
    - Si `Status: stale-after-<ID>` est déjà présent (posé par la cascade) : laisser tel quel, ne pas le remplacer par un `stale` générique — l'info de cause est plus précieuse.
    - Sinon : marquer `Status: stale`, ne pas conclure résolu/pending. **Ne pas tenter de re-locater automatiquement** (risque de faux positif sur un fichier au nom voisin). Noter la situation.
  c. **Si le fichier existe** : vérifier que le pattern décrit dans l'observation est toujours présent à la localisation indiquée (ou nearby si les lignes ont bougé). Heuristique :
    - Lire les ~20 lignes autour de la localisation.
    - Si le pattern décrit (duplication, god file taille, etc.) est encore reconnaissable → status inchangé.
    - Si le pattern a disparu → bascule en Resolved.
3. Pour chaque résolu détecté :
  - Déplacer l'entrée de `## Pending` vers `## Resolved` au **format compact** (cf. *Format compact d'une entrée résolue* dans *Format des fichiers projet*) — Observation, Reco, Δ initial et Double-check sont droppés au move.
  - Ajouter `(résolu YYYY-MM-DD)` au titre.
  - La bullet `Resolution` indique `détecté résolu lors de update (YYYY-MM-DD). Δ LoC mesuré : <valeur>` (via `git log --since=<date> -- <fichier>` ou comparaison directe ; sinon `indéterminé`). Ajouter `Commit : <hash>` si un commit aval est identifiable.
  - Mettre à jour la ligne history correspondante (l'audit qui a créé ce finding) : ajouter ou compléter le `(résolus <ID>+...)`.
4. Pour chaque stale (générique ou `stale-after-<ID>` posé par la cascade) : laisser dans Pending. Le `Status` a déjà été ajusté à l'étape 2.b. Demander à l'utilisateur en chat — message adapté à la cause :
  - Stale générique : *"`<ID>` référence un fichier introuvable. Rouvrir avec nouveau path, marquer résolu (le pattern n'existe plus), ou archiver ?"*
  - Stale-after : *"`<ID>` est `stale-after-<ID-primaire>` depuis le fix du <YYYY-MM-DD>. Localisation invalidée par le fix. Rouvrir avec nouveau path, marquer résolu, ou archiver ?"*
5. **Vérification de l'invariant cap Resolved** : compter les entrées de la section `## Resolved` après les moves de l'étape 3. Si > cap (cf. *Format des fichiers projet > maintainability_findings.md*), appliquer le flux d'archivage automatique (cf. *Cycle de vie d'un finding* étape 5) pour ramener au cap.
6. **Recompute des compteurs d'IDs** : re-scanner `maintainability_findings.md` + `maintainability_resolved_archive.md` (s'il existe), recalculer le max par préfixe, mettre à jour le header `<!-- id_counters: ... -->` du fichier findings (le créer s'il est absent). Self-heal contre drift (édition manuelle, bug du skill). Le skill lit l'archive ici et dans `archive-clear` uniquement — coût acceptable car les deux opérations sont rares et explicites.

### Sortie en chat

```
Update terminé — services/example-project/

Re-vérifié 8 pendings :
  Résolus (2) : DUP-005, CPX-008
  Toujours présents (4) : DUP-007, SIZ-003, INC-002, TST-001
  Stale (1) : CFG-003 (config/flags.toml introuvable, déplacé ?)
  Stale-after (1) : DRF-002 (stale-after-SIZ-009 préservé, pas écrasé)
  Archivés (3) : DUP-001, DUP-002, INC-001 (cap Resolved atteint)

Files mis à jour : .claude/maintainability_findings.md, .claude/maintainability_history.md, .claude/maintainability_resolved_archive.md
```

### Coût

Cette commande lit potentiellement beaucoup de fichiers (un par pending). Acceptable car invocation rare et explicite — pas appelée à chaque audit.

### Détection intra-session

Indépendamment de la commande `update` explicite, **pendant la conversation qui suit un audit ou un double-check**, si l'utilisateur applique un fix qui résout un finding listé :

1. Le skill **exécute la re-vérification en cascade en lecture seule** (cf. *Re-vérification en cascade > Confirmation utilisateur*), puis propose la confirmation batchée — primaire + cascadés + stale-after en un seul prompt. Si overlap = 0 (aucun autre pending sur les fichiers du diff) : prompt simple *"Ce fix résout DUP-007. Je marque comme résolu ?"*.
2. Si l'utilisateur valide : applique le même flux que update sur le primaire (move Pending → Resolved, bullet `Resolution`, ligne history) **et** exécute les écritures cascade (cascade-resolved au format compact, stale-after taggés, lignes history complétées pour cascadés, cap Resolved respecté).
3. **Confirmer en chat** par une ligne explicite `Files mis à jour : .claude/maintainability_findings.md (move <ID> → Resolved [+ N cascadés] [+ M stale-after]), .claude/maintainability_history.md (résolus <ID>+...)` détaillant les écritures effectuées. Si push-back partiel à l'étape 1 (l'utilisateur a refusé certains items) : la ligne reflète seulement ce qui a été appliqué.

Cette détection est **opportuniste, pas exhaustive**. Pour une re-vérification systématique après plusieurs fixes hors-session, l'utilisateur lance `/maintainability-update`.

## Mode : double-check

Déclenché par `/maintainability-double-check <ID>` (ex. `/maintainability-double-check DUP-007`). Approfondit un finding existant, ne crée pas de nouveau finding.

### Flux

1. **Localiser le finding** : scanner `maintainability_findings.md`, trouver l'entrée `### <ID> — …`. Si absent → demander à l'utilisateur un ID valide (ne pas inventer).
2. **Lire le fichier référencé** intégralement, plus les fichiers voisins / importeurs.
3. **Trace** :
  - **Localisation complète** : tous les call sites, imports, références au symbole/pattern concerné.
  - **Blast radius** : tests qui touchent la zone, surfaces publiques affectées, couplages cachés (ce qui casse si on applique le fix proposé).
  - **Faisabilité de la reco initiale** : tient-elle ? Y a-t-il une contrainte (typage, signature publique, dépendance circulaire, contrat externe) qui invaliderait la reco ?
  - **Effort estimé** : `S` (≤2h), `M` (≤1j), `L` (>1j, plusieurs commits). Distinct de la faisabilité.
  - **Δ LoC affiné** : ré-estimer à la lumière du blast radius et des contraintes. Si l'écart avec l'estimation initiale est > 50 %, expliquer brièvement pourquoi.
  - **Reco affinée** : ajustée à la lumière des contraintes découvertes, ou alternatives si l'originale ne tient plus.
  - **Verdict** : GO / NO-GO / GO-mais-après-X.
  - **Apport** (uniquement si Verdict GO ou GO-mais-après-X — jamais sur NO-GO) : une seule phrase concrète qui nomme ce qui s'améliore. Une formulation générique type *"améliore la maintenabilité"* reste valable si elle est étoffée par le **comment** (ce qui rend le code plus maintenable, concrètement, dans ce cas précis). À l'agent de décider de la teneur — pas de catégorie imposée.
4. **Possibilité de reclasser la sévérité** : si l'analyse montre que HIGH était excessif (effort L mais impact en réalité MED), proposer le changement à l'utilisateur. **Ne pas changer l'ID.**

### Écriture dans le fichier findings

Ajouter une section au sein de l'entrée existante du finding (avant la ligne `Status:` ou après `Détecté:`) :

```markdown
- **Double-check (YYYY-MM-DD) :** Blast radius : 47 imports dans le projet, 12 tests touchés. Effort M (~1 jour, 4 commits incrémentaux). Faisabilité OK avec contraintes mineures (transactions à préserver). Δ LoC affiné : ~+85 (au lieu de ~+120 estimé : on regroupe routing + middleware au lieu de splitter en 5 fichiers). Reco affinée : splitter d'abord routing puis validation, persistance en dernier. Verdict : GO, prioriser après TST-009. Apport : chaque responsabilité d'`api_handler` devient testable indépendamment et débloque le refactor de routing prévu plus tard.
```

Si la sévérité change, **également** modifier le titre de l'entrée :
```
### SIZ-003 — MED — core/api_handler.py
```

### Sortie en chat

Réponse complète en chat (l'utilisateur veut le détail pour décider) avec une copie de ce qui a été écrit dans le fichier + tout contexte additionnel utile (extraits de code des call sites, etc.). L'`Apport` (si verdict GO / GO-mais-après-X) est repris tel quel.

## Mode : archive-clear

Déclenché par `/maintainability-archive-clear [--all|--keep N|--older-than <duration>]`. Purge `maintainability_resolved_archive.md` selon les critères. Toujours confirmer avant d'écrire.

### Flux

1. Si l'archive n'existe pas : abort avec *"Pas d'archive sur ce projet, rien à clearer."*
2. Parser les entrées de l'archive : extraire `ID` et la date `(résolu YYYY-MM-DD)` du titre.
3. Calculer `dropped` / `kept` selon les args :
  - **Défaut** (aucun flag) : drop entrées résolues il y a > 6 mois.
  - `--older-than <duration>` : format `<entier><unité>` avec unités `d`/`m`/`y` (`m`=30j, `y`=365j). Ex. `6m`, `1y`, `90d`. Parse échoué → *"Durée `<input>` non reconnue. Format attendu : `6m`, `1y`, `90d`."*
  - `--keep N` : conserver les N entrées les plus récentes (date du titre).
  - `--all` : drop tout.
4. **Recompute des compteurs d'IDs** (cf. *Mode : update > Flux* étape 6) : scanner findings + archive complète **avant** la suppression, mettre à jour le header `<!-- id_counters: ... -->`. Garantit que les IDs futurs continuent de monter monotonement.
5. **Confirmation utilisateur** :
  - `--all` : *"Confirme la suppression totale de l'archive (X entrées). Tape 'oui' pour confirmer."* — attend "oui" littéral.
  - Autre cas : *"X entrées seront supprimées, Y conservées (la plus récente : <ID> du <date>). Confirmer ? (y/N)"*.
6. Réécrire l'archive avec les seules entrées `kept`. Si `kept = []` (cas `--all`) : supprimer le fichier (recreation paresseuse au prochain débordement).
7. Annoncer en chat : *"Archive clearée — X supprimées, Y conservées. Compteurs : DUP=12, SIZ=5, ..."*.

### Garde-fous

- Aucune modification sur `maintainability_findings.md` (sauf le header de compteurs) ni sur `maintainability_history.md`. Les références dangling depuis history vers une entrée archivée disparue restent — convention "voir git".
- Confirmation obligatoire dans tous les cas, même par défaut.
- Si le filtre ne capture aucune entrée : *"Filtre `<critère>` ne capture aucune entrée. Archive inchangée."* — pas d'écriture, pas même du header.

## Catalogue des dimensions (seed)

11 dimensions de départ. **Ce n'est pas une grille fermée** : si un problème de maintenabilité réel ne colle à aucune, **invente un nouveau préfixe 3 lettres** (ex. `LOG-` pour sprawl de logging, `RAC-` pour patterns concurrents). La rigueur est sur l'observation factuelle, pas sur l'étiquetage.

| Préfixe | Dimension | Cible |
|---|---|---|
| `DUP` | Duplication / DRY | Code répété, logique copiée-collée avec variations mineures, schémas dupliqués |
| `CPX` | Complexité inutile, factorisation | Imbrications profondes, accumulation de conditions, opportunités d'extraire un helper |
| `SIZ` | Taille excessive | God files (≥600 LoC source), modules mêlant trop de responsabilités |
| `DED` | Code mort | Exports/imports inutilisés, branches inatteignables, blocs commentés laissés en place |
| `INC` | Patterns incohérents | 3 façons de paginer, 4 conventions d'erreur, 2 styles de logging dans le même module |
| `IDM` | Idiomes du langage | Non-conformité aux patterns idiomatiques du langage : gestion d'erreur, gestion des ressources, builder pattern, types stricts, etc. (cf. cadrage dédié) |
| `BND` | Violations de frontière, couplage caché | Module A qui importe les internes de B, contournement de l'API publique, co-changement fréquent |
| `DRF` | Drift de types/interfaces | Schémas quasi-identiques qui divergent par accident, dup back/front, types parallèles |
| `TST` | Tests | Redondance, fragilité, ratio code/test qui dérive (tests devenant la majorité du code), tests d'impl plutôt que de contrat |
| `CFG` | Config / feature-flags sprawl | Env vars / flags accumulés, certains plus jamais flippés ou lus |
| `DOC` | Doc/commentaires | Désync code/doc, ET commentaires inutiles sur code self-explanatory (paraphrase d'un nom de fonction explicite) |

**Hors scope du skill** : sécurité, performance, accessibilité, choix de stack.

**Principe d'observation** : décrire le problème en clair (fait vérifiable, fichier:ligne, impact concret) **avant** de chercher quel préfixe coller. Ne pas forcer une dimension par audit.

### Cadrage de la dimension IDM

`IDM` cible la non-conformité aux patterns idiomatiques du langage. Le risque de cette dimension est qu'elle dérive en linter de style — le cadrage suivant est strict.

**Détection des langages** : avant l'audit, identifier les langages via extensions et fichiers de config (`Cargo.toml`, `pyproject.toml`, `package.json`, `go.mod`, `Gemfile`, `pom.xml`, `composer.json`, …). Sur projet multi-langage, évaluer IDM zone par zone selon le langage dominant.

**Périmètre inclus** : patterns structurels avec impact maintenabilité direct — lisibilité par un dev habitué au langage, error-prone-ness évitable, friction avec l'écosystème. Familles à couvrir : gestion d'erreur idiomatique (Rust `Result`/`?`, Go error wrapping, Python `try/except` ciblé), gestion des ressources (context managers Python, `defer` Go, RAII Rust, try-with-resources Java), types et conteneurs adaptés (dataclasses Python, types stricts TS, `Optional` Java), patterns de construction du langage (builder Rust, comprehensions Python). L'agent s'appuie sur sa connaissance des idiomes du langage rencontré, pas sur une liste fermée du skill.

**Périmètre exclu** : tout ce qui est automatisable par un linter ou un formatter — naming style (snake_case vs camelCase), ordre des imports, indentation, choix de quotes, longueur de ligne, espace avant parenthèse. Hors scope du skill.

**Abstention sur méconnaissance** : si l'agent n'a pas une connaissance suffisante des idiomes d'un langage présent dans la zone, il s'abstient sur cette dimension plutôt que d'inventer des règles. Note honnête en chat type *"Je passe IDM sur ce fichier Elixir : idiomes du langage hors zone de confort."*

## Grille de sévérité

Sévérité = **impact × exposition**. Ce n'est pas un goût, c'est une calibration sur l'effet sur la maintenabilité du code.

- **HIGH** — bloque ou alourdit toute évolution future de la zone.
  Exemples : god file dans un hot path, duplication structurante (3+ copies de logique), drift de contrat utilisé partout, tests fondants empêchant tout refactor.
- **MED** — friction notable mais contournable.
  Exemples : incohérence locale de pattern, redondance modérée de tests, sprawl de config sur 2-3 modules, duplication 2x sur fonction utilitaire.
- **LOW** — cosmétique, nettoyage sans impact comportemental.
  Exemples : commentaire stale, var inutilisée, doublon trivial dans helper jamais touché, doc d'une fonction self-explanatory.

**La sévérité est mutable.** Un `double-check` peut révéler que ce qu'on pensait HIGH est en fait MED (ou inversement). Dans ce cas : amender l'attribut sévérité dans l'entrée, **ne pas changer l'ID**.

## Quand ne PAS produire de finding

Le skill est intrinsèquement orienté détection, ce qui crée un biais structurel à sur-produire des findings pour "justifier" l'invocation. Sans contre-poids, l'audit dérive vers du **paperclip maximizing** : on optimise la maintenabilité jusqu'à dégrader d'autres aspects du projet. Cette section est le contrepoids.

### Conscience du biais à sur-produire

Une zone qui produit 0 finding sur toutes les dimensions est un audit **réussi**, pas un audit raté (cf. *Cas zone propre* déjà documenté). Corollaires opérationnels :

- Ne pas remplir du vide pour rentabiliser l'invocation.
- Si une dimension n'a rien produit après examen sérieux, passer à la suivante sans forcer.
- Si la zone entière est propre, l'écrire (ligne history `0 findings (clean)`) et s'arrêter là — pas de finding "consolation" pour avoir l'air d'avoir travaillé.
- Une dimension qui ne produit jamais rien sur une zone donnée n'est pas un échec d'audit ; le code peut être propre sur cet axe.

### Trade-off check sur les autres axes du projet

Si la reco améliorerait la maintenabilité au prix d'une dégradation visible sur un autre axe : **ne pas produire le finding** par défaut, ou le produire en annotant explicitement le trade-off dans la bullet `Reco`. Axes à vérifier avant production :

- **Performance** : abstraction qui ajoute du coût per-call dans un hot path, allocation supplémentaire, indirection runtime introduite par un helper, copies de données en plus.
- **Sécurité** : suppression d'un check, élargissement d'une surface d'attaque, partage d'état précédemment isolé, secret précédemment scopé qui devient transitif.
- **Scalabilité** : suppression d'un seam d'extension, fusion de variantes "presque identiques" qui pourraient diverger demain, aplatissement qui bloque l'ajout futur d'une nouvelle responsabilité, suppression d'une couche d'indirection qui était un point de branchement. Trop simplifier aujourd'hui se paye cher quand on voudra accueillir une feature.
- **Lisibilité paradoxale** : sur-abstraction qui crée des indirections plus difficiles à suivre que la duplication originale (DRY pathologique : 3 copies divergentes fusionnées en un helper paramétré incompréhensible avec un boolean qui change le comportement à mi-chemin).

**Règle par défaut** : si le trade-off est significatif, ne pas produire le finding. Si le finding est produit malgré un trade-off identifié, l'annoter dans la bullet `Reco` (ex. *"Reco : extraire `_apply_refund_policy`. Trade-off : si une 4e variante de refund émerge, le helper devra être paramétré — accepter ce coût plus tard plutôt que maintenant."*) pour que l'utilisateur puisse trancher en connaissance de cause.

Ce check intervient **en amont** de la production du finding. Il ne remplace pas le double-check (qui creuse la faisabilité d'un finding existant) — il intervient une étape avant, à la décision même de produire.

## Estimation Δ LoC

Chaque finding doit indiquer un `Δ LoC` estimé : la variation de lignes de code source que produirait l'application de la reco. Format `~±N` (le `~` marque l'estimation, le signe indique l'effet net).

**Convention de signe :**
- **Négatif** (`~-40`) : la reco réduit le code (extraction de duplication, suppression de dead code, fusion de variantes).
- **Positif** (`~+30`) : la reco ajoute du code (split d'un god file en modules avec boilerplate, ajout d'une couche d'abstraction).
- **Quasi-nul** (`~±5`) : la reco déplace ou réécrit sans réduire (renommage transverse, restructuration locale, harmonisation de pattern).

**Méthode d'estimation à l'audit :**
- Mesurer la taille des occurrences impliquées (lignes du pattern × nombre de copies).
- Soustraire la taille du helper / module extrait, en incluant un peu de boilerplate (signature, imports, docstring si nécessaire).
- Pour les splits de god files : estimer à partir de la taille des responsabilités identifiées + ~10-20 % de boilerplate (imports, signatures, ré-exports).
- Si l'estimation est trop incertaine pour être utile (e.g. la reco dépend de choix d'architecture non tranchés) : noter `Δ LoC : indéterminé — à affiner en double-check`.

**À l'application du fix (résolution) :** mesurer le delta réel via `git diff --stat` ou comptage direct, et le consigner dans `Resolution :`. Format `Δ LoC mesuré : -47`. C'est cette valeur qui compte dans les bilans, pas l'estimation initiale.

**À un double-check :** raffiner l'estimation à la lumière du blast radius et des contraintes découvertes. Format `Δ LoC affiné : ~-35`. Si le raffinement contredit l'estimation initiale (> 50 % d'écart), expliquer brièvement pourquoi (ex. *"on regroupe routing + middleware au lieu de splitter en 5 fichiers"*).

**Chat summary post-audit :** afficher un Δ LoC compact par finding (e.g. `(HIGH, Δ ~-40)`) et un Δ LoC total estimé sur l'ensemble si tout était appliqué. C'est une indication d'orientation, pas un objectif (un Δ très positif sur un split de god file peut être pleinement justifié).

## Format des fichiers projet

Deux fichiers vivent dans `<projet>/.claude/`. Le skill les crée/lit/écrit. Format strict, à respecter à la lettre.

### `.claude/maintainability_history.md`

Une ligne par audit. Taille adaptative `N = clamp(round(Z / 4), 3, 8)` où `Z` est le nombre de zones inventoriées au moment de l'écriture. Au write-time, recalcule N et trim le surplus du plus ancien.

```markdown
<!-- rolling_size: 5 -->        # commentaire optionnel : override manuel
# Maintainability audit history

- 2026-05-03 — services/billing/refund/ — 6 findings (3 HIGH, 2 MED, 1 LOW) (résolus DUP-007+SIZ-003)
- 2026-05-01 — pipeline:order-processing [api/ingest.py, validators/order.py, enrichers/customer.py, store/orders.py] — 4 findings (1 HIGH, 3 MED) (pending)
- 2026-04-22 — core/api_handler.py — 8 findings (4 HIGH, 3 MED, 1 LOW) (pending)
- 2026-04-15 — services/auth/ — 3 findings (1 MED, 2 LOW) (résolus tous)
```

Règles :
- Format ligne : `- YYYY-MM-DD — <zone> — N findings (X HIGH, Y MED, Z LOW) (status)`
- `<zone>` = chemin dossier (`services/billing/refund/`), chemin fichier (`core/api_handler.py`), ou `pipeline:<nom> [fichiers,…]` (le bracket fichiers n'apparaît QUE pour les pipelines).
- `(status)` : `(pending)`, `(résolus tous)`, ou `(résolus <ID>+<ID>+...)` quand certains seulement sont résolus.
- Si `<!-- rolling_size: N -->` est présent en tête de fichier, **respecter cette valeur** au lieu du calcul auto, même si elle tombe hors `[3, 8]`. L'utilisateur sait ce qu'il veut ; le skill ne discute pas la valeur.

### `.claude/maintainability_findings.md`

Source de vérité. Findings groupés en deux sections, plus un header de compteurs d'IDs.

```markdown
# Maintainability findings

<!-- id_counters: DUP=7, SIZ=3, CPX=2, INC=2, DOC=1 -->

## Pending

### DUP-007 — HIGH — services/billing/refund_handler.py:42-67
- **Dimension :** duplication de code
- **Observation :** Logique de refund dupliquée 3× avec variations mineures (l. 42, 89, 134).
- **Reco :** Extraire dans `_apply_refund_policy(order, policy)`.
- **Δ LoC :** ~-40 (3 copies de ~25 LoC fusionnées dans un helper de ~30 LoC).
- **Détecté :** 2026-05-03 (audit zone services/billing/refund/)
- **Status :** pending

### SIZ-003 — HIGH — core/api_handler.py
- **Dimension :** god file (1842 LoC, 23 fonctions, 4 responsabilités)
- **Observation :** Fichier mêle routing, validation, persistance, formatting.
- **Reco :** Splitter en `routing.py`, `validation.py`, `formatting.py` ; persistence va dans `db/api_log.py`.
- **Δ LoC :** ~+120 (split en 4 modules avec imports/signatures partagées, ~30 LoC de boilerplate par module).
- **Détecté :** 2026-04-22
- **Status :** pending
- **Double-check (2026-04-25) :** Blast radius : 47 imports, 12 tests touchés. Effort M (~1 jour, 4 commits incrémentaux). Faisabilité OK avec contraintes mineures (transactions à préserver). Δ LoC affiné : ~+85. Verdict : GO, prioriser après TST-009. Apport : chaque responsabilité d'`api_handler` devient testable indépendamment et débloque le refactor de routing prévu plus tard.

## Resolved

### DUP-005 — MED — services/auth/login.py:23 (résolu 2026-04-16)
- **Dimension :** duplication de code
- **Resolution :** Extrait vers `services/auth/_helpers.py`. Δ LoC mesuré : -32. Commit : a7b3d12.
- **Audit origin :** 2026-04-15 (services/auth/)
```

Règles :
- En-tête entrée : `### <ID> — <SÉVÉRITÉ> — <localisation>` (avec `(résolu YYYY-MM-DD)` ajouté pour les Resolved).
- `<localisation>` = `path:line` ou `path:start-end` ou juste `path` (pour les god files).
- **Pending** — bullets dans cet ordre : Dimension, Observation, Reco, Δ LoC, Détecté, Status, puis sections optionnelles (Double-check). Valeurs de `Status` : `pending` (initial), `stale (YYYY-MM-DD) — <raison>` (posé par `update` quand le fichier est introuvable, cf. *Mode : update > Flux* étape 2.b), `stale-after-<ID> (YYYY-MM-DD) — <raison>` (posé par la cascade quand le fix de `<ID>` invalide la localisation, cf. *Re-vérification en cascade*).
- **Resolved** — format compact à 3 bullets : Dimension, Resolution, Audit origin. Voir *Format compact d'une entrée résolue* ci-dessous.
- L'ID est immuable. Tout autre attribut peut être amendé.
- Le header `<!-- id_counters: PREFIX=N, ... -->` cache les compteurs d'IDs pour assignation rapide (cf. *Compteur d'IDs*). Absent dans un fichier fraîchement bootstrappé ; ajouté à la première assignation d'ID.
- **Cap Resolved = 8** (valeur canonique unique du skill, référencée partout ailleurs). La section `## Resolved` est cappée à 8 entrées ; les plus anciennes sont déplacées vers `maintainability_resolved_archive.md` automatiquement (cf. *Cycle de vie d'un finding* étape 5).

#### Format compact d'une entrée résolue

À chaque move vers `## Resolved` (intra-session, update, NO-GO post double-check). **Drop** : Observation, Reco, Δ initial, Status, Double-check. **Conserver** : 3 bullets fixes :

```markdown
### DUP-011 — LOW — crates/bot/src/web.rs (résolu 2026-05-06)
- **Dimension :** duplication scaffolding vault
- **Resolution :** Helper `vault_blocking<F,T>` ajouté, 4 sites migrés. Δ LoC mesuré : -30. Commit : 86518fb.
- **Audit origin :** 2026-05-05 (crates/bot/src/web.rs)
```

`Resolution` doit contenir : description courte du fix + `Δ LoC mesuré : <valeur>` + `Commit : <hash>` (ou `Commits : <h1>+<h2>`). `Audit origin` reprend la date et la zone de l'audit qui a produit le finding.

**Cas NO-GO archivé** (cf. *Mode : audit > H. Proposition de double-check autonome*) : `Resolution` cite la raison du NO-GO en 1-2 phrases ; `Δ LoC : N/A (NO-GO)` remplace le Δ mesuré.

Les entrées Resolved en format verbose **existantes** restent valides — pas de re-écriture rétroactive.

### `.claude/maintainability_resolved_archive.md`

Cold storage pour les entrées de `## Resolved` qui débordent du cap (valeur définie en *Format des fichiers projet > maintainability_findings.md > Règles*). **Jamais lu par défaut** : le skill ne le charge que pendant `update` (recompute des compteurs d'IDs). Création paresseuse au premier débordement.

```markdown
# Maintainability resolved archive

### DUP-001 — MED — services/auth/login.py:23 (résolu 2026-04-16)
- **Dimension :** duplication de code
- **Observation :** Validation token dupliquée avec `services/auth/refresh.py:18`.
- **Reco :** Helper `_validate_token()`.
- **Δ LoC :** ~-25 (estimation initiale).
- **Resolution :** Extrait vers `services/auth/_helpers.py`. Δ LoC mesuré : -32.

### CPX-002 — HIGH — core/api_handler.py:88 (résolu 2026-04-22)
- ...
```

Règles :
- Pas de section `## Pending` / `## Resolved` (le fichier entier est l'équivalent d'un `## Resolved` géant).
- Entrées au format strict identique à celles de `## Resolved` du fichier findings (titre + bullets, déplacées intactes — pas de compaction).
- Append-only en fin de fichier (l'ordre = ordre chronologique des résolutions, du plus ancien au plus récent).
- Les IDs des entrées archivées restent référencés dans `maintainability_history.md` (lignes `(résolus DUP-001+...)`) — pas de mise à jour à faire dans history lors de l'archivage.
- Lecture explicite uniquement par l'utilisateur (`grep`, ouverture éditeur, ou demande conversationnelle "regarde l'archive et …"). Pas de mode dédié dans le skill.

### Compteur d'IDs (header cached)

Le fichier `maintainability_findings.md` porte un header en commentaire HTML qui cache le max assigné par préfixe :

```markdown
<!-- id_counters: DUP=12, CPX=8, SIZ=5, INC=4, DRF=2, BND=1, TST=2, DOC=4, DED=4, CFG=1 -->
```

**Assignation d'un nouvel ID** : lire le compteur pour le préfixe dans le header, incrémenter, écrire le finding avec ce nouvel ID, mettre à jour la ligne header. Coût trivial : le header est déjà chargé, pas besoin de scanner l'archive ni même la totalité du fichier findings.

**Préfixe inédit** (premier finding d'une nouvelle dimension comme `LOG-`, `RAC-`, ou autre invention) : ajouter `<PREFIX>=1` au header.

**Header absent** (cas migration depuis un état pré-archive, ou édition manuelle qui l'a viré) : scan one-shot de `maintainability_findings.md` + `maintainability_resolved_archive.md` (s'il existe), calcul des max par préfixe, écriture du header. Coût ponctuel, jamais répété ensuite.

**Self-healing** : à chaque `update`, recompute des compteurs en re-scannant les deux fichiers (cf. *Mode : update > Flux* étape 6). Avec `archive-clear`, ce sont les seuls moments où le skill lit l'archive — coût acceptable car les deux opérations sont rares et explicites.

Format : à 3 chiffres (`DUP-007`), peut grandir au-delà sans souci (`DUP-1042` reste lisible).

**Jamais de réutilisation d'ID**, même après suppression manuelle d'une entrée par l'utilisateur, et même après archivage. Le compteur monte monotonement. Si max trouvé = `DUP-005` mais l'utilisateur a supprimé `DUP-005`, le prochain est `DUP-006` (pas `DUP-005`).

## Cycle de vie d'un finding

1. **Création** lors d'un audit → entrée `## Pending` avec ID, dimension, sévérité, observation, reco, date, `Status: pending`.
2. **Double-check** (`/maintainability-double-check <ID>`) → ajoute une section `Double-check (date)` dans l'entrée existante. Peut amender la reco. Peut révéler un changement de sévérité (proposer à l'utilisateur, valider, puis amender l'attribut).
3. **Résolution intra-session** → quand l'utilisateur applique un fix dans la conversation qui suit un audit ou un double-check, le skill **propose** de marquer résolu :
  - Déplace l'entrée en `## Resolved` au **format compact** (cf. *Format compact d'une entrée résolue*) — Observation, Reco, Δ initial, Status, Double-check sont droppés.
  - Ajoute `(résolu YYYY-MM-DD)` dans le titre.
  - La bullet `Resolution` contient : description courte du fix + `Δ LoC mesuré : <valeur>` (mesurer via `git diff --stat` ou comptage direct ; faire la mesure dans le tour de conversation si possible) + `Commit : <hash>` du commit qui applique le fix.
  - Met à jour la ligne history correspondante : `(résolus DUP-007)` → `(résolus DUP-007+SIZ-003)` si plus d'un fix.
  - **Déclenche la re-vérification en cascade** sur les pendings dont la localisation chevauche le diff du fix (cf. *Re-vérification en cascade*). Le résultat est intégré dans le **même prompt** de confirmation primaire — l'utilisateur valide l'ensemble (primaire + cascadés + stale-after) en un mot.
4. **Update** (`/maintainability-update`) → re-vérifie chaque pending :
  - Pattern toujours présent → status inchangé.
  - Pattern absent → bascule en Resolved au format compact (cf. étape 3) ; `Resolution` indique `détecté résolu lors de update (YYYY-MM-DD)` + Δ mesuré + `Commit : <hash>` si identifiable via `git log`.
  - Fichier disparu / déplacé → `Status: stale` (sauf si `stale-after-<ID>` est déjà posé par la cascade : préservé, pas écrasé). Demande à l'utilisateur de confirmer (rouvrir avec nouveau path, marquer résolu, ou archiver).
5. **Archivage automatique** → après chaque move vers `## Resolved` (étapes 3, 4, ou *Cas NO-GO en autonomie* du mode audit) :
  - Compter les entrées de la section `## Resolved` du fichier findings.
  - Si > cap (cf. *Format des fichiers projet > maintainability_findings.md*) : déplacer la (les) plus ancienne(s) vers `maintainability_resolved_archive.md` jusqu'à ramener le compte au cap. Ancienneté déterminée par la date `(résolu YYYY-MM-DD)` dans le titre — la plus petite date part en premier. Tie-break en cas d'égalité de date : ordre dans le fichier (la plus haute dans la section part en premier).
  - Si l'archive n'existe pas, la créer à la volée avec le header `# Maintainability resolved archive\n\n` puis appender l'entrée.
  - Append en fin d'archive (l'ordre d'archivage = ordre chronologique des résolutions).
  - L'entrée est déplacée intacte (la compaction a déjà eu lieu au move vers `## Resolved`).
  - Le header `<!-- id_counters: ... -->` du fichier findings n'est pas affecté (les IDs restent monotonement croissants ; cf. *Compteur d'IDs*).

## Re-vérification en cascade

Sous-processus déclenché automatiquement après chaque move Pending → Resolved **lié à un fix** (intra-session, `fix B<n>` depuis list). But : détecter et tenir à jour les findings dont la localisation chevauche le diff du fix sans relancer un `update` complet. Les moves NO-GO (pas de fix, pas de diff) et les résolutions issues de `update` (déjà exhaustif par construction) ne déclenchent **pas** de cascade.

### Algorithme

1. **Capter le diff** : `git show --name-only <hash>` où `<hash>` est le commit de la `Resolution` du finding primaire. Pour des fixes batchés (plusieurs primaires dans le même turn) : union des paths sur tous les commits associés. Si pas de commit identifiable (cas rare où le fix n'est pas committé au moment de la résolution) : sauter la cascade et noter en chat *"Cascade re-check sautée : pas de commit identifié pour `<ID>`."*

2. **Filtrer les candidats** parmi `## Pending`, hors les primaires déjà déplacés. Un finding est candidat ssi son path :
  - matche exactement un path du diff, ou
  - est descendant d'un dossier du diff, ou
  - est ancêtre d'un path du diff (cas god file dont le contenu est splitté en sous-fichiers).
  
  **Si zéro candidat** : sortie silencieuse, aucune écriture, aucun message en chat.

3. **Re-check par candidat** — réutilise la logique par-dimension de *Mode : update > Flux* étape 2c. Trois issues possibles :
  - **Pattern toujours présent** → laisser pending. Si la ligne a shifté significativement, mettre à jour `path:line` dans le titre. Pas d'autre écriture.
  - **Pattern absent** (fichier toujours là, observation ne tient plus) → cascade-resolved. Move vers `## Resolved` au format compact (cf. *Format compact d'une entrée résolue*). Bullet `Resolution :` au format : *"résolu collatéralement par fix de `<ID-primaire>` (YYYY-MM-DD). Δ LoC mesuré : intégré dans `<ID-primaire>`. Commit : `<hash-primaire>`."* — pas de fragmentation du Δ, la valeur globale reste dans la `Resolution` du primaire ; le commit est celui du primaire (le cascadé n'a pas son propre commit).
  - **Fichier disparu / renommé** (path absent du repo après le fix) → laisser en pending et **remplacer** la bullet `Status` par `Status : stale-after-<ID-primaire> (YYYY-MM-DD) — localisation invalidée par le fix, à relocaliser ou archiver`. Pas de question synchrone.

4. **Mettre à jour `maintainability_history.md`** : pour chaque cascade-resolved, retrouver la zone et la date de l'audit d'origine via la bullet `Détecté` de l'entrée Pending (lue **avant** le move qui la drop) et compléter `(résolus <IDs>+...)` sur la ligne d'audit correspondante.

5. **Appliquer l'invariant cap Resolved** (cf. *Cycle de vie d'un finding* étape 5).

### Confirmation utilisateur (flux intra-session)

Le flux intra-session existant (*"Ce fix résout DUP-007. Je marque comme résolu ?"*, cf. *Mode : update > Détection intra-session*) est étendu : la cascade s'exécute en lecture seule **avant** le prompt, et son résultat est inclus dans le **même prompt** que la confirmation primaire :

```
Ce fix résout DUP-007 (Δ -32). Cascade re-check sur 3 pendings touchant les mêmes fichiers :
  - INC-008 — pattern absent → résolu collatéralement
  - DOC-011 — pattern toujours présent (l. 42 → 38, à mettre à jour)
  - TST-005 — tests/refund_test.py renommé → stale-after-DUP-007

Je marque DUP-007 + INC-008 résolus, mets à jour DOC-011, et tag TST-005 stale-after ?
```

L'utilisateur valide tout en un mot. Si push-back partiel (*"garde INC-008 en pending"*) : appliquer le reste, ne pas insister.

### Sortie en chat (flux pré-validés)

Les flux `fix B<n>` (mode list) ont déjà un OK explicite avant exécution. La cascade s'exécute alors **sans nouveau prompt** ; son résultat agrégé est intégré au récap final :

```
3/3 résolus, Δ LoC total mesuré : -47, commits : a7b3+c812+d934.
Cascade re-check : 1 résolu collatéralement (DOC-011), 1 stale-after (TST-005).
```

Si overlap = 0 sur tous les fixes du batch : la ligne `Cascade re-check :` est omise.

### Edge cases

- **Cascade qui résout un autre item du batch en cours** (cas `fix B<n>`) : si le re-check post-fix de l'item #1 résout DUP-008 et que DUP-008 est l'item #2 du batch → skip DUP-008 dans la suite avec annonce *"DUP-008 déjà résolu collatéralement par DUP-007, skip."* Réutilise le pattern existant *"Finding déjà résolu entre `list` et action → skip avec annonce."*
- **`update` rencontre un `stale-after-<ID>` existant** : laisser tel quel, ne pas remplacer par un `stale` générique — l'info de cause est plus précieuse (cf. *Mode : update > Flux* étape 2.b).

### Idempotence et borne de coût

- Idempotent : re-runner la cascade sur le même commit ne re-bouge rien (les cascadés sont déjà dans Resolved, le filtre à l'étape 2 les exclut).
- Coût : ∝ |pendings ∩ overlap diff|, pas |pendings|. ≤ ~20 lignes lues par candidat (le re-check par-dim borne lui-même).
- Aucun coût si overlap zéro (filtrage tôt à l'étape 2, sortie silencieuse à l'étape 3).

### Distinction avec `/maintainability-update`

`update` est exhaustif et explicite — l'utilisateur le lance pour rattraper des fixes hors-session. La cascade est **ciblée et automatique** — elle couvre les fixes faits dans la conversation courante. Les deux cohabitent : la cascade limite la dérive intra-session, `update` ratisse plus large quand la dérive a échappé.

## Invariant de fin de mode

Avant de rendre la main à l'utilisateur, l'agent **doit** valider que toutes les écritures attendues du mode courant ont eu lieu. Cette section liste le checklist par mode — toute case applicable non cochée doit être exécutée avant de répondre. Garde-fou cognitif contre le drift sur les flux multi-écritures (intra-session resolution, update batch, cascade), où une étape secondaire peut être silencieusement omise après que l'étape principale a été faite.

Une case **non applicable** au cas courant (ex. cap Resolved pas dépassé donc pas d'archivage, pas de reclassification de sévérité donc pas de titre amendé) est considérée cochée — la liste cible les omissions silencieuses, pas les opérations toujours requises.

### Audit (mode auto ou forcé)

- Findings appendés dans `## Pending` de `maintainability_findings.md` — un par finding produit (ou aucun si zone propre).
- Header `<!-- id_counters: ... -->` incrementé pour chaque préfixe utilisé.
- Ligne préfixée en tête de `maintainability_history.md` (`- YYYY-MM-DD — <zone> — N findings ...` ou `0 findings (clean)` si zone propre).
- Rolling trimmé : taille recalculée, lignes en surplus du bas supprimées.
- Si bootstrap a eu lieu : `.claude/maintainability_history.md` et `.claude/maintainability_findings.md` créés avec le contenu initial spécifié (cf. *Mode : audit > A. Bootstrap*).

### Double-check

- Section `Double-check (YYYY-MM-DD) :` ajoutée à l'entrée du finding ciblé.
- Si reclassification de sévérité validée : titre `### <ID> — <NEW-SEV> — <localisation>` modifié, attribut `Dimension` éventuellement ajusté.

### Update

- Chaque pending re-vérifié (lecture du fichier + check par-dimension).
- Résolus détectés déplacés vers `## Resolved` au format compact.
- Stales détectés taggés `Status: stale` ; `stale-after-<ID>` existants préservés (pas écrasés).
- Lignes `maintainability_history.md` correspondantes complétées (`(résolus <ID>+...)`).
- Cap Resolved appliqué : si > cap après les moves, archivage automatique vers `maintainability_resolved_archive.md` jusqu'à ramener au cap.
- Header `<!-- id_counters: ... -->` recomputed (self-heal en re-scannant findings + archive).

### Résolution intra-session (cycle de vie étape 3)

- Entrée déplacée Pending → Resolved au format compact (Observation, Reco, Δ initial, Status, Double-check droppés).
- Bullet `Resolution :` complète (description + `Δ LoC mesuré : <valeur>` + `Commit : <hash>`).
- `(résolu YYYY-MM-DD)` ajouté au titre.
- Ligne history correspondante mise à jour (`(résolus <ID>+...)`).
- **Re-vérification en cascade déclenchée** sur les pendings overlap diff (cf. section dédiée).
- Cap Resolved respecté (archivage si débordement après le move primaire + cascadés).

### Re-vérification en cascade

- Diff capté via `git show --name-only <hash>` (ou cascade explicitement sautée avec annonce *"Cascade re-check sautée : pas de commit identifié pour `<ID>`"* si pas de hash).
- Candidats filtrés par overlap diff (zéro candidat → sortie silencieuse, aucune écriture).
- Cascade-resolved déplacés vers `## Resolved` au format compact avec `Resolution :` adapté (résolu collatéralement par fix de `<ID-primaire>`).
- Stale-after-`<ID>` taggés (bullet `Status` remplacée).
- Lignes `maintainability_history.md` complétées pour chaque cascade-resolved (via `Détecté` lu avant le move).
- Cap Resolved respecté (archivage si débordement après les cascadés).

### Archive-clear

- Archive réécrite avec les seules entrées `kept` (ou fichier supprimé si `kept = []` cas `--all`).
- Header `<!-- id_counters: ... -->` recomputed **avant** la suppression (les IDs futurs continuent monotonement).
- Pas d'écriture sur `maintainability_history.md` ni sur `## Pending` / `## Resolved` du findings file.

### List

Aucune écriture attendue — vérifier qu'aucun fichier projet n'a été modifié pendant le mode (read-only strict).

### Si une case n'a pas pu être cochée

Si une condition empêche une écriture attendue (e.g. tests KO bloque le marquage Resolution dans `fix B<n>`, fichier en lecture seule, conflit de merge dans le findings file) : **annoncer en chat** ce qui n'a pas pu être fait et pourquoi, plutôt que rendre la main silencieusement. L'utilisateur doit savoir qu'un état partiel existe.

## Edge cases

### Reclassification
Si un finding s'avère mal catégorisé (e.g. `DUP-007` est en réalité un problème de complexité, pas de duplication) :
- **Garder l'ID.** `DUP-007` reste `DUP-007`.
- Ajouter une bullet `Note: Reclassifié sémantiquement vers CPX, ID conservé pour traçabilité`.
- Optionnel : ajuster la dimension dans la bullet `Dimension`.

### Fichier déplacé / refactoré entre audits
La logique stale de *Mode : update > Flux* (étape 2.b et étape 4) s'applique aussi en `double-check` quand l'ID référencé pointe vers un fichier disparu.

### Doublons potentiels
Si un audit produit un finding qui ressemble fortement à un finding pending existant (même fichier, même pattern) :
- Ne pas créer de doublon. Référencer l'ID existant dans le résumé chat : *"DUP-007 toujours présent — pas re-comptabilisé."*
- Rafraîchir éventuellement la date de détection sur l'entrée existante.

### Conflit de prefix
Si l'utilisateur a manuellement utilisé un préfixe inhabituel (e.g. `XXX-001`) dans le findings file, le skill le respecte et continue à incrémenter dans cette série si pertinent. Aucun "rebasage" automatique.
