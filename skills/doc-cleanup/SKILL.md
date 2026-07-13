---
name: doc-cleanup
argument-hint: "[<path> | project | session [--touched]]"
description: "Aggressively remove redundant, stale, or AI-generated code comments and docstrings while preserving business rules, non-obvious intent, safety notes, and public API contracts. Use for comment cleanup, over-documentation, self-documenting renames, project-wide cleanup, or files touched in the current session; also for French requests such as « nettoyer les commentaires » or « supprimer la sur-documentation ». This skill edits code. Use maintainability instead for structural audits."
---

# Doc-cleanup skill

Nettoyage **agressif** de la documentation de code : supprimer le bruit (commentaires qui paraphrasent le code), rendre le code auto-documenté par renommage, et fiabiliser le peu qui reste (corriger le drift). Le livrable est le **code nettoyé** dans l'arbre de travail, pas un rapport.

## Frontière

Exécuter le nettoyage demandé dans le code. Pour un audit structurel (duplication, code mort, god files, couplage, architecture), utiliser le skill `maintainability` : il *diagnostique et suit* des findings, tandis que ce skill *modifie* la couche documentation.

## Références

Ce SKILL.md est un **routeur mince** : il fixe le mode, les conventions transverses et pointe vers le playbook. Les détails normatifs vivent dans `references/`, chargées **à la demande** :

**Doctrine (le cœur — à lire avant tout nettoyage, quel que soit le mode)** :

- `references/doctrine.md` — la posture agressive, l'heuristique « *what* = bruit / *why* = on garde », les 3 verbes (SUPPRIMER / RENOMMER / GARDER+dé-drifter), la liste indicative de ce qui se supprime à vue, l'allowlist de ce qui survit, et les garde-fous (quand NE PAS toucher). **Sans cette lecture, le nettoyage dérive** — soit trop timide (le défaut d'un agent), soit destructeur.

**Playbooks de mode (lire et exécuter celui du mode courant)** :

- `references/mode-project.md` — campagne globale : bootstrap, inventaire des zones, ledger de couverture, boucle de campagne, reprise.
- `references/mode-zone.md` — nettoyage d'un path unique (ou sélection auto d'une zone).
- `references/mode-session.md` — sélection par diff git, switch `--touched`.

**Orchestration et formats (chargées quand on fan-out ou qu'on écrit l'état)** :

- `references/orchestration.md` — stratégie de sous-agents quand cette capacité est disponible (fan-out vs main-loop), fallback séquentiel, sécurité des renames, granularité de validation et briefing d'un agent de zone. Partagée par `project` et par `zone` quand la zone est grosse.
- `references/file-formats.md` — format du ledger de couverture (`<STATE_DIR>/doccleanup_coverage.md`) et templates de sortie chat.

## Dispatch des modes

Déduire le mode de la requête utilisateur, indépendamment de la syntaxe d'invocation de l'agent :

| Intention de la requête | Mode | Playbook | Entrée attendue |
|---|---|---|---|
| Nettoyer une zone, sans chemin | **zone auto** | `references/mode-zone.md` | Inventorier, proposer une zone, la faire valider, puis nettoyer. |
| Nettoyer une zone avec chemin | **zone forcée** | `references/mode-zone.md` | Chemin existant, fichier ou dossier. |
| Nettoyer tout le projet | **project** | `references/mode-project.md` | Aucun argument supplémentaire. |
| Nettoyer les fichiers de la session | **session** | `references/mode-session.md` | Option `--touched` éventuelle. |

Accepter comme aliases de compatibilité `/doccleanup`, `/doccleanup-project` et `/doccleanup-session`. Avec Codex, les formulations équivalentes sont par exemple `$doc-cleanup sur src/`, `$doc-cleanup sur tout le projet` et `$doc-cleanup sur les fichiers touchés --touched`. Si le skill est invoqué explicitement sans précision, choisir **zone auto**.

**Procédure de dispatch** : (1) vérifier le root projet ; (2) résoudre `<STATE_DIR>` ; (3) valider l'entrée restante de la requête — demander une clarification uniquement pour un chemin inexistant ou un flag inconnu ; (4) lire `references/doctrine.md` ; (5) lire et exécuter le playbook du mode. Ne jamais dépendre d'une variable propre à un agent telle que `$ARGUMENTS`.

