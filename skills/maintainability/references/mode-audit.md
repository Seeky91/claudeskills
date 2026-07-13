# Mode : audit

Référence chargée par SKILL.md en mode **audit auto** ou **audit forcé** avec un chemin. Les conventions transverses (date déterministe, écritures en delta) et la doctrine d'évaluation vivent dans SKILL.md et s'appliquent ici.

## Sommaire

- A. Bootstrap
- B. Inventaire des zones
- C. Sélection automatique
- D. Audit forcé
- E. Exécution
- F. Écritures
- G. Sortie en chat
- H. Proposition de double-check
- I. Action post-proposition
- Invariants de fin de mode

## A. Bootstrap (si `<STATE_DIR>/maintainability_*.md` absent)

1. Si `<STATE_DIR>` n'existe pas dans le projet : créer le dossier.
2. Si `maintainability_history.md` absent : créer avec `# Maintainability audit history\n\n`.
3. Si `maintainability_findings.md` absent : créer avec `# Maintainability findings\n\n## Pending\n\n## Resolved\n`. Pas de header `<!-- id_counters: ... -->` à ce stade (création paresseuse à la première assignation d'ID). Pas non plus de `maintainability_resolved_archive.md` (création paresseuse au premier débordement du cap Resolved).
4. Annoncer en chat : *"Bootstrap maintainability sur ce projet, aucun historique préalable."*
5. Continuer le flux d'audit normalement (pas de rolling à respecter).

## B. Inventaire des zones

Calculer à chaque audit (jamais persisté). Algorithme :

0. **Outil de comptage opportuniste (optionnel, dégradation gracieuse).** Avant la marche manuelle, tester `command -v scc || command -v tokei`. Si présent, l'**exécuter en JSON par fichier** (`scc --by-file -f json` ou `tokei -o json`) et en dériver l'inventaire : les outils donnent les LoC de **code réelles** (hors commentaires/blank), par fichier et par langage, en excluant nativement le vendored — exactement le découpage et la chasse aux god files recherchés ci-dessous, en un appel, sans lire le code (c'est la sortie qui entre en contexte, pas les fichiers). **Si aucun n'est présent** : repli sur la marche manuelle (étapes 1-6). L'outil n'est jamais une dépendance dure ; il remplace seulement l'estimation manuelle quand il est là. La détection des landmarks architecturaux (étape 5) reste à faire même si le comptage vient d'un outil : elle dépend du rôle des fichiers/symboles, pas seulement de leur taille.
1. **Walk de l'arbo** depuis la racine du projet.
2. **Pour chaque dossier**, mesurer le total LoC source (exclure `.json`, `.toml`, `.lock`, `.md`, dossiers `node_modules`, `.git`, `dist`, `build`, `vendor`, `target`, `.venv`, et tout ce qui ressemble à du généré).
3. **Règles de découpage** :
   - Dossier 200–2000 LoC → zone candidate.
   - Dossier > 2000 LoC → descendre dans ses sous-dossiers, appliquer la règle récursivement.
   - Dossier < 200 LoC → grouper avec son parent (ne pas le proposer seul).
   - **Échelle relative** : les seuils portent sur les LoC de **code** (hors commentaires/blank — naturel si l'inventaire vient de `scc`/`tokei`). Ce sont des défauts volontairement simples, pas une table par langage. Sur **très gros repo / monorepo**, viser un découpage où chaque zone tient dans un budget de lecture raisonnable plutôt que de s'accrocher aux 600/2000 LoC absolus : sous-découper un gros package par sous-module plutôt que de le marquer mécaniquement « trop gros ».
4. **Fichiers ≥ 600 LoC source** (peu importe leur dossier) → zone autonome additionnelle. Chasse les god files même quand ils sont noyés dans un dossier raisonnable.
5. **Landmarks architecturaux (taille ignorée)** : ajouter comme zones candidates les fichiers ou plus petits dossiers propriétaires qui portent une composition root ou une façade structurante, même sous 200 LoC. Exemples stack-agnostiques : entrypoint applicatif (`main`, `app`, `server`, CLI/worker), bootstrap/init/start d'un sous-système, builder/factory qui assemble plusieurs dépendances concrètes, router/API composer, façade publique qui stabilise l'API/boundary d'un module, assembly de pipeline. La zone reste un **path réel** (fichier ou dossier), pas un nouveau type d'history. Si plusieurs landmarks appartiennent au même petit composant, les grouper dans le plus petit dossier propriétaire plutôt que créer 10 micro-zones. Borne anti-bruit : ne retenir que les landmarks qui assemblent ≥3 dépendances/sous-systèmes, fixent une politique de lifecycle, ou sont fortement importés/modifiés ; ignorer les helpers `init_*` triviaux et les simples barrels/réexports sans responsabilité propre. **Exception assumée à la règle `<200 LoC` (étape 3)** : un landmark sous le seuil est proposé pour lui-même au lieu d'être fondu dans son parent ; il peut donc coexister avec la size-zone qui le contient (`src/main.rs` comme landmark **et** dans la zone `src/`) — clés d'history distinctes, voulu : la zone-landmark fait un audit ciblé sur le rôle (lentille `E.1quater`), pas un re-scan du dossier entier.
6. **Mesure LoC source** (marche manuelle uniquement — sauté si l'étape 0 a fourni le compte) : compter les lignes non vides hors lignes-commentaires pures. Approximation acceptable, pas besoin d'AST.
7. **Pipelines candidats** : si en parcourant l'arbo le skill identifie un flux de données traçable (un point d'entrée qui appelle 3-5 fichiers en chaîne), il peut le proposer comme zone `pipeline:<nom>` avec la liste explicite des fichiers. Si le skill n'arrive pas à nommer le pipeline et ses fichiers concrètement, il **n'inclut pas** de pipeline dans les candidats — on n'invente pas de pipeline pour cocher la case. *Optionnel* : si un outil de graphe d'imports est déjà présent dans le repo (`madge --json` JS/TS, `go list -deps`, `pydeps`), s'en servir pour confirmer la fermeture réelle des dépendances autour de l'entry point (capte les imports indirects / l'injection que la lecture à l'œil rate) ; sinon, repli sur le repérage manuel via les imports lus en tête de fichier, l'abstention ci-dessus restant la règle.

`Z` = nombre total de zones candidates issu de cet inventaire.

## C. Sélection (mode auto, args vides)

L'historique sert **trois usages distincts** qui ont des horizons de mémoire différents — la sélection les exploite séparément :

1. **Lire `maintainability_history.md` en entier.** Parser toutes les lignes `- YYYY-MM-DD — <zone> — …` et extraire les zones (les lignes `crosscut:*` sont ignorées pour la sélection zonale).
2. Calculer `N = clamp(round(Z / 4), 3, 10)` (override possible via `<!-- rolling_size: M -->` en tête de history).
3. Construire deux vues sur les zones parsées :
   - **`rolling_actif`** = les `N` zones les plus récentes (les `N` premières lignes du fichier, qui est en ordre prepend = newest-first).
   - **`zones_jamais_auditees`** = `inventaire − {toutes les zones apparaissant dans le fichier, sans limite de date}`.
4. **Calculer le signal d'activité par zone** (cf. *Signal d'activité* ci-dessous). Pour chaque zone de l'inventaire, classer en :
   - **`jamais_auditee`** — zone absente de tout history.
   - **`chaude`** — zone auditée, avec `last_touch_hors_maintainability > last_audit_zone`. Du code utilisateur a bougé depuis le dernier audit.
   - **`froide`** — zone auditée, sans activité hors-maintainability depuis le dernier audit.
5. **Candidats** = `inventaire − rolling_actif`.
6. **Pondération à trois niveaux** :
   - **Top** : candidats `jamais_auditee` → couverture neuve, priorité absolue.
   - **Haute** : candidats `chaude` → la zone vient de bouger, le re-audit a un ROI élevé (nouveau code à examiner).
   - **Basse** : candidats `froide` → re-audit légitime mais marginal (la zone n'a pas changé hors fixes maintainability).
   
   Sélection : prendre le niveau le plus haut non vide, puis **départager de façon déterministe** (reproductible et auditable via l'history) — `last_audit_zone` la plus ancienne d'abord (les `jamais_auditee` n'en ont pas → considérées comme les plus anciennes), puis, à égalité résiduelle, **ordre alphabétique du chemin de zone**. Ce départage étale quand même la couverture (chaque zone finit par devenir la plus ancienne) tout en restant reproductible d'un run à l'autre. Le niveau bas n'est jamais bloqué — il est juste consulté en dernier. Si l'utilisateur veut auditer une zone froide, il invoque le mode audit avec un chemin explicite.
7. **Visée pipeline ~30%** : si des candidats `pipeline:` existent et qu'on n'a pas audité de pipeline récemment (rolling), augmenter leur pondération pour atteindre approximativement 30 % des audits sur la durée. La visée pipeline se cumule avec la pondération d'activité — un pipeline chaud reste prioritaire sur un pipeline froid.
8. **Landmarks architecturaux** : les candidats issus de `B.5` participent à la pondération normale (jamais audités / chauds / froids). Ne pas leur donner une priorité absolue permanente : leur intérêt vient de leur rôle central, mais le rolling et l'activité continuent de protéger contre le ressassement. Leur motif d'annonce est `landmark architectural` ou plus précis (`composition root locale`, `façade publique structurante`, `bootstrap sous-système`).
9. **Annonce en chat** : utiliser le template `selection:proposition` (cf. `references/templates.md`). Le `<motif>` reflète à la fois la couverture (`jamais auditée`, `god file`, `pipeline traçable`, `landmark architectural`) et le signal d'activité (`chaude — <N> commits depuis le dernier audit`, `froide — auditée le YYYY-MM-DD, aucune activité hors-maintainability depuis`).
10. **Validation utilisateur** : accepter, demander une alternative listée, ou imposer un autre chemin. Attendre avant de lancer l'audit.

**Pourquoi cette séparation** : trimmer history (ancien comportement) faisait perdre la couverture historique. Sur gros projet (40+ zones), après 11+ audits, des zones réellement auditées sortaient du fichier et redevenaient « jamais auditées » du point de vue de la pondération — le skill re-proposait alors des zones déjà couvertes. History est désormais append-only ; le rolling est une vue sur les `N` premières lignes, la couverture est sur le fichier entier, et le signal d'activité prévient le second mode de bouclage (rester collé aux mêmes quelques zones non-rolling sur un gros projet où l'aléatoire pondéré seul ne suffit pas à pousser vers les zones effectivement modifiées).

### Signal d'activité

Croise les modifications réelles du code (commits utilisateur) avec l'historique des audits, pour pousser la sélection vers les zones où auditer apporte vraiment quelque chose.

**a. Identifier les commits maintainability** (à exclure du calcul d'activité — ils ne reflètent pas un changement utilisateur) :
- Scanner `maintainability_findings.md` (sections Pending **et** Resolved) : extraire tous les hashes après `Commit : ` ou `Commits : ` (un hash, ou plusieurs séparés par `+`).
- Scanner `maintainability_resolved_archive.md` s'il existe : pareil.
- Set `commits_maintainability` = union des hashes extraits (typiquement courts, 7–8 chars).

**b. Calculer `last_touch_hors_maintainability` par zone candidate** :
- Pour une zone simple (dossier ou fichier) : `git log --format=%H %cI -- <path>` puis filtrer les lignes dont le hash **commence par** un des hashes de `commits_maintainability` (matching par préfixe, car le set contient des hashes courts alors que `%H` est long). `last_touch = max(date)` parmi les restants.
- Pour un pipeline (`pipeline:<nom>` avec fichiers explicites) : appliquer le calcul sur l'union des fichiers, `last_touch = max` sur tous.
- Si aucun commit non-maintainability n'existe pour la zone (zone introduite uniquement par des fixes maintainability, cas rare) : `last_touch = epoch`. La zone tombera naturellement en `froide` au point c. — cohérent.
- **Si le repo n'est pas un git repo** (`.git/` absent au root) : sauter le signal d'activité, retomber sur la pondération à deux niveaux historique (jamais auditée = haute, sinon aléatoire). Annoncer *"Repo non-git : signal d'activité indisponible, pondération en mode dégradé."*

**c. Calculer `last_audit_zone` par zone** :
- Scanner les lignes history (hors `crosscut:*`) dont la zone matche exactement (chemin exact, ou `pipeline:<nom>` avec même nom).
- `last_audit_zone = max(date)` parmi ces lignes. Pour une zone dans `zones_jamais_auditees`, ce calcul est inutile (la zone est top de toute façon).

**d. Classement** :
- `jamais_auditee` ssi zone dans `zones_jamais_auditees`.
- Sinon `chaude` ssi `last_touch > last_audit_zone`. **Comparer au jour** (`last_touch` est un timestamp complet, `last_audit_zone` une date) ; **égalité de jour → `chaude`** : impossible de savoir si le commit précède ou suit l'audit du même jour, et sur-prioriser une zone est le biais le moins coûteux (le rolling protège de toute façon les zones auditées récemment).
- Sinon `froide`.

**Coût** : un `git log` par zone candidate. Sur Z = 40 zones, ~40 appels — quelques secondes en sélection auto, négligeable face au coût de l'audit lui-même. Sur Z > 80, le coût devient sensible ; à ce stade, le signal reste utile mais le skill peut limiter à un échantillon des top 30 zones par taille LoC (les zones < 200 LoC ont déjà été regroupées en *Inventaire des zones*, donc le filtre par taille est naturel).

### Cas dégénérés de la sélection

- **Candidats vides** (typiquement petit projet avec un override `rolling_size` qui exclut tout) : relâcher le rolling, choisir la zone la moins récemment auditée parmi **toutes** les zones de l'inventaire. Annoncer *"Toutes les zones sont dans le rolling — j'ai pris la moins récente : `<zone>` (auditée 2026-04-22)."* À égalité, ordre alphabétique du chemin (même départage déterministe que C.6).
- **Toutes les zones candidates sont froides** : le niveau bas est consulté, choisir la `froide` la moins récemment auditée (à égalité, ordre alphabétique du chemin). Annoncer *"Aucune zone modifiée depuis son dernier audit — re-audit d'une zone froide : `<zone>` (auditée le YYYY-MM-DD, sans activité depuis)."* Pas de blocage — l'audit a toujours un sens, ne serait-ce que pour approfondir.
- **Inventaire vide** (`Z = 0`) : abort avec *"Aucune zone auditable détectée (chaque dossier fait < 200 LoC source ou est exclu). Le projet est-il vide, ou veux-tu auditer manuellement un chemin précis ?"*
- **Une seule zone candidate après exclusion** : pas d'alternatives à proposer, annoncer la zone unique et demander si on lance.

## D. Audit forcé (mode `<path>`)

0. Si bootstrap nécessaire (`<STATE_DIR>/maintainability_*.md` absent) : suivre la section *A. Bootstrap* avant les étapes ci-dessous.
1. Vérifier que le chemin existe dans le projet courant.
2. Mesurer la taille de la zone (LoC source agrégée).
3. **Si > 5000 LoC** : refuser un audit aveugle. Annoncer la taille, proposer un sous-scope (ex. *"trop large à 6200 LoC. Sous-scopes possibles : `<path>/sub1/`, `<path>/sub2/`"*) et demander confirmation. L'utilisateur peut forcer s'il insiste, en sachant que l'audit sera moins profond.
4. Sinon : audit direct, pas de sélection auto.

## E. Exécution de l'audit

Pour la zone validée :

1. **Lire le code de la zone** intégralement (tous les fichiers source dans le scope).
1bis. **Indices outillés (optionnel, dégradation gracieuse).** Avant l'examen au jugement, si des outils de détection déterministes sont présents dans l'environnement, les exécuter sur la zone pour obtenir des candidats précis et localisés (duplication, exports morts, complexité, god files). Cf. `references/dimensions.md > Outils de détection opportunistes` pour la cartographie outil↔dimension et la posture (l'outil fournit le **rappel et la localisation** ; l'agent garde le **jugement** — produire ou non le finding, sévérité, trade-off check). **Aucune dépendance dure** : outil absent → repli sur la lecture/jugement de l'étape 2. L'outil ne décide jamais à la place de l'agent.
1ter. **Frontière d'imports (pour `ARC`).** L'audit zonal lit la zone, mais le couplage ne se voit qu'à sa frontière : compléter par les imports entrants/sortants de la zone (`rg` des imports, ou graphe si outil présent), **sans lecture intégrale hors zone**. La cohésion (feature envy, sur-fragmentation, abstraction locale) se juge ici ; le couplage profond inter-zones (cycles, co-change, instabilité × churn) relève du crosscut `ARC` (cf. `references/dimensions.md > Cadrage de la dimension ARC`).
1quater. **Lentille composition root / niveau d'abstraction (pour `ARC`).** Si la zone contient un landmark architectural (cf. `B.5`), examiner les composition roots qu'elle possède — pas seulement l'entrypoint applicatif, aussi les roots locales de sous-systèmes. Cf. `references/dimensions.md > Composition roots et niveau d'abstraction` pour le principe (niveau d'abstraction uniforme), la barre de friction concrète exigée, et la reco bornée (constructeur/factory possédé par le sous-système, anti-wrappers).
2. **Examiner systématiquement toutes les dimensions** du catalogue (cf. `references/dimensions.md`). Pour chacune :
   - Chercher des occurrences concrètes du pattern dans la zone.
   - Pour chaque occurrence : observer (fait vérifiable, fichier:ligne, contexte), évaluer la sévérité (impact × exposition, cf. `references/quality.md > Grille de sévérité`), **estimer le Δ LoC** que produirait l'application de la reco (cf. `references/quality.md > Estimation Δ LoC`).
   - **Appliquer le trade-off check** avant de produire (cf. `references/quality.md > Quand ne PAS produire de finding`) — performance, sécurité, scalabilité, lisibilité paradoxale. Si le trade-off est significatif, ne pas produire ; sinon, annoter dans `Reco`.
   - **Ne pas forcer la production de findings.** Une dimension peut très bien produire 0 finding si le code est propre sur cet axe.
3. **Si un problème réel ne colle à aucune dimension** : créer un nouveau préfixe 3 lettres (cf. `references/dimensions.md > Seed des dimensions`). Documenter brièvement dans le finding pourquoi cette nouvelle catégorie.
4. **Assignation des IDs** : suivre le mécanisme de `references/file-formats.md > Compteur d'IDs` (lire le header `<!-- id_counters: ... -->`, **le recaler sur le plus grand NNN réellement présent dans findings avant d'incrémenter** — garde-fou anti-collision si le header a dérivé, mettre à jour la ligne header). Format à 3 chiffres (`DUP-007`).

## F. Écritures (append-only)

1. **Append des findings** dans `## Pending` de `maintainability_findings.md`. Format strict cf. `references/file-formats.md`.
2. **Préfixer une nouvelle ligne en tête** de `maintainability_history.md` :
   ```
   - YYYY-MM-DD — <zone> — N findings (X HIGH, Y MED, Z LOW) (pending)
   ```
3. **Pas de trim.** History est append-only — le fichier accumule sur la durée de vie du projet. La taille du rolling actif `N` est appliquée à la lecture (vue sur les `N` premières lignes), jamais à l'écriture.

### Cas zone propre (0 findings)

Si l'audit produit zéro finding (zone réellement clean sur toutes les dimensions) :

- **Écrire quand même la ligne history**, format adapté :
  ```
  - YYYY-MM-DD — <zone> — 0 findings (clean)
  ```
- Ne **rien appender** dans `maintainability_findings.md` (pas de pending à créer).
- Sortie en chat : utiliser le template `audit:clean`.

L'écriture de la ligne history est **importante** : sans elle, la zone serait re-proposée trop tôt et la couverture historique perdrait l'info que la zone a été examinée.

## G. Sortie en chat (post-audit)

- Audit avec findings → template `audit:summary`.
- Audit sans finding (zone propre) → template `audit:clean`.
- Suite : la proposition de double-check autonome (cf. H ci-dessous).

## H. Proposition de double-check autonome (post-audit)

Après le résumé en chat, si l'audit a produit ≥ 1 finding, proposer trois options à l'utilisateur via le template `audit:proposition` (3 options : quick-wins / heavy / rien), puis attendre sa réponse.

**Critères de sélection des panels** :

- **(a) Quick-wins** : panel de 3 à 5 findings « bas effort, fix direct ».
  - Sévérité LOW en priorité, complétée par des MED si nécessaire pour atteindre 3.
  - `|Δ LoC|` faible (≤ 30) ou reco mono-fichier sans blast radius identifiable.
  - **Pas de finding HIGH dans ce panel** — un HIGH n'est jamais un quick-win.
- **(b) Heavy finding** : un seul finding, le plus structurant.
  - Sévérité HIGH en priorité (sinon le MED de plus large scope).
  - Plus large scope d'abord : god file > duplication structurante 3+ > drift transverse > complexité locale.
  - Tie-break : `|Δ LoC|` estimé le plus élevé.
- **(c) Rien** : l'utilisateur verra plus tard.

**Cas dégénérés** :

- 0 finding : ne pas afficher cette proposition (déjà couvert par le cas zone propre).
- 1 ou 2 findings : remplacer par le template `audit:proposition-min` (question simple sur 1 ID).
- Aucun candidat ne tient les critères de quick-win (e.g. tous les findings sont HIGH avec gros blast radius) : ne proposer que (b) et (c).
- Aucun finding HIGH ni MED de gros scope : pour (b), proposer le finding au plus grand `|Δ LoC|` estimé, en avertissant que ce n'est pas un finding « lourd » au sens classique.

**Exécution selon le choix utilisateur** :

- **(a) Quick-wins** : pour chaque finding du panel, exécuter le flux de `references/mode-double-check.md` (lecture du fichier, trace, blast radius, Δ LoC affiné, reco affinée, verdict). Écrire la section `Double-check (date)` dans chaque entrée du fichier findings. **Sortie agrégée** via `double-check:autonomous-batch`, suivie de `double-check:autonomous-batch-proposition` (cf. *I. Action post-proposition batch* ci-dessous).
- **(b) Heavy finding** : exécuter le flux de `references/mode-double-check.md` sur le finding sélectionné. Sortie complète via `double-check:output` standard, suivie de `double-check:proposition` (cf. `references/mode-double-check.md > Action selon le choix utilisateur`).
- **(c) Rien** : terminer la commande. Aucune écriture supplémentaire.

## I. Action post-proposition batch

Déclenché par la proposition `double-check:autonomous-batch-proposition` (suite à `(a) Quick-wins` ci-dessus ou à `double-check B<n>` depuis `references/mode-list.md`). Selon le choix utilisateur :

- **Fix tous les GO** :
  1. Établir l'ordering (règles dans `references/templates.md > double-check:autonomous-batch-proposition`).
  2. Plan par finding (1-3 lignes : fichiers touchés, ordre, Δ LoC attendu) — réutilise `Reco affinée`.
  3. Plan global affiché, OK explicite. Si OK, exécuter dans l'ordre.
  4. Avant chaque marquage `Resolution`, lancer la suite de tests. Tests OK → flux résolution intra-session. Tests KO → arrêt, ne pas marquer.
  5. Cascade re-check automatique après chaque résolution (cf. `references/cascade.md`).
  6. Si variante mix GO+NO-GO : archiver les NO-GO restants dans la foulée (move Pending → Resolved compact, `Resolution: archivé après double-check (NO-GO motivé : <raison>)`, lignes history complétées, cap Resolved respecté).
  7. Récap final via `cascade:recap-batch`.
- **Fix un seul** : étapes 2-5 ci-dessus sur le finding choisi.
- **Archiver les NO-GO** (variante mix, archive partielle) ou **Archiver tous** (variante tous NO-GO) : pour chaque NO-GO, move Pending → Resolved au format compact, `Resolution: archivé après double-check (NO-GO motivé : <raison>)`, ligne history complétée. Cap Resolved respecté.
- **Rien** / **Garder pending** : terminer sans écriture supplémentaire.

## Invariants de fin de mode (audit auto ou forcé)

Avant de rendre la main, valider (une case **non applicable** au cas courant est considérée cochée ; cf. SKILL.md > *Invariants de fin de mode* pour la règle transverse) :

- Findings appendés dans `## Pending` de `maintainability_findings.md` — un par finding produit (ou aucun si zone propre).
- Header `<!-- id_counters: ... -->` incrémenté pour chaque préfixe utilisé.
- Ligne préfixée en tête de `maintainability_history.md`. **Pas de trim** — history est append-only.
- Si bootstrap a eu lieu : fichiers `<STATE_DIR>/maintainability_*.md` créés avec le contenu initial.
- Si l'utilisateur a choisi un panel à la proposition (H) : invariants des modes correspondants (`references/mode-double-check.md` pour single, *Résolution intra-session* de `references/mode-update.md` pour fix) applicables.
