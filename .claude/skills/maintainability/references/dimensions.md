# Catalogue des dimensions de maintenabilité

Référence chargée par SKILL.md à l'exécution d'un audit ou d'un crosscut, pour cadrer ce qui constitue un finding sur chaque axe.

## Seed des dimensions

12 dimensions de départ. **Ce n'est pas une grille fermée** : si un problème de maintenabilité réel ne colle à aucune, **invente un nouveau préfixe 3 lettres** (ex. `LOG-` pour sprawl de logging, `RAC-` pour patterns concurrents). La rigueur est sur l'observation factuelle, pas sur l'étiquetage.

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
| `ARC` | Architecture / couplage | Cycles inter-modules, responsabilité mal placée (feature envy), shotgun surgery, abstraction fuyante ou spéculative, composition roots opaques, couches pass-through, sur-fragmentation (cf. cadrage dédié) |

**Hors scope du skill** : sécurité, performance, accessibilité, choix de stack. Précision : l'architecture *interne* du repo est couverte (`ARC`) ; le choix de stack/framework et l'architecture d'infra/déploiement restent exclus.

**Principe d'observation** : décrire le problème en clair (fait vérifiable, fichier:ligne, impact concret) **avant** de chercher quel préfixe coller. Ne pas forcer une dimension par audit.

### Frontières entre dimensions voisines

Plusieurs dimensions se partagent le territoire « structure du code ». Règle d'affectation (évite les litiges de reclassification) :

| Le défaut porte sur… | Dimension |
|---|---|
| le flux de contrôle *dans une fonction* (nesting, structure inversée, fragmentation intra-fichier) | `CPX` |
| la taille d'un fichier/module | `SIZ` |
| la transgression d'une frontière *déclarée* (import d'internes, contournement d'API publique) | `BND` |
| un idiome d'*expression* du langage (gestion d'erreur, ressources, types, construction) | `IDM` |
| le mélange de niveaux d'abstraction dans une fonction de composition (entrypoint, bootstrap, factory de sous-système) | `ARC` |
| la forme des relations *entre unités* : placement des responsabilités, graphe de dépendances, qualité d'abstraction | `ARC` |

`BND` vs `ARC` en une phrase : `BND` = une règle existe et est violée ; `ARC` = aucune règle violée, la structure elle-même est le défaut.

## Outils de détection opportunistes

Source unique de la cartographie outil↔dimension, référencée par `references/mode-audit.md > E.1bis` et `references/mode-crosscut.md > C`. Pour les dimensions mécanisables, un outil déterministe bat l'agent en **rappel** et en **localisation** ; l'agent garde le **jugement**. Posture invariante :

