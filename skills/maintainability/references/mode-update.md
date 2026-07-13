# Mode : update

Référence chargée par SKILL.md en mode **update**. **Pas d'audit nouveau.** Re-vérifie tous les pendings contre l'état actuel du code et met à jour les statuts. Les conventions transverses (date déterministe, écritures en delta) vivent dans SKILL.md et s'appliquent ici.

## Flux

1. Lire `maintainability_findings.md`. Itérer sur chaque entrée de la section `## Pending`.
2. Pour chaque finding :
   a. Lire le fichier référencé en localisation.
   b. **Si le fichier est introuvable** (déplacé, supprimé, renommé) — passer en **investigation self-heal** avant de conclure. Utiliser les outils à disposition selon le contexte (git history, lecture de diffs, recherche du pattern dans la codebase, cross-check avec history) ; pour `stale-after-<ID>`, le commit primaire est connu et fournit un signal direct. Trois issues :
      - **Pattern retrouvé clairement à un nouvel emplacement** (signal fort : rename git ≥50% similarité, ou pattern unique retrouvé à 1 endroit avec match clair sur l'observation) → proposer la relocalisation 1-touch (*"`<ID>` retrouvé à `<new-path>:<line>` (<signal utilisé>). Relocaliser ?"*). Si OK : amender le titre avec le nouveau path, reset du `Status` à `pending`, puis re-vérifier le pattern au nouveau path comme à l'étape 2.c.
      - **Pattern dissout** (suppression nette du pattern dans un commit identifiable, ou aucune trace ailleurs dans la codebase) → proposer marquer résolu (*"`<ID>` dissout par <commit / refactor>. Marquer résolu ?"*). Si OK : flux résolu standard (étape 3), `Resolution` cite le commit responsable si identifiable.
      - **Signaux insuffisants ou ambigus** (pattern trop vague pour scanner, hits multiples non discriminants, fichiers au nom voisin créant un risque de faux positif, observation reposant sur du contexte humain) → marquer `Status: stale` (ou préserver `stale-after-<ID>` déjà posé par la cascade — l'info de cause reste plus précieuse), traité à l'étape 4.
      
      **Seuil de confiance** : conclure seulement si le signal est fort. En cas de doute, retomber sur le tagging stale — l'esprit "pas de faux positif sur fichier au nom voisin" est préservé via cette calibration, pas via une interdiction blanche. Le choix des outils et leur enchaînement reste à la main de l'agent ; le skill spécifie l'intention et les contraintes, pas la procédure.
      
      **Refus utilisateur sur une proposition self-heal** (no à relocaliser ou no à résoudre) → traité comme un stale standard à l'étape 4 (3 options manuelles). Le `Status` reste `stale` (ou `stale-after-<ID>` selon ce qui est applicable).
   c. **Si le fichier existe** : vérifier que le pattern décrit dans l'observation est toujours présent à la localisation indiquée (ou nearby si les lignes ont bougé). Heuristique :
      - Lire les ~20 lignes autour de la localisation.
      - Si le pattern décrit (duplication, god file taille, etc.) est encore reconnaissable → status inchangé.
      - Si le pattern a disparu → bascule en Resolved.
      - **Finding multi-fichiers** (bullet `Localisation` listant plusieurs emplacements, typiquement issu d'un crosscut) : lire chacun, juger le pattern globalement. Pattern dissout sur tous les emplacements → Resolved. Pattern partiellement résolu (1 sur N occurrences clear, mais ≥ 2 restent) → status inchangé. Si seul reste 1 emplacement, traiter selon la dimension : `DUP` n'a plus de sens à 1 copie → Resolved ; `DRF`/`INC` peuvent persister à 1 emplacement si le drift / l'incohérence subsiste → status inchangé ; `ARC` (cycle, couplage) est résolu quand la **relation** structurelle est rompue (cycle cassé, dépendance inversée), pas quand un des fichiers change → juger sur la relation, pas sur les emplacements.
3. Pour chaque résolu détecté :
   - Déplacer l'entrée de `## Pending` vers `## Resolved` au **format compact** (cf. `references/file-formats.md > Format compact d'une entrée résolue`).
   - Ajouter `(résolu YYYY-MM-DD)` au titre.
   - La bullet `Resolution` indique `détecté résolu lors de update (YYYY-MM-DD). Δ LoC mesuré : <valeur>` (via `git log --since=<date> -- <fichier>` ou comparaison directe ; sinon `indéterminé`). Ajouter `Commit : <hash>` si un commit aval est identifiable.
   - Mettre à jour la ligne history correspondante (l'audit qui a créé ce finding) : ajouter ou compléter le `(résolus <ID>+...)`.
4. Pour chaque stale **non résolu par l'investigation self-heal** (générique ou `stale-after-<ID>` préservé) : laisser dans Pending. Le `Status` a déjà été ajusté à l'étape 2.b. Demander à l'utilisateur en chat — message adapté à la cause, et mentionnant brièvement pourquoi le self-heal n'a pas conclu :
   - Stale générique : *"`<ID>` référence un fichier introuvable, investigation inconclusive (`<raison-courte>`). Rouvrir avec nouveau path, marquer résolu (le pattern n'existe plus), ou archiver ?"*
   - Stale-after : *"`<ID>` est `stale-after-<ID-primaire>` depuis le fix du <YYYY-MM-DD>. Investigation inconclusive (`<raison-courte>`). Rouvrir avec nouveau path, marquer résolu, ou archiver ?"*
   - **Escalade des stales anciens** (borne de terminaison à la boucle d'arbitrage) : comparer la date de pose du `Status: stale (...)` / `stale-after-<ID> (...)` à la date courante (`date +%F`). Si elle dépasse **90 jours**, ne plus re-proposer les trois options à égalité : basculer vers un **défaut explicite d'archivage** — *"`<ID>` est stale depuis le <date-de-pose> (> 90 j sans résolution). J'archive (NO-GO : stale non résolu) sauf objection ?"*. L'utilisateur peut toujours rouvrir/relocaliser ; le but est d'éviter qu'un stale jamais tranché pollue le board indéfiniment. Sans escalade, un stale resterait Pending éternellement.
5. **Vérification de l'invariant cap Resolved** : compter les entrées de `## Resolved` après les moves. Si > 8, appliquer le flux d'archivage automatique (cf. `references/file-formats.md > Cycle de vie d'un finding` étape 5).
6. **Recompute des compteurs d'IDs** : re-scanner `maintainability_findings.md` + `maintainability_resolved_archive.md` (s'il existe), recalculer le max par préfixe, mettre à jour le header `<!-- id_counters: ... -->`. Self-heal contre drift.
7. **Réconciliation history → findings (lecture seule, signalement only).** Les deux fichiers de l'étape 6 sont déjà chargés ; à ce moment, vérifier que chaque ID présent en `## Resolved`/archive apparaît bien dans un `(résolus <ID>+...)` d'une ligne history, et inversement qu'aucune ligne history ne marque résolu un ID encore dans `## Pending`. **Aucune écriture corrective automatique** : en cas d'incohérence (matching date+zone ambigu, `(résolus …)` oublié ou posé sur la mauvaise ligne), le **signaler en chat** (*"history incohérent : `<ID>` est résolu mais aucune ligne history ne le marque — à corriger à la main"*). `(résolus …)` est purement informatif (n'alimente aucune logique de sélection), donc un simple signalement suffit ; la source de vérité reste `findings.md`.

## Sortie

Utiliser le template `update:summary`.

## Coût

Cette commande lit potentiellement beaucoup de fichiers (un par pending), plus les appels d'investigation self-heal sur les pendings dont le fichier est introuvable (git history, grep codebase, lecture de diffs ciblés). Acceptable car invocation rare et explicite — pas appelée à chaque audit. Le coût self-heal est proportionnel au nombre de stales rencontrés, pas au total des pendings.

## Détection intra-session

Indépendamment de la commande `update` explicite, **pendant la conversation qui suit un audit ou un double-check**, si l'utilisateur applique un fix qui résout un finding listé :

1. Le skill **exécute la re-vérification en cascade en lecture seule** (cf. `references/cascade.md`), puis propose la confirmation batchée via le template `resolution:confirm` — primaire + cascadés + stale-after en un seul prompt. Si overlap = 0 (aucun autre pending sur les fichiers du diff) : le template gère la variante simple sans bloc cascade.
2. Si l'utilisateur valide : applique le flux update sur le primaire (move Pending → Resolved, bullet `Resolution`, ligne history) **et** exécute les écritures cascade (cascade-resolved au format compact, stale-after taggés, lignes history complétées, cap Resolved respecté).
3. **Confirmer en chat** via le template `resolution:done` — détaillant les écritures effectuées. Si push-back partiel à l'étape 1 (l'utilisateur a refusé certains items) : la sortie reflète seulement ce qui a été appliqué.

Cette détection est **opportuniste, pas exhaustive**. Pour une re-vérification systématique après plusieurs fixes hors-session, l'utilisateur invoque le mode update.

## Invariants de fin de mode

Avant de rendre la main, valider (une case **non applicable** est considérée cochée ; cf. SKILL.md > *Invariants de fin de mode* pour la règle transverse).

### Update

- Chaque pending re-vérifié.
- Résolus détectés déplacés vers `## Resolved` au format compact.
- **Investigation self-heal exécutée** sur chaque pending dont le fichier est introuvable (cf. étape 2.b).
- **Stales auto-relocalisés** (signal fort de rename / nouvel emplacement) : titre amendé avec le nouveau path, `Status` reset à `pending`, pattern re-vérifié au nouveau path.
- **Stales auto-résolus** (pattern dissout, fix identifié) : déplacés vers `## Resolved` au format compact, `Resolution` cite le commit responsable si identifiable.
- Stales non résolus par investigation taggés `Status: stale` ; `stale-after-<ID>` existants préservés (pas écrasés). L'utilisateur arbitre à l'étape 4. **Stales > 90 j escaladés** vers un défaut d'archivage proposé (cf. étape 4) plutôt que re-proposés à l'identique.
- Lignes history correspondantes complétées (`(résolus <ID>+...)`).
- Cap Resolved appliqué (archivage automatique si > 8).
- Header `<!-- id_counters: ... -->` recomputed (self-heal en re-scannant findings + archive).
- **Réconciliation history → findings** exécutée en lecture seule (étape 7) ; toute incohérence signalée en chat (pas de correction auto).

### Résolution intra-session

Checklist du flux *Détection intra-session* ci-dessus (réutilisée par `references/mode-double-check.md` *Fix maintenant*, `references/mode-audit.md > I`, et `references/mode-list.md` `fix B<n>`) :

- Entrée déplacée Pending → Resolved au format compact.
- Bullet `Resolution :` complète (description + Δ LoC mesuré + Commit).
- `(résolu YYYY-MM-DD)` ajouté au titre.
- Ligne history correspondante mise à jour.
- Cascade re-check déclenchée si fix avec diff (cf. `references/cascade.md`).
- Cap Resolved respecté.