## Détection du root projet

Avant tout dispatch, confirmer que `cwd` est la racine d'un projet :

1. Chercher un marqueur dans le `cwd` : `.git/`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `composer.json`, `Gemfile`, `pom.xml`, `build.gradle`, `.hg/`, `.svn/`.
2. **Trouvé** → continuer.
3. **Absent** → remonter dans les parents jusqu'à un marqueur (ou la racine du filesystem).
4. **Trouvé dans un parent** : annoncer *"Le root projet semble être `<parent>`, mais le `cwd` est `<cwd>`. Relance depuis `<parent>` ou confirme ici (l'état sera créé dans le projet confirmé)."* et attendre.
5. **Aucun marqueur** : abort avec *"Aucun marqueur de projet détecté. Lance la commande depuis la racine d'un projet."*

Si l'utilisateur passe un `<path>` (mode zone forcée), le path est le scope et l'état est rattaché au marqueur de root le plus proche.

## Résolution du répertoire d'état

Résoudre une seule fois `<STATE_DIR>` après `<PROJECT_ROOT>` afin que Claude Code et Codex partagent le même historique :

1. Si `doccleanup_coverage.md` existe **dans les deux répertoires**, arrêter avant toute écriture, signaler l'historique scindé et demander lequel conserver ou migrer. Ne jamais fusionner automatiquement.
2. Sinon, si `<PROJECT_ROOT>/.code-quality/doccleanup_coverage.md` existe, utiliser `<PROJECT_ROOT>/.code-quality`.
3. Sinon, si le legacy `<PROJECT_ROOT>/.claude/doccleanup_coverage.md` existe, utiliser `<PROJECT_ROOT>/.claude` pour toute l'invocation et annoncer : *"État legacy `.claude/` conservé pour éviter de scinder l'historique."*
4. Sinon, utiliser `<PROJECT_ROOT>/.code-quality`; le créer uniquement lorsqu'un mode doit écrire.

Ne jamais lire dans un répertoire puis écrire dans l'autre pendant la même invocation.

Dans toutes les références de ce skill, un nom de fichier d'état non qualifié tel que `doccleanup_coverage.md` désigne toujours `<STATE_DIR>/doccleanup_coverage.md`.

## Conventions transverses (tous modes)

Ces règles s'appliquent à **chaque** mode, elles ne sont pas répétées dans les playbooks.

1. **Git en lecture seule.** Le skill **édite librement l'arbre de travail** (c'est son produit), mais ne touche **jamais** à l'index ni à l'historique : `git log`/`diff`/`status`/`blame`/`show` autorisés ; `git add`/`commit`/`push`/`reset`/`checkout`/`restore` **interdits**. Les modifications restent non commitées — la review et le commit appartiennent à l'utilisateur. Le diff non commité **est** la surface de review du skill.

2. **Validation après chaque zone entièrement appliquée** (jamais par edit). Un rename touche N fichiers : la zone n'est valide qu'une fois les N faits. Détecter la commande de lint/test du projet (cf. `references/orchestration.md > Validation`) et la lancer à la fin de chaque zone. **Tests KO → ne pas passer à la zone suivante** : annoncer, et soit corriger, soit signaler que la zone reste dans un état partiel. Pas de setup de test détecté → l'annoncer et continuer en dégradé (compilation/lint seuls si dispo).

3. **Date déterministe.** Toute date écrite dans l'état (`<STATE_DIR>/doccleanup_coverage.md`) vient de `date +%F`, jamais supposée de mémoire. Si `date` est indisponible, le signaler en chat plutôt qu'inventer.

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

- Ledger `<STATE_DIR>/doccleanup_coverage.md` mis à jour (une ligne par zone/passe nettoyée).
- Validation lancée et son résultat reporté (ou dégradation annoncée).
- Renames listés dans la sortie.
- Aucun `git add`/`commit` effectué.

**Si une case n'a pas pu être cochée** (tests KO, pas de setup, fichier en lecture seule), **l'annoncer en chat** plutôt que rendre la main silencieusement — l'utilisateur doit savoir qu'un état partiel existe. La checklist détaillée propre à chaque mode vit en fin de son playbook.