- **Opportuniste, jamais obligatoire.** Tester la présence (`command -v <outil>`, ou la présence d'un manifeste de langage) ; si absent, repli sur la lecture/jugement — aucune dépendance dure n'est introduite.
- **Exécuter, ne pas lire.** C'est la **sortie** de l'outil (idéalement JSON) qui entre en contexte, pas le code source — gain de tokens et de précision.
- **L'outil propose, l'agent dispose.** Un hit outil = un **candidat à examiner**, pas un finding. L'agent applique ensuite la grille de sévérité, le trade-off check (`references/quality.md`) et peut écarter le bruit. Un seuil d'outil franchi (p.ex. complexité cyclomatique = 11) n'est *pas* un finding en soi.

| Dimension | Outils (sortie JSON si dispo) | Notes |
|---|---|---|
| `DUP` | `jscpd` (≈223 langages, reporters json/sarif), PMD `CPD` | Donne blocs dupliqués + localisation exacte ; idéal en crosscut repo-wide. |
| `DED` | `knip` (JS/TS), `vulture` (Python, scores de confiance), `deadcode -json` (Go), `cargo-machete`/`cargo-udeps` (Rust), `staticcheck` U1000 (Go) | Exports/déps inutilisés. Garder la prudence anti-faux-positif du crosscut `DED` (API publiques, hooks de framework, barrels). |
| `SIZ` / `CPX` | `scc` (LoC + complexité, `--by-file -f json`), `tokei -o json` (LoC), `lizard` (CCN multi-langage), `radon cc -j` (Python) | Sert aussi à l'inventaire de zones (`references/mode-audit.md > B.0`). |
| `CFG` | `ripgrep` ciblé (`rg` sur lectures d'env vars / flags), `dotenv-linter` (drift `.env`) | Repérer les flags accumulés / jamais lus. |
| `BND` | graphes d'imports : `madge --circular` (JS/TS), `go list -deps`, `import-linter` (Python), `pydeps` | Cycles, fan-in-out, contournements de frontière. |
| `ARC` | mêmes graphes d'imports que `BND` (+ `dependency-cruiser` JS/TS, règles + JSON), **co-change git** (`git log`, aucune dépendance externe) | Cycles, fan-in/out × churn, couplage temporel. Méthode co-change : cf. cadrage `ARC` ci-dessous — signal langage-agnostique. |
| `DRF` | comparaison de schémas/types au jugement (pas d'outil générique fiable) | Reste majoritairement à la lecture. |

Pour `INC`, `IDM`, `TST`, `DOC` : pas d'outil fiable de substitution — détection au jugement (et pour `IDM`, garde-fou anti-linter strict ci-dessous).

## Référentiel paradigmatique (transverse à ARC, IDM, CPX)

Le skill n'impose aucun dogme architectural unique. Les invariants évalués sont **haute cohésion, faible couplage, lisibilité structurelle** — leur *forme* idiomatique varie selon le paradigme (module fonctionnel pur, composition par traits, classe cohésive). Méthode :

1. **Détecter le(s) langage(s)** — mécanisme existant du cadrage `IDM` (extensions + fichiers de config).
2. **Détecter le paradigme effectif du codebase** : signaux observables — traits/interfaces vs hiérarchies d'héritage, fonctions libres vs classes, immutabilité dominante, composition vs extension.
3. **Référentiel = idiomes du langage ∩ conventions établies du codebase.** En cas de conflit, **la convention du codebase prime** (la cohérence interne bat le dogme). Exception : quand le codebase « se bat contre le langage » et que la friction est *observable et récurrente* (ex. hiérarchies d'héritage simulées par embedding en Go, mutabilité partagée qui combat le borrow checker Rust). Pourquoi cette règle : sans elle, le skill produirait des dizaines de findings contre un codebase Python délibérément orienté objet — du dogme, pas de la dette.
4. **Évaluer relativement à ce référentiel**, jamais contre un style d'architecture nommé (hexagonale, clean, DDD) en tant que tel. La densité logique reste une **qualité** tant qu'elle est cohésive et scannable ; elle ne devient actionnable que si elle a un **coût de lecture concret et citable** — un sous-concept réel qui n'a pas de nom, une décision importante noyée dans du détail, une séquence qu'on ne peut suivre sans retenir une pile d'éléments accidentels. « C'est trop dense » sans ce coût n'est pas un finding. La régression à éviter est la fragmentation en wrappers triviaux ou en noms vagues qui rendent la navigation plus coûteuse que le bloc original.
5. **Abstention sur méconnaissance** : même clause que le cadrage `IDM` — paradigme ou écosystème hors zone de confort → s'abstenir et l'annoncer en chat.

Pas de table par langage dans le skill (elle vieillirait mal) : l'agent s'appuie sur sa connaissance des paradigmes du langage rencontré, le skill spécifie la méthode et les garde-fous.

## Cadrage de la dimension IDM

`IDM` cible la non-conformité aux patterns idiomatiques du langage. Le risque de cette dimension est qu'elle dérive en linter de style — le cadrage suivant est strict. S'évalue contre le *Référentiel paradigmatique* ci-dessus. **Frontière avec `ARC`** : `IDM` juge l'expression *dans* le code (comment c'est écrit) ; la structure *entre* unités relève d'`ARC`.

**Détection des langages** : avant l'audit, identifier les langages via extensions et fichiers de config (`Cargo.toml`, `pyproject.toml`, `package.json`, `go.mod`, `Gemfile`, `pom.xml`, `composer.json`, …). Sur projet multi-langage, évaluer IDM zone par zone selon le langage dominant.

**Périmètre inclus** : patterns structurels avec impact maintenabilité direct — lisibilité par un dev habitué au langage, error-prone-ness évitable, friction avec l'écosystème. Familles à couvrir : gestion d'erreur idiomatique (Rust `Result`/`?`, Go error wrapping, Python `try/except` ciblé), gestion des ressources (context managers Python, `defer` Go, RAII Rust, try-with-resources Java), types et conteneurs adaptés (dataclasses Python, types stricts TS, `Optional` Java), patterns de construction du langage (builder Rust, comprehensions Python). L'agent s'appuie sur sa connaissance des idiomes du langage rencontré, pas sur une liste fermée du skill.

**Périmètre exclu** : tout ce qui est automatisable par un linter ou un formatter — naming style (snake_case vs camelCase), ordre des imports, indentation, choix de quotes, longueur de ligne, espace avant parenthèse. Hors scope du skill.

**Abstention sur méconnaissance** : si l'agent n'a pas une connaissance suffisante des idiomes d'un langage présent dans la zone, il s'abstient sur cette dimension plutôt que d'inventer des règles. Note honnête en chat type *"Je passe IDM sur ce fichier Elixir : idiomes du langage hors zone de confort."*

## Cadrage de la dimension ARC

`ARC` cible les défauts de structure **entre unités** (modules, couches, abstractions). C'est la dimension la plus subjective du catalogue — le risque est qu'elle dérive en linter d'architecture. Le cadrage suivant est strict, symétrique de celui d'`IDM`.

**Préalable** : évaluer contre le *Référentiel paradigmatique* ci-dessus, jamais contre un dogme. Et appliquer `references/quality.md > Dogme ≠ défaut` : sans symptôme concret de friction, pas de finding.

**Périmètre inclus** (symptômes observables uniquement) :

- **Couplage** : cycles inter-modules ; couplage temporel (fichiers co-modifiés de façon répétée à travers une frontière de module **sans** relation d'import) ; module à fort fan-in × fort churn (beaucoup en dépendent ET il bouge tout le temps — aimant à casse).
- **Cohésion** : responsabilité mal placée — feature envy (fonction qui manipule majoritairement les données d'un autre module) ; shotgun surgery (modifier un concept force à toucher N fichiers — seam manquant).
- **Abstraction** : fuyante (les call sites doivent connaître l'interne — observable : un client importe le module ET ses internes dans le même fichier) ; spéculative (généricité jamais exercée : interface à implémenteur unique conçue « pour plus tard », paramètres jamais variés) ; couche pass-through / middle-man (module dont la majorité des exports délèguent sans rien ajouter) ; **sur-fragmentation** (logique éclatée en miettes d'indirection là où une unité cohésive et nommée serait plus lisible — le miroir de `SIZ`).
- **Composition roots / entrypoints locaux** : point d'entrée applicatif, builder/factory de sous-système, façade publique structurante ou assembly de pipeline qui mélange orchestration haut niveau, construction détaillée de dépendances concrètes, configuration bas niveau et logique métier au point que la séquence de boot/traitement n'est plus scannable.

**Preuve de friction exigée** : chaque finding `ARC` cite un symptôme concret et vérifiable — le commit qui a dû toucher 7 fichiers, le call site qui contourne l'abstraction, le cycle fichier:ligne, le bug pattern récurrent, la construction d'un sous-système qui oblige le parent à connaître ses détails internes. « Ce n'est pas conforme au pattern X » n'est jamais une observation.

**Reco incrémentale obligatoire** : la reco d'un `ARC` propose un **premier pas** (inverser une dépendance, extraire une interface, déplacer une fonction, introduire un constructeur/factory nommé possédé par le sous-système), jamais une réorganisation big-bang. Le Δ LoC porte sur ce premier pas ; si la cible finale est plus large, la nommer dans la reco sans la chiffrer.

**Heuristiques de détection** (candidats à examiner, jamais findings — posture outillée standard) :

- **Co-change git** : sur les ~200 derniers commits hors maintainability (réutiliser le set `commits_maintainability` du signal d'activité, cf. `references/mode-audit.md > C`), paires de fichiers fréquemment co-modifiées (ordre de grandeur : ≥ 5 co-occurrences) à travers une frontière de module sans lien d'import = couplage caché ; commits de feature touchant répétitivement ≥ 3 modules = shotgun surgery. Exclure lockfiles et généré.
- **Instabilité × churn** : croiser le fan-in du graphe d'imports avec le churn git — les modules hauts sur les deux axes sont les candidats prioritaires.
- **Ratio pass-through** : exports qui ne font que re-exporter/déléguer sans rien ajouter, détectable au `rg`.
- **Landmarks architecturaux** : fichiers ou symboles de composition (`main`, `app`, `server`, `worker`, `bootstrap`, `init`, `start`, `build`, `new`, `factory`, `router`, `pipeline`, façade publique structurante). Signal seulement si le landmark assemble plusieurs dépendances/sous-systèmes ou fixe une politique de lifecycle ; ignorer les helpers triviaux et simples barrels/réexports.

### Composition roots et niveau d'abstraction

Une composition root est un point qui assemble des dépendances concrètes et fixe une politique de lifecycle. Elle peut être globale (`main`, serveur, CLI) ou locale à un sous-système (runtime engine, web state, worker, router, pipeline, client externe). La lentille est **récursive mais bornée** : chaque boundary importante mérite une composition lisible ; les opérations atomiques n'ont pas besoin de devenir des mini-entrypoints.

Chercher le principe de **niveau d'abstraction uniforme** : une fonction de composition devrait lire comme une suite d'étapes nommées au même niveau ("charger config → créer runtime → démarrer engine → servir web"), pas alterner cette histoire avec des détails de locks, channels, maps, parsers, adapters ou champs internes.

Produire un finding seulement si la friction est observable : séquence de boot/traitement difficile à scanner, parent obligé de connaître les champs internes d'un sous-système, changement local qui impose d'éditer l'entrypoint parent, wiring similaire recopié entre plusieurs roots, ou politique globale noyée dans du détail accidentel.

Reco attendue : déplacer le détail vers un constructeur/factory nommé et possédé par le sous-système (`Runtime::new`, `WebState::from_config`, `build_router`, `start_worker`, etc. selon le langage), tout en gardant visibles dans le parent les politiques globales (ordre de boot, fallback non fatal, shutdown, choix de mode). Une extraction à usage unique est acceptable si elle nomme un concept réel ou baisse une densité qui gêne la lecture. **Ne pas recommander** de wrappers pass-through ni de noms vagues qui déplacent seulement le problème ou cachent les décisions importantes.

**Périmètre exclu** : conformité à un style d'architecture nommé en tant que telle ; choix de stack/framework ; architecture d'infra/déploiement ; god files (→ `SIZ`) ; transgressions de frontières déclarées (→ `BND`) ; cf. *Frontières entre dimensions voisines*.

**En zonal vs crosscut** : la cohésion (feature envy, sur-fragmentation, abstraction locale, composition roots opaques) se juge en audit zonal — avec la frontière d'imports de la zone (cf. `references/mode-audit.md > E`) ; le couplage profond (cycles, co-change, instabilité × churn) relève du crosscut `ARC`.

**Abstention sur méconnaissance** : même clause qu'`IDM`.

## Cadrage de la dimension CPX — design épuré

`CPX` cible la complexité *intra-fonction*. Doctrine : la lisibilité vient de la **structure**, pas de règles de formatage ni de seuils statistiques.

**Ce qu'on cherche** :

- **Structure inversée** : early returns / guard clauses absents. Heuristique de signature : **le cas nominal doit être le chemin le moins indenté** — une fonction dont le return nominal est au niveau d'indentation le plus profond est candidate.
- Chaînes if/else qui seraient un pattern matching / switch exhaustif **plat** dans le langage.
- Conditions à inverser pour dégager le flux principal.
- **Fragmentation excessive intra-fichier** : cascade de helpers à usage unique qui forcent le lecteur à sauter — extraire un helper quand il **nomme un concept réel**, ou quand la densité a un coût de lecture citable (sous-concept sans nom, décision noyée), jamais pour réduire mécaniquement une longueur ni sur un ressenti « trop dense » ; éviter les wrappers triviaux ou noms vagues qui ne font que déplacer le code (la version inter-unités est `ARC` sur-fragmentation).

**Anti-seuil explicite** : pas de « max N niveaux d'imbrication », pas de complexité cyclomatique-as-finding. Un nesting de 4 qui reflète l'arbre de décision réel du domaine peut être la forme la plus claire. Les outils (`lizard`, `radon`) fournissent des candidats ; le jugement tranche — posture « l'outil propose, l'agent dispose ».

**Garde comportementale** : une réécriture early-return doit préserver le comportement — attention aux langages sans `defer`/RAII où un return anticipé saute un cleanup. Mentionner ce point dans la `Reco` quand applicable.
