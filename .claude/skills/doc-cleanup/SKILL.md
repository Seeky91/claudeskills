---
name: doc-cleanup
description: Use when the user invokes `/doccleanup`, `/doccleanup-project` or `/doccleanup-session`, or asks to aggressively clean up code comments / remove over-documentation / comment bloat / excessive or redundant comments (especially AI- or agent-generated over-commenting that paraphrases the code), wants to make code self-documenting by renaming symbols and deleting the comments that compensated for vague names, wants to prune / trim / declutter comments and docstrings while keeping (and de-drifting) the genuinely useful ones (business rules, non-obvious intent, tradeoffs, safety, public API contracts), or wants to clean the comments in files touched during the current session; or asks in French for « nettoyer les commentaires », « trop de commentaires / sur-documentation », « commentaires inutiles », « alléger / purger la doc de code », « rendre le code auto-documenté », « supprimer les commentaires générés », « commentaires obsolètes ou qui mentent ». This skill is the executor that rewrites code. For a structural maintainability audit (duplication, dead code, god files, coupling, architecture) use `/maintainability` instead — its DOC dimension is only a light drift guard ; this skill is the dedicated aggressive doc cleanup.
---

# Doc-cleanup skill

Nettoyage **agressif** de la documentation de code : supprimer le bruit (commentaires qui paraphrasent le code), rendre le code auto-documenté par renommage, et fiabiliser le peu qui reste (corriger le drift). Le livrable est le **code nettoyé** dans l'arbre de travail, pas un rapport.

## Quand l'invoquer

Famille de trois slash commands :

- `/doccleanup [path]` — nettoie une zone (un fichier ou un dossier). Sans arg : sélection auto d'une zone.
- `/doccleanup-project` — campagne globale : nettoie tout le projet zone par zone, via orchestration de sous-agents, en suivant une couverture persistée.
- `/doccleanup-session [--touched]` — nettoie les fichiers touchés pendant la session courante (signal : diff git de l'arbre de travail).

Chaque command file invoque ce skill avec un mode pré-déterminé. **Ne pas invoquer ce skill pour** un audit structurel (duplication, code mort, god files, couplage, architecture) — c'est `/maintainability`. Frontière nette : `maintainability` *diagnostique et suit* des findings ; ce skill *exécute* un nettoyage de la couche documentation.

## Références

Ce SKILL.md est un **routeur mince** : il fixe le mode, les conventions transverses et pointe vers le playbook. Les détails normatifs vivent dans `references/`, chargées **à la demande** :

**Doctrine (le cœur — à lire avant tout nettoyage, quel que soit le mode)** :

- `references/doctrine.md` — la posture agressive, l'heuristique « *what* = bruit / *why* = on garde », les 3 verbes (SUPPRIMER / RENOMMER / GARDER+dé-drifter), la liste indicative de ce qui se supprime à vue, l'allowlist de ce qui survit, et les garde-fous (quand NE PAS toucher). **Sans cette lecture, le nettoyage dérive** — soit trop timide (le défaut d'un agent), soit destructeur.

**Playbooks de mode (lire et exécuter celui du mode courant)** :

- `references/mode-project.md` — campagne globale : bootstrap, inventaire des zones, ledger de couverture, boucle de campagne, reprise.
- `references/mode-zone.md` — nettoyage d'un path unique (ou sélection auto d'une zone).
- `references/mode-session.md` — sélection par diff git, switch `--touched`.

**Orchestration et formats (chargées quand on fan-out ou qu'on écrit l'état)** :

- `references/orchestration.md` — stratégie de sous-agents (quand fan-out vs main-loop), sécurité des renames (blast radius inter-zones), granularité de validation, prompt-type d'un agent de zone. Partagée par `project` et par `zone` quand la zone est grosse.
- `references/file-formats.md` — format du ledger de couverture (`.claude/doccleanup_coverage.md`) et templates de sortie chat.

## Dispatch des modes

Le mode est fixé par la slash command. Table canonique :

| Command | Mode | Playbook | `$ARGUMENTS` attendu |
|---|---|---|---|
| `/doccleanup` (vide) | **zone auto** | `references/mode-zone.md` | (aucun) — inventaire + sélection autonome d'une zone, validée avec l'utilisateur, puis nettoyage. |
| `/doccleanup <path>` | **zone forcée** | `references/mode-zone.md` | chemin existant (fichier ou dossier) — nettoie cette zone. |
| `/doccleanup-project` | **project** | `references/mode-project.md` | (aucun) — campagne globale orchestrée, reprise sur la couverture. |
| `/doccleanup-session` | **session** | `references/mode-session.md` | `[--touched]` — défaut : fichier entier de chaque fichier touché ; `--touched` : restreint aux hunks modifiés. |

**Procédure de dispatch** : (1) vérifier le root projet (ci-dessous) ; (2) valider `$ARGUMENTS` — sinon **demander une clarification** plutôt que deviner (path inexistant pour zone forcée, flag inconnu pour session) ; (3) **lire `references/doctrine.md`** (obligatoire, tout mode) ; (4) **lire le playbook du mode** et l'exécuter. Les conventions transverses ci-dessous s'appliquent partout.

## Détection du root projet

Avant tout dispatch, confirmer que `cwd` est la racine d'un projet :

1. Chercher un marqueur dans le `cwd` : `.git/`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `composer.json`, `Gemfile`, `pom.xml`, `build.gradle`, `.hg/`, `.svn/`.
2. **Trouvé** → continuer.
3. **Absent** → remonter dans les parents jusqu'à un marqueur (ou la racine du filesystem).
4. **Trouvé dans un parent** : annoncer *"Le root projet semble être `<parent>`, mais le `cwd` est `<cwd>`. Relance depuis `<parent>` ou confirme ici (le `.claude/` sera créé dans le `cwd`)."* et attendre.
5. **Aucun marqueur** : abort avec *"Aucun marqueur de projet détecté. Lance la commande depuis la racine d'un projet."*

Si l'utilisateur passe un `<path>` (mode zone forcée), le path est le scope et le `.claude/` est créé au marqueur de root le plus proche.

## Conventions transverses (tous modes)

Ces règles s'appliquent à **chaque** mode, elles ne sont pas répétées dans les playbooks.

1. **Git en lecture seule.** Le skill **édite librement l'arbre de travail** (c'est son produit), mais ne touche **jamais** à l'index ni à l'historique : `git log`/`diff`/`status`/`blame`/`show` autorisés ; `git add`/`commit`/`push`/`reset`/`checkout`/`restore` **interdits**. Les modifications restent non commitées — la review et le commit appartiennent à l'utilisateur. Le diff non commité **est** la surface de review du skill.

