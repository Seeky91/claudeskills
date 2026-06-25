# Claude Skills

Une collection de skills réutilisables pour Claude Code, avec un CLI d'installation (`make`) pour les synchroniser vers `~/.claude`.

## Structure du repo

Chaque skill est **compartimenté** : développer sur l'un n'impacte jamais les autres.

```
.claude/
├── skills/
│   └── <name>/              # un dossier autonome par skill
│       ├── SKILL.md
│       └── references/      # fichiers chargés à la demande
└── commands/
    └── <name>/              # slash commands du skill <name>
        └── *.md
```

Convention : les slash commands d'un skill vivent dans `.claude/commands/<name>/` (le sous-dossier est un namespace d'organisation — le nom de la commande reste celui du fichier). C'est ce qui permet au CLI d'installer/désinstaller/differ chaque skill et ses commands indépendamment, dans le repo comme dans `~/.claude`.

Le repo étant lui-même un projet Claude Code, les skills sont actifs en l'état quand on travaille dedans — c'est ici qu'on les développe, `~/.claude` n'est qu'un miroir d'installation.

## Installation (CLI)

Depuis la racine du dépôt :

```bash
make list                  # skills disponibles + état (installé ou non)
make install               # installe tous les skills vers ~/.claude
make install SKILL=foo     # installe un seul skill
make diff                  # diff repo ↔ ~/.claude, tous les skills
make diff SKILL=foo        # diff pour un seul skill
make uninstall SKILL=foo   # retire un skill de ~/.claude (confirmation)
make uninstall             # retire tous les skills (confirmation)
```

L'installation est un miroir exact par skill (`rsync --delete` sur `~/.claude/skills/<name>/` **et** `~/.claude/commands/<name>/`) : `~/.claude` reflète toujours le repo, sans toucher aux skills ou commands d'autres provenances.

---

## Skills disponibles

### 🛠 maintainability

Audit de maintenabilité ciblé et incrémental — détecte et suit la dette de maintenabilité (duplication, code mort, complexité, défauts d'architecture : couplage, cohésion, abstractions) dans le temps sans repasser toujours sur les mêmes zones.

* suivi des findings via des IDs stables, état persistant par projet (`.claude/`)
* historique d'audits **append-only** : pas de zone re-proposée par perte de mémoire
* **sélection auto qui pousse vers les zones effectivement modifiées** : signal d'activité (git log croisé avec les fixes) qui priorise les zones jamais auditées et les zones « chaudes »
* **évaluation multi-paradigme** : architecture et idiomes jugés contre le référentiel du langage *et* les conventions du codebase (haute cohésion / faible couplage, composition roots lisibles, design épuré — early returns, pattern matching), jamais contre un dogme unique ni des seuils statistiques aveugles
* **landmarks architecturaux** : les entrypoints applicatifs, roots locales de sous-systèmes, façades publiques structurantes et builders/factories structurants peuvent être audités même s'ils sont petits, avec garde-fous anti-wrappers triviaux
* **sweeps cross-zone** sur une dimension transverse (`DUP`/`INC`/`DRF`/`DED`/`BND`/`ARC`) avec rolling crosscut indépendant (`Nx = 6`)
* **outillage déterministe opportuniste** : utilise `scc`/`tokei`, `jscpd`, `knip`/`vulture`/`cargo-udeps`, `lizard`/`radon`, `madge`… s'ils sont présents, dégradation gracieuse vers la lecture sinon
* re-vérification en cascade automatique après chaque fix
* sorties chat normalisées via templates nommés

Architecture : `SKILL.md` routeur mince + un playbook par mode dans `references/` (une invocation ne paie que le contexte de son mode).

#### Slash commands

| Commande | Rôle |
|---|---|
| `/maintainability [path]` | Audit d'une zone (sélection auto si pas de path) |
| `/maintainability-crosscut` | Sweep cross-zone sur une dimension transverse (auto-proposée) |
| `/maintainability-list` | Tableau de bord : pendings, résolus récents, rollings, batches suggérés |
| `/maintainability-update` | Re-vérifie tous les findings pending, self-heal des stales |
| `/maintainability-double-check <ID>` | Deep-dive d'un finding : blast radius, faisabilité, verdict GO/NO-GO |
| `/maintainability-archive-clear [--all \| --keep N \| --older-than <durée>]` | Purge l'archive des résolus (défaut : > 6 mois), avec confirmation |

#### Fichiers générés dans le projet audité

* `.claude/maintainability_history.md` — historique des audits
* `.claude/maintainability_findings.md` — findings pending + résolus récents
* `.claude/maintainability_resolved_archive.md` — archive des anciens résolus

---

## Ajouter un nouveau skill

1. Créer `.claude/skills/<name>/` avec son `SKILL.md` (et `references/` si besoin).
2. Ajouter ses slash commands dans `.claude/commands/<name>/`.
3. `make list` le découvre automatiquement ; `make install SKILL=<name>` l'installe.

## Licence

MIT
