# Format des fichiers projet

Référence chargée par SKILL.md quand le skill doit lire ou écrire un fichier d'état. Trois fichiers vivent dans le `<STATE_DIR>` résolu par SKILL.md. Format strict, à respecter à la lettre.

## Sommaire

- Historique : `maintainability_history.md`
- Findings actifs et résolus récents : `maintainability_findings.md`
- Archive : `maintainability_resolved_archive.md`
- Compteurs d'IDs
- Cycle de vie d'un finding

### Pourquoi markdown (choix délibéré)

L'état est en **markdown**, pas en JSON/binaire, **par choix** : lisible directement, **git-diffable** (chaque audit/résolution est un diff revue-able), et **éditable à la main** par l'utilisateur (le skill assume et anticipe cette édition — cf. *Compteur d'IDs > header absent* et la non-réutilisation d'ID après suppression manuelle). Un format opaque gagnerait un peu de robustesse de parsing mais perdrait ces trois propriétés, mauvais compromis pour un outil dont l'état doit rester inspectable. **Ne pas migrer vers JSON.** La robustesse de parsing est obtenue autrement : schéma de bullets stable (ci-dessous), écritures en delta (*SKILL.md > Conventions transverses*), et self-heal des compteurs.

## `<STATE_DIR>/maintainability_history.md`

**Journal d'audits append-only.** Une ligne par audit, **nouvelle entrée préfixée en tête de fichier** (ordre du plus récent au plus ancien). Le fichier n'est **jamais trimmé** — il accumule sur la durée de vie du projet.

```markdown
<!-- rolling_size: 5 -->        # optionnel : override la taille du rolling actif (cf. plus bas)
# Maintainability audit history

- 2026-05-03 — services/billing/refund/ — 6 findings (3 HIGH, 2 MED, 1 LOW) (résolus DUP-007+SIZ-003)
- 2026-05-01 — pipeline:order-processing [api/ingest.py, validators/order.py, enrichers/customer.py, store/orders.py] — 4 findings (1 HIGH, 3 MED) (pending)
- 2026-04-22 — core/api_handler.py — 8 findings (4 HIGH, 3 MED, 1 LOW) (pending)
- 2026-04-15 — services/auth/ — 3 findings (1 MED, 2 LOW) (résolus tous)
- 2026-03-30 — services/payments/ — 0 findings (clean)
- ... (ligne par audit, jamais tronqué)
```

### Règles de format

- Format ligne : `- YYYY-MM-DD — <zone> — N findings (X HIGH, Y MED, Z LOW) (status)`
- `<zone>` = chemin dossier (`services/billing/refund/`), chemin fichier (`core/api_handler.py`), `pipeline:<nom> [fichiers,…]`, ou `crosscut:<DIM>` (cf. *Lignes crosscut* plus bas). Le bracket fichiers n'apparaît QUE pour les pipelines.
- `(status)` : `(pending)`, `(résolus tous)`, ou `(résolus <ID>+<ID>+...)` quand certains seulement sont résolus.
- **Retrouver la bonne ligne** pour compléter `(résolus …)` : matcher sur la **paire exacte (date `Détecté` du finding + zone)**, pas sur la zone seule (une même zone peut avoir plusieurs lignes d'audit à des dates différentes ; un finding multi-fichiers issu d'un crosscut a pour origine une ligne `crosscut:<DIM>`). Si plusieurs lignes restent éligibles après ce matching, **le signaler en chat** plutôt que de deviner.
- Zone propre (0 findings) : ligne `- YYYY-MM-DD — <zone> — 0 findings (clean)`. **Écrire quand même cette ligne** — c'est ce qui mémorise que la zone a été examinée.

### Trois usages du fichier (à distinguer)

Le fichier sert à **trois choses** qui n'ont pas le même horizon de mémoire :

1. **Rolling actif** — les `N` audits les plus récents, à exclure des candidats au prochain audit pour éviter le ressassement. `N = clamp(round(Z / 4), 3, 10)` où `Z` = nombre de zones de l'inventaire courant. Override possible via `<!-- rolling_size: M -->` en tête de fichier.
2. **Couverture historique** — l'ensemble des zones **jamais auditées dans la vie du projet**, pour pondérer la sélection ("zones jamais auditées → priorité haute"). Construit en scannant **toutes** les lignes du fichier, pas seulement les `N` dernières.
3. **Datation par zone** — pour chaque zone, `last_audit_zone = max(date)` parmi les lignes history pointant cette zone. Sert au signal d'activité (`references/mode-audit.md > C. Signal d'activité`) : la sélection compare cette date à celle du dernier commit utilisateur du path pour classer la zone en `chaude` / `froide`.

Le fichier sert les trois usages depuis la même source. Le rolling est une **vue** des `N` premières lignes (les plus récentes) ; la couverture est l'**union** des zones de toutes les lignes ; la datation par zone est un **lookup** dans les lignes correspondantes.

### Pourquoi append-only

Trimmer le fichier à `N` lignes faisait perdre la couverture historique : sur un gros projet (40+ zones), après 11+ audits, des zones réellement auditées sortaient du fichier et redevenaient « jamais auditées » du point de vue de la pondération. Le skill re-proposait alors des zones déjà couvertes. Append-only règle ça sans coût significatif (un audit ≈ une ligne, 100 audits ≈ 100 lignes, lecture instantanée).

### Override `rolling_size`

Si `<!-- rolling_size: N -->` est présent en tête de fichier (avant le `#` header), **respecter cette valeur** au lieu du calcul auto, même si elle tombe hors `[3, 10]`. L'utilisateur sait ce qu'il veut ; le skill ne discute pas la valeur. L'override ne porte que sur la **taille du rolling actif** — il n'affecte ni la taille du fichier (toujours unbounded) ni le calcul de la couverture historique (toujours sur l'ensemble du fichier).

