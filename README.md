# Claude Code & Codex Skills

Une collection de skills de qualité de code utilisables par **Claude Code** et **Codex**, avec une source canonique unique et un CLI d'installation locale basé sur `make`.

## Architecture

Le contenu métier de chaque skill vit une seule fois sous `skills/` :

```text
skills/
├── maintainability/
│   ├── SKILL.md
│   ├── agents/openai.yaml
│   └── references/
└── doc-cleanup/
    ├── SKILL.md
    ├── agents/openai.yaml
    └── references/
```

Les vues de projet sont des symlinks vers cette source :

```text
.claude/skills/  -> skills destinés à Claude Code
.agents/skills/  -> skills destinés à Codex
```

Le dépôt porte aussi les deux manifests de distribution :

```text
.claude-plugin/plugin.json
.codex-plugin/plugin.json
```

Il n'y a pas de fichiers de commandes séparés : chaque skill est nativement invocable en slash command (`/maintainability`, `/doc-cleanup`), les arguments étant interprétés par le dispatch du `SKILL.md`.

## Installation locale

Depuis la racine du dépôt :

```bash
make list

make install-claude
make install-codex
make install-all

make install-claude SKILL=maintainability
make install-codex SKILL=doc-cleanup
```

La forme générique est également disponible :

```bash
make install AGENT=claude
make install AGENT=codex
make install AGENT=all
```

Sans `AGENT`, les aliases historiques `make install`, `make diff`, `make uninstall` et `make sync` restent ciblés sur Claude Code. Utiliser les targets `*-all` pour agir explicitement sur les deux agents.

Destinations :

- Claude Code : `~/.claude/skills/<name>/`.
- Codex : `~/.agents/skills/<name>/`.

Commandes associées :

```bash
make diff-claude [SKILL=<name>]
make diff-codex  [SKILL=<name>]
make diff-all    [SKILL=<name>]

make uninstall-claude [SKILL=<name>]
make uninstall-codex  [SKILL=<name>]
make uninstall-all    [SKILL=<name>]

make validate
```

L'installation est un miroir exact par skill avec `rsync --delete`. Elle ne touche pas aux skills portant d'autres noms.

## Invocation

Les deux agents chargent les mêmes `SKILL.md`, mais leur syntaxe explicite diffère :

| Intention | Claude Code | Codex |
|---|---|---|
| Audit automatique | `/maintainability` | `$maintainability audite la zone la plus pertinente` |
| Audit ciblé | `/maintainability src/api` | `$maintainability audite src/api` |
| Tableau de bord | `/maintainability list` | `$maintainability affiche le tableau de bord` |
| Re-vérification | `/maintainability update` | `$maintainability re-vérifie les pendings` |
| Nettoyage ciblé | `/doc-cleanup src/api` | `$doc-cleanup nettoie src/api` |
| Fichiers touchés | `/doc-cleanup session` | `$doc-cleanup nettoie les fichiers touchés` |
| Projet complet | `/doc-cleanup project` | `$doc-cleanup nettoie tout le projet` |

L'invocation implicite reste possible quand la demande correspond à la description d'un skill.

## État généré dans les projets audités

Les exécutions partagent un répertoire neutre entre agents :

```text
.code-quality/
├── maintainability_history.md
├── maintainability_findings.md
├── maintainability_resolved_archive.md
└── doccleanup_coverage.md
```

## Skills disponibles

### `maintainability`

Audit de maintenabilité ciblé et incrémental : duplication, code mort, complexité, taille, incohérences, couplage, frontières architecturales, tests redondants, configuration dispersée et dette documentaire légère.

Le skill fournit :

- des audits zonaux et cross-zone ;
- un suivi persistant avec IDs stables ;
- un tableau de bord et une re-vérification des pendings ;
- des double-checks avec blast radius et verdict ;
- une re-vérification en cascade après résolution.

### `doc-cleanup`

Nettoyage agressif des commentaires et docstrings qui paraphrasent le code, avec conservation des règles métier, intentions non évidentes, contraintes de sécurité et contrats d'API publique.

Le skill fournit :

- un mode zone, projet complet ou fichiers touchés ;
- des renames prudents pour rendre le code auto-documenté ;
- une orchestration sérialisée, avec ou sans sous-agents ;
- une validation par zone et une couverture persistante.

## Ajouter un skill

1. Créer `skills/<name>/SKILL.md` et ses ressources éventuelles.
2. Ajouter `skills/<name>/agents/openai.yaml` pour les métadonnées Codex.
3. Ajouter les symlinks `.claude/skills/<name>` et `.agents/skills/<name>` vers `../../skills/<name>`.
4. Lancer `make validate`.

## Licence

MIT
