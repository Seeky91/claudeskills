# Mode : project (campagne globale)

Playbook chargé par SKILL.md sur `/doccleanup-project`. Campagne de nettoyage de **tout** le projet, zone par zone, via orchestration de sous-agents, avec couverture persistée pour la reprise. Charger `references/doctrine.md` et `references/orchestration.md` avant d'exécuter. Conventions transverses (git read-only, validation par zone, dates, delta) : cf. SKILL.md.

## A. Bootstrap

1. Si `.claude/` n'existe pas : le créer.
2. Si `<PROJECT_ROOT>/.claude/doccleanup_coverage.md` absent : le créer avec `# Doc-cleanup coverage\n\n`. Le chemin est **toujours** relatif au root projet résolu (cf. SKILL.md > *Détection du root projet*), jamais au `cwd` brut.
3. Annoncer en chat : *"Bootstrap doc-cleanup, aucune couverture préalable."*

## B. Inventaire des zones

Calculé à chaque campagne (jamais persisté). But : un découpage où chaque zone tient dans le budget de lecture d'un agent.

0. **Comptage opportuniste** : tester `command -v scc || command -v tokei`. Si présent, l'exécuter en JSON par fichier (`scc --by-file -f json` / `tokei -o json`) pour les LoC source par fichier/dossier, sans lire le code. Sinon, marche manuelle.
1. **Walk** depuis le root. Exclure : `node_modules`, `.git`, `dist`, `build`, `vendor`, `target`, `.venv`, et tout généré (`*.gen.*`, `*_pb2.*`, output de codegen). Exclure aussi les non-source (`.json`, `.lock`, `.md`, `.toml`) — le skill nettoie du **code**.
2. **Découpage** :
   - Dossier 200–2000 LoC source → zone candidate.
   - Dossier > 2000 LoC → descendre récursivement dans les sous-dossiers.
   - Dossier < 200 LoC → grouper avec le parent.
   - Fichier ≥ 600 LoC → zone autonome additionnelle.
   - Sur monorepo : viser un budget de lecture raisonnable par zone plutôt que les seuils absolus.

`Z` = nombre de zones.

## C. Reprise sur la couverture

1. **Lire `<PROJECT_ROOT>/.claude/doccleanup_coverage.md`** en entier. Parser les lignes `- YYYY-MM-DD — <zone> — <mode> — …` en couples `(zone, date)`.
2. **`zones_couvertes`** = map `<zone> → date de couverture la plus récente`, sur les lignes de mode `project` ou `zone` (chemins). Les lignes `session (…)` ne portent pas sur une zone d'inventaire → ignorées pour la couverture (un nettoyage de session antérieur rend juste une zone ultérieure moins chargée).
3. **Staleness** (repo git uniquement) : une zone couverte est **revalidée stale** si du code y a bougé depuis son nettoyage — `git log -1 --format=%cd --date=short -- <zone>` postérieur (strictement) à sa date de couverture. *Auto-correcteur* : le commit de nettoyage de l'utilisateur peut déclencher un stale **une fois** ; l'agent re-balaie, trouve la zone propre, ré-écrit une ligne `0 supprimés` à jour, et la zone ressort du stale. Repo non-git → pas de staleness, couverture par chemin seul.
4. **`zones_pending`** = `(inventaire − zones_couvertes)` ∪ `zones_stale`.
5. **Ordre de traitement** : zones **jamais couvertes** d'abord, puis **stale** (modifiées depuis), puis départage déterministe par **ordre alphabétique du chemin** (reproductible d'un run à l'autre).
6. Si `zones_pending` est vide (tout couvert **et** rien de stale) : annoncer que tout le projet est à jour, et proposer soit un re-balayage complet (ignorer la couverture), soit de cibler une zone via `/doccleanup <path>`. Attendre.

## D. Plan de campagne + go-ahead

Avant de lancer quoi que ce soit, afficher le plan via le template `project:plan` (cf. `references/file-formats.md`) :

- nombre de zones pending / total, point de reprise s'il y a lieu,
- la **commande de validation** détectée (ou la demander une fois si ambiguë, cf. `references/orchestration.md > Validation`),
- rappel : nettoyage agressif, git laissé non commité (review = diff).

**Attendre un go-ahead explicite.** C'est l'unique gate de la campagne : ensuite elle tourne en autonomie zone par zone, avec un report par zone. Pas d'approbation par commentaire (absurde pour de l'agressif) — la review se fait sur le diff non commité en fin de campagne.

## E. Boucle de campagne

Pour chaque zone de `zones_pending`, dans l'ordre :

1. **Fan-out** : instancier un sous-agent à contexte vierge avec le briefing de `references/orchestration.md > Briefing d'un sous-agent de zone`, scopé à la zone. (Petite zone unique ≲ 1500 LoC : l'orchestrateur peut traiter en main-loop sans agent, cf. orchestration.)
2. **Recevoir le résumé** (fichiers inspectés, supprimés, renames + sites + outil, docs dé-driftées, fichiers modifiés, non-traités, incertitudes). Ne **pas** charger le code de la zone dans le contexte orchestrateur.
3. **Vérifier l'intégrité** du résumé (cf. `references/orchestration.md > Vérification d'intégrité`) : `git diff --stat -- <zone>` recoupé avec le résumé et le scope (débordement autorisé seulement pour des sites de propagation de rename déclarés). Anomalie → investiguer/relancer, **ne pas** marquer couvert.
4. **Valider** (commande établie en D). KO → **stop la campagne**, reporter l'échec + la zone, laisser l'utilisateur arbitrer. OK → étape 5.
5. **Écrire la ligne de couverture** (delta, en tête de `<PROJECT_ROOT>/.claude/doccleanup_coverage.md`) : cf. `references/file-formats.md`.
6. **Report par zone** via `project:zone-progress`, puis zone suivante.

Sérialisation stricte (cf. orchestration) : une zone à la fois, renames propagés au projet entier avant la suivante.

## F. Sortie finale

À l'épuisement de `zones_pending` (ou à l'arrêt sur tests KO), afficher `project:summary` : zones traitées, totaux agrégés (commentaires supprimés, renames, docs dé-driftées), zones restantes le cas échéant, rappel que tout est non commité.

## Invariants de fin de mode

- Une ligne de couverture écrite **par zone traitée** (mode `project`).
- Validation lancée et reportée par zone (ou dégradation annoncée une fois).
- Renames listés dans les résumés de zone.
- Aucun `git add`/`commit`.
- Campagne interrompue sur KO → état partiel **annoncé** (zones faites vs restantes), pas de main rendue silencieusement.