### Lignes crosscut

Le mode crosscut (cf. `references/mode-crosscut.md`) écrit ses propres lignes history avec un discriminateur `crosscut:<DIM>` au lieu d'un path de zone. Format :

```
- 2026-05-11 — crosscut:DUP — 4 findings (1 HIGH, 3 MED) (pending)
- 2026-03-08 — crosscut:BND — 0 findings (clean)
- 2026-02-19 — crosscut:DED — 2 findings (2 MED) (pending) [partiel : 8/23 zones]
```

**Annotation de couverture partielle** : quand le sweep n'a couvert qu'un échantillon de zones (fallback sans outil, cf. `references/mode-crosscut.md > C`), suffixer la ligne de `[partiel : N/M zones]`. L'annotation ne change ni l'extraction de `<DIM>` ni le rolling crosscut (la ligne y compte normalement — pas de re-proposition immédiate de la même dimension) ; elle mémorise qu'un `0 findings (clean)` échantillonné n'est pas un clean complet et qu'un sweep outillé reste pertinent sur cette dimension.

Ces lignes sont **filtrées différemment** selon l'usage :

- **Rolling actif zonal** et **couverture historique zonale** (usages 1 et 2 ci-dessus) : ignorent les lignes `crosscut:*`. Le rolling zonal ne consomme pas de slot quand un crosscut est exécuté.
- **Rolling crosscut** (nouvel usage) : ne lit **que** les lignes `crosscut:*`, extrait `<DIM>`, conserve les `Nx = 6` plus récentes pour exclure ces dimensions du prochain crosscut auto. Override possible via `<!-- crosscut_rolling_size: M -->` en tête de fichier.