2. **Validation après chaque zone entièrement appliquée** (jamais par edit). Un rename touche N fichiers : la zone n'est valide qu'une fois les N faits. Détecter la commande de lint/test du projet (cf. `references/orchestration.md > Validation`) et la lancer à la fin de chaque zone. **Tests KO → ne pas passer à la zone suivante** : annoncer, et soit corriger, soit signaler que la zone reste dans un état partiel. Pas de setup de test détecté → l'annoncer et continuer en dégradé (compilation/lint seuls si dispo).

3. **Date déterministe.** Toute date écrite dans l'état (`.claude/doccleanup_coverage.md`) vient de `date +%F`, jamais supposée de mémoire. Si `date` est indisponible, le signaler en chat plutôt qu'inventer.

4. **Écritures en delta.** Avant d'écrire le ledger de couverture, le relire juste avant et **préfixer la nouvelle ligne** en tête, sans régénérer le fichier (il peut avoir été édité à la main).

5. **Pas de big-bang silencieux sur les renames.** Le nettoyage par suppression s'applique directement (le diff non commité est la review). Les **renames** ont un blast radius inter-fichiers : chaque rename est précédé d'un grep des références (cf. `references/doctrine.md` et `references/orchestration.md`) et **listé explicitement** dans la sortie de zone.

## Doctrine — à charger avant tout nettoyage

`references/doctrine.md` **doit** être lue au début de chaque mode. Elle porte la calibration qui fait ou défait le skill : la posture agressive par défaut (un agent compétent *sous-supprime* spontanément), l'heuristique de tri, et les garde-fous qui évitent que l'agressivité ne détruise les 10 % de commentaires utiles. Aucun mode ne produit d'edit sans l'avoir chargée.

## Sorties chat — conventions

Les sorties suivent des templates nommés définis dans `references/file-formats.md > Templates`. Conventions transverses :

- **Header** : `<Mode> terminé — <scope>`.
- **Trailer** « Files mis à jour : … » présent dès qu'on écrit le ledger ; mention des fichiers source nettoyés via leur compte, pas leur liste exhaustive (le diff git porte le détail).
- **Stats normalisées** : `<N> commentaires supprimés, <M> renames, <K> docs dé-driftées`.
- Le bloc de proposition d'action (lancer la campagne, continuer, etc.) est séparé du récap.

## Invariants de fin de mode

Avant de rendre la main, valider que toutes les écritures attendues du mode ont eu lieu (une case **non applicable** est considérée cochée) :

- Ledger `.claude/doccleanup_coverage.md` mis à jour (une ligne par zone/passe nettoyée).
- Validation lancée et son résultat reporté (ou dégradation annoncée).
- Renames listés dans la sortie.
- Aucun `git add`/`commit` effectué.

**Si une case n'a pas pu être cochée** (tests KO, pas de setup, fichier en lecture seule), **l'annoncer en chat** plutôt que rendre la main silencieusement — l'utilisateur doit savoir qu'un état partiel existe. La checklist détaillée propre à chaque mode vit en fin de son playbook.