`Nx = 6` est fixé en dur (contrairement au `N` zonal qui est calculé sur la taille de l'inventaire). C'est précisément le nombre de dimensions éligibles par défaut (`DUP`, `INC`, `DRF`, `DED`, `BND`, `ARC`) — le rolling se remplit après 6 crosscut, puis le cas dégénéré "toutes dans le rolling" (cf. `references/mode-crosscut.md > B`) prend la moins récemment crosscutée. Effet net : un round-robin naturel et prévisible sur les 6 dimensions, plutôt qu'un aléatoire pondéré qui revient deux fois sur la même dimension sur une fenêtre courte.

## `<STATE_DIR>/maintainability_findings.md`

Source de vérité des findings. Deux sections (`## Pending`, `## Resolved`) plus un header de compteurs d'IDs.

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

### Règles de format

- En-tête entrée : `### <ID> — <SÉVÉRITÉ> — <localisation>` (avec `(résolu YYYY-MM-DD)` ajouté pour les Resolved).
- `<localisation>` = `path:line` ou `path:start-end` ou juste `path` (pour les god files).
- **Findings multi-fichiers** (typiquement issus du mode crosscut, `references/mode-crosscut.md`, mais possibles aussi en audit zonal si l'observation pointe naturellement vers plusieurs lieux) : `<localisation>` du titre = fichier *primaire* (occurrence majoritaire, ou premier alphabétiquement à égalité) ; la bullet `Localisation` énumère tous les fichiers/lignes impliqués (le champ accepte plusieurs lignes ou une énumération `path1:line, path2:line, …`).
- **Pending** — bullets dans cet ordre : Dimension, Localisation (multi-fichiers uniquement), Observation, Reco, Δ LoC, Détecté, Status, puis sections optionnelles (Double-check — toujours **après** `Status`). Valeurs de `Status` :
  - `pending` (initial),
  - `stale (YYYY-MM-DD) — <raison>` (posé par `update` quand le fichier est introuvable **et** l'investigation self-heal est inconclusive ; cf. `references/mode-update.md > étape 2.b`),
  - `stale-after-<ID> (YYYY-MM-DD) — <raison>` (posé par la cascade quand le fix de `<ID>` invalide la localisation ; peut être résolu ou relocalisé au prochain `update` par self-heal).
- **Resolved** — format compact à 3 bullets : Dimension, Resolution, Audit origin. Voir *Format compact d'une entrée résolue* ci-dessous.
- L'ID est immuable. Tout autre attribut peut être amendé.
- Le header `<!-- id_counters: PREFIX=N, ... -->` cache les compteurs d'IDs pour assignation rapide (cf. *Compteur d'IDs*). Absent dans un fichier fraîchement bootstrappé ; ajouté à la première assignation d'ID.
- **Cap Resolved = 8** (valeur canonique unique du skill). La section `## Resolved` est cappée à 8 entrées ; les plus anciennes sont déplacées vers `maintainability_resolved_archive.md` automatiquement (cf. *Cycle de vie d'un finding* étape 5).

### Format compact d'une entrée résolue

À chaque move vers `## Resolved` (intra-session, update, NO-GO post double-check). **Drop** : Observation, Reco, Δ initial, Status, Double-check. **Conserver** : 3 bullets fixes :

```markdown
### DUP-011 — LOW — crates/bot/src/web.rs (résolu 2026-05-06)
- **Dimension :** duplication scaffolding vault
- **Resolution :** Helper `vault_blocking<F,T>` ajouté, 4 sites migrés. Δ LoC mesuré : -30. Commit : 86518fb.
- **Audit origin :** 2026-05-05 (crates/bot/src/web.rs)
```

`Resolution` doit contenir : description courte du fix + `Δ LoC mesuré : <valeur>` + `Commit : <hash>` (ou `Commits : <h1>+<h2>`). **Fix non commité au moment de la résolution** (cas normal : le skill ne commit jamais lui-même, cf. SKILL.md > Conventions transverses) : écrire `Commit : non commité` — jamais un hash inventé ; un `update` ultérieur peut compléter le hash s'il devient identifiable (cf. `references/mode-update.md > étape 6`). `Audit origin` reprend la date et la zone de l'audit qui a produit le finding.

**Cas NO-GO archivé** (cf. `references/mode-audit.md > H. Proposition de double-check autonome`) : `Resolution` cite la raison du NO-GO en 1-2 phrases ; `Δ LoC : N/A (NO-GO)` remplace le Δ mesuré.

Les entrées Resolved en format verbose **existantes** restent valides — pas de re-écriture rétroactive.

## `<STATE_DIR>/maintainability_resolved_archive.md`

Cold storage pour les entrées de `## Resolved` qui débordent du cap. **Jamais lu par défaut** : le skill ne le charge que pendant `update` (recompute des compteurs d'IDs) et `archive-clear`. Création paresseuse au premier débordement.

```markdown
# Maintainability resolved archive

### DUP-001 — MED — services/auth/login.py:23 (résolu 2026-04-16)
- **Dimension :** duplication de code
- **Resolution :** Extrait vers `services/auth/_helpers.py`. Δ LoC mesuré : -32. Commit : a7b3d12.
- **Audit origin :** 2026-04-15 (services/auth/)

### CPX-002 — HIGH — core/api_handler.py:88 (résolu 2026-04-22)
- ...
```

### Règles de format

- Pas de section `## Pending` / `## Resolved` (le fichier entier est l'équivalent d'un `## Resolved` géant).
- Entrées au format strict identique à celles de `## Resolved` du fichier findings (titre + 3 bullets compactes, déplacées intactes — la compaction a déjà eu lieu au move vers `## Resolved`). Des entrées **verbose héritées** (archivées avant l'introduction du format compact) peuvent subsister — valides, pas de réécriture rétroactive.
- Append-only en fin de fichier (l'ordre = ordre chronologique des résolutions, du plus ancien au plus récent).
- Les IDs des entrées archivées restent référencés dans `maintainability_history.md` (lignes `(résolus DUP-001+...)`) — pas de mise à jour à faire dans history lors de l'archivage.
- Lecture explicite uniquement par l'utilisateur (`grep`, ouverture éditeur, ou demande conversationnelle "regarde l'archive et …"). Pas de mode dédié dans le skill.

## Compteur d'IDs (header cached)

Le fichier `maintainability_findings.md` porte un header en commentaire HTML qui cache le max assigné par préfixe :

```markdown
<!-- id_counters: DUP=12, CPX=8, SIZ=5, INC=4, DRF=2, BND=1, TST=2, DOC=4, DED=4, CFG=1 -->
```

**Assignation d'un nouvel ID** : lire le compteur pour le préfixe dans le header, **le recaler sur la donnée réelle avant d'incrémenter** : `compteur_effectif = max(valeur_header, plus grand NNN observé pour ce préfixe dans le fichier findings)`, puis incrémenter, écrire le finding avec ce nouvel ID, mettre à jour la ligne header. Le scan du seul fichier findings suffit à éviter une **collision active** (deux entrées vivantes partageant un ID) si le header a dérivé après une édition manuelle — coût quasi nul, le fichier findings est déjà en contexte. L'archive n'a pas besoin d'être relue à ce moment (les IDs archivés sont couverts par le recompute self-heal d'`update`/`archive-clear`, qui scanne les deux fichiers) : le header reste un **cache** de la donnée, jamais une source de vérité indépendante.

**Préfixe inédit** (premier finding d'une nouvelle dimension comme `LOG-`, `RAC-`, ou autre invention) : ajouter `<PREFIX>=1` au header.

**Header absent** (cas migration depuis un état pré-archive, ou édition manuelle qui l'a viré) : scan one-shot de `maintainability_findings.md` + `maintainability_resolved_archive.md` (s'il existe), calcul des max par préfixe, écriture du header. Coût ponctuel, jamais répété ensuite.

**Self-healing** : à chaque `update`, recompute des compteurs en re-scannant les deux fichiers. Avec `archive-clear`, ce sont les seuls moments où le skill lit l'archive — coût acceptable car les deux opérations sont rares et explicites.

Format : à 3 chiffres (`DUP-007`), peut grandir au-delà sans souci (`DUP-1042` reste lisible).

**Jamais de réutilisation d'ID**, même après suppression manuelle d'une entrée par l'utilisateur, et même après archivage. Le compteur monte monotonement. Si max trouvé = `DUP-005` mais l'utilisateur a supprimé `DUP-005`, le prochain est `DUP-006` (pas `DUP-005`).

## Cycle de vie d'un finding

1. **Création** lors d'un audit → entrée `## Pending` avec ID, dimension, sévérité, observation, reco, date, `Status: pending`.
2. **Double-check** (mode `double-check` avec `<ID>`) → ajoute une section `Double-check (date)` dans l'entrée existante. Peut amender la reco. Peut révéler un changement de sévérité (proposer à l'utilisateur, valider, puis amender l'attribut).
3. **Résolution intra-session** → quand l'utilisateur applique un fix dans la conversation qui suit un audit ou un double-check, le skill **propose** de marquer résolu :
   - Déplace l'entrée en `## Resolved` au **format compact** — Observation, Reco, Δ initial, Status, Double-check sont droppés.
   - Ajoute `(résolu YYYY-MM-DD)` dans le titre.
   - La bullet `Resolution` contient : description courte du fix + `Δ LoC mesuré : <valeur>` (mesurer via `git diff --stat` ou comptage direct ; faire la mesure dans le tour de conversation si possible) + `Commit : <hash>` du commit qui applique le fix.
   - Met à jour la ligne history correspondante : `(résolus DUP-007)` → `(résolus DUP-007+SIZ-003)` si plus d'un fix.
   - **Déclenche la re-vérification en cascade** sur les pendings dont la localisation chevauche le diff du fix (cf. `references/cascade.md`). Le résultat est intégré dans le **même prompt** de confirmation primaire.
4. **Update** (mode `update`) → re-vérifie chaque pending :
   - Pattern toujours présent → status inchangé.
   - Pattern absent → bascule en Resolved au format compact ; `Resolution` indique `détecté résolu lors de update (YYYY-MM-DD)` + Δ mesuré + `Commit : <hash>` si identifiable via `git log`.
   - Fichier disparu / déplacé → **investigation self-heal** (cf. `references/mode-update.md > étape 2.b`). Trois issues : pattern retrouvé ailleurs → relocalisation 1-touch ; pattern dissout → résolu auto avec commit cité ; signaux insuffisants → `Status: stale` (ou préservation de `stale-after-<ID>` posé par la cascade) puis arbitrage utilisateur.
5. **Archivage automatique** → après chaque move vers `## Resolved` (étapes 3, 4, ou *Cas NO-GO en autonomie* du mode audit) :
   - Compter les entrées de la section `## Resolved` du fichier findings.
   - Si > cap (8) : déplacer la (les) plus ancienne(s) vers `maintainability_resolved_archive.md` jusqu'à ramener le compte au cap. Ancienneté déterminée par la date `(résolu YYYY-MM-DD)` dans le titre — la plus petite date part en premier. Tie-break en cas d'égalité de date : ordre dans le fichier (la plus haute dans la section part en premier).
   - Si l'archive n'existe pas, la créer à la volée avec le header `# Maintainability resolved archive\n\n` puis appender l'entrée.
   - Append en fin d'archive (l'ordre d'archivage = ordre chronologique des résolutions).
   - L'entrée est déplacée intacte (la compaction a déjà eu lieu au move vers `## Resolved`).
   - Le header `<!-- id_counters: ... -->` du fichier findings n'est pas affecté (les IDs restent monotonement croissants).
