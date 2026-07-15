<p align="center">
  <img src="assets/thoth-logo.png" width="200" alt="Thoth">
</p>

<h1 align="center">Thoth</h1>

<p align="center"><em>Des skills de qualité de code, écrits une seule fois, partagés par Claude Code et Codex.</em></p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-E9B84C.svg"></a>
  <img alt="Agents" src="https://img.shields.io/badge/agents-Claude%20Code%20%C2%B7%20Codex-2E5FA3">
  <img alt="Version" src="https://img.shields.io/badge/version-0.3.0-blue">
</p>

## Qu'est-ce que Thoth ?

**Thoth** — *Toolkit for Heuristic Orchestration & Task Handling* — outille les agents de code avec des workflows de qualité de code robustes et réutilisables : audits de **maintenabilité**, optimisation de **performance** mesurée, et **nettoyage de commentaires**.

Deux principes le distinguent d'un simple prompt :

- **Auditer avant de corriger.** Au lieu d'un refactoring one-shot, chaque skill *diagnostique et suit* d'abord — findings persistants à IDs stables, tableau de bord, preuves avant/après — puis modifie le code sur confirmation. Et ses [**cycles autonomes**](#cycles-autonomes) enchaînent toute la boucle *audit → correction → validation* sans supervision.
- **Une source, deux agents.** Le contenu de chaque skill vit **une seule fois** et s'installe à l'identique pour **[Claude Code](https://docs.claude.com/en/docs/claude-code)** et **[Codex](https://openai.com/codex/)**. Un skill = une slash command (`/maintainability`) côté Claude Code, une invocation en langage naturel (`$maintainability …`) côté Codex.

## Les skills

Thoth s'utilise à deux niveaux. Les **cycles autonomes** sont le cœur du toolkit : ils enchaînent toute la boucle *audit → double-check → correction → validation* pour toi. Ils reposent sur des **skills atomiques**, que tu peux aussi lancer un par un quand tu veux garder la main à chaque étape.

| Skill | Ce qu'il fait | Exemple |
|---|---|---|
| [`maintainability-cycle`](#maintainability-cycle) | **Cycle autonome** : audit → double-check → fix → validation, sur un ou plusieurs cycles | `/maintainability-cycle 5` |
| [`performance-cycle`](#performance-cycle) | **Cycle autonome** mesuré : sélection → double-check → **une** optimisation → benchmark avant/après | `/performance-cycle` |
| [`maintainability`](#maintainability) | Audit et résolution suivie de la dette : duplication, code mort, complexité, couplage, frontières… | `/maintainability src/api` |
| [`performance`](#performance) | Diagnostic fondé sur des mesures reproductibles : latence, CPU, mémoire, I/O, contention… | `/performance feature checkout` |
| [`doc-cleanup`](#doc-cleanup) | Suppression des commentaires qui paraphrasent le code, en préservant règles métier et contrats d'API | `/doc-cleanup session` |

### Cycles autonomes

La façon la plus complète d'utiliser Thoth : un `goal` natif, une boucle bornée, et tous les garde-fous des skills atomiques préservés. Chaque cycle orchestre le skill atomique correspondant ([`maintainability`](#maintainability), [`performance`](#performance)) sans jamais lever ses règles de sûreté ou de preuve.

#### `maintainability-cycle`

Orchestration autonome d'un ou plusieurs cycles complets au sein d'un goal natif : sélection d'un audit ou de pendings, double-check GO/NO-GO obligatoire, fix borné des GO, validation et mise à jour du ledger.

- un cycle par défaut, ou `N` cycles avec arrêt anticipé quand plus rien n'est actionnable ;
- une autorisation autonome bornée qui évite les confirmations intermédiaires sans élargir les droits Git ;
- des sous-agents organisés par rôle et capacité, sans nom de modèle ou de fournisseur figé ;
- une politique anti testing-creep, et une unique clôture `doc-cleanup` sur les fichiers modifiés par la campagne.

#### `performance-cycle`

Orchestration autonome d'un ou plusieurs cycles mesurés au sein d'un goal natif : sélection d'un Pending ou d'un audit sûr, double-check obligatoire, fix d'un seul `PERF-NNN`, benchmark comparable avant/après et résolution du ledger.

- un cycle par défaut, ou `N` cycles avec arrêt anticipé lorsqu'aucune hypothèse mesurable n'est actionnable ;
- une autorisation bornée aux workloads locaux, sûrs, courts et non ambigus, sans lever les protections de production ;
- une optimisation unique par cycle pour conserver l'attribution du gain ;
- des mesures, profils, builds et mutations strictement sérialisés, y compris avec des sous-agents.

### Skills atomiques

Les briques que les cycles orchestrent — à lancer seules pour un audit ciblé, un tableau de bord, ou un fix précis.

#### `maintainability`

Audit, suivi et résolution contrôlée de la dette de maintenabilité : duplication, code mort, complexité, taille, incohérences, couplage, frontières architecturales, tests redondants, configuration dispersée et dette documentaire légère.

- audits zonaux et cross-zone ;
- suivi persistant avec IDs stables, tableau de bord, re-vérification des pendings ;
- double-checks avec blast radius et verdict avant tout fix ;
- fixes confirmés, validés par les tests, avec re-vérification en cascade après résolution.

#### `performance`

Audit de performance fondé sur des mesures reproductibles : latence, throughput, CPU, mémoire, I/O, contention et scalabilité sous charge.

- audit automatique ou ciblé par path/feature ;
- contrat de workload, baseline, profiling et comparabilité ;
- findings `PERF-NNN` persistants et tableau de bord ;
- double-checks qui reproduisent la preuve, fixes validés par tests et benchmark avant/après.

#### `doc-cleanup`

Nettoyage agressif des commentaires et docstrings qui paraphrasent le code, avec conservation des règles métier, intentions non évidentes, contraintes de sécurité et contrats d'API publique.

- mode zone, projet complet, ou fichiers touchés dans la session ;
- renames prudents pour rendre le code auto-documenté ;
- validation par zone et couverture persistante.

## Installation

Thoth s'installe **localement** avec `make` : chaque skill est copié dans le répertoire de l'agent visé (miroir exact par skill via `rsync --delete`, sans toucher aux skills portant d'autres noms).

```bash
# 1. Récupérer le dépôt
git clone https://github.com/Seeky91/thoth
cd thoth

# 2. Installer pour ton agent
make install-claude        # → ~/.claude/skills/
make install-codex         # → ~/.agents/skills/
make install-all           # les deux (équivaut à `make install`)

# Un seul skill :
make install-claude SKILL=maintainability
```

Sans suffixe, les alias nus `make install`, `make diff` et `make uninstall` ciblent **les deux agents**. La forme générique `make install AGENT=claude|codex|all` est équivalente.

| Commande | Rôle |
|---|---|
| `make list` | État d'installation par agent |
| `make diff-claude` / `make diff-codex` `[SKILL=x]` | Compare le dépôt et l'installation |
| `make uninstall-claude` / `make uninstall-codex` `[SKILL=x]` | Désinstalle (avec confirmation) |
| `make validate` | Valide structure, symlinks et manifests |

> **En plugin.** Le dépôt porte aussi les manifests `.claude-plugin/plugin.json` et `.codex-plugin/plugin.json`. Installé comme **plugin** (via marketplace) plutôt qu'en local, le skill est préfixé du nom du plugin (`thoth`) : `/thoth:maintainability`, `/thoth:performance-cycle`, etc. Le corps du skill est identique — seul le nom d'invocation change.

## Utilisation

Les deux agents chargent les mêmes `SKILL.md` ; seule la syntaxe d'invocation explicite diffère. Chaque skill reste aussi invocable **implicitement** quand ta demande correspond à sa description.

| Intention | Claude Code | Codex |
|---|---|---|
| Audit de maintenabilité automatique | `/maintainability` | `$maintainability audite la zone la plus pertinente` |
| Audit ciblé | `/maintainability src/api` | `$maintainability audite src/api` |
| Tableau de bord | `/maintainability list` | `$maintainability affiche le tableau de bord` |
| Re-vérification des pendings | `/maintainability update` | `$maintainability re-vérifie les pendings` |
| Un cycle maintainability autonome | `/maintainability-cycle` | `$maintainability-cycle lance un cycle` |
| Plusieurs cycles autonomes | `/maintainability-cycle 5` | `$maintainability-cycle lance 5 cycles` |
| Cycles sans clôture documentaire | `/maintainability-cycle 5 --no-doc-cleanup` | `$maintainability-cycle lance 5 cycles sans doc-cleanup` |
| Audit de performance automatique | `/performance` | `$performance audite la cible la plus pertinente` |
| Performance ciblée par path | `/performance src/api` | `$performance audite src/api` |
| Performance ciblée par feature | `/performance feature checkout` | `$performance audite la feature checkout` |
| Board performance | `/performance list` | `$performance affiche le tableau de bord` |
| Re-mesure des pendings | `/performance update` | `$performance re-mesure les pendings` |
| Double-check d'un finding | `/performance double-check PERF-001` | `$performance double-check PERF-001` |
| Un cycle performance autonome | `/performance-cycle` | `$performance-cycle lance un cycle` |
| Plusieurs cycles performance | `/performance-cycle 5` | `$performance-cycle lance 5 cycles` |
| Nettoyage ciblé | `/doc-cleanup src/api` | `$doc-cleanup nettoie src/api` |
| Fichiers touchés dans la session | `/doc-cleanup session` | `$doc-cleanup nettoie les fichiers touchés` |
| Liste explicite de fichiers | `/doc-cleanup session --files src/a.ts src/b.ts` | `$doc-cleanup session sur src/a.ts et src/b.ts uniquement` |
| Projet complet | `/doc-cleanup project` | `$doc-cleanup nettoie tout le projet` |

### État généré dans les projets audités

Les skills écrivent leur suivi dans un répertoire neutre, partagé entre les deux agents, à la racine du projet audité :

```text
.code-quality/
├── maintainability_history.md
├── maintainability_findings.md
├── maintainability_resolved_archive.md
├── performance_history.md
├── performance_findings.md
├── performance_resolved_archive.md
└── doccleanup_coverage.md
```

Les campagnes multi-cycles ajoutent temporairement `maintainability_campaign.md` ou `performance_campaign.md` : obligatoires pour `N > 1`, supprimés après une clôture normale, conservés uniquement pour reprendre une campagne interrompue.

## Architecture

Le contenu métier de chaque skill vit une seule fois sous `skills/` :

```text
skills/
├── maintainability/          ┐
│   ├── SKILL.md              │  skills atomiques
│   ├── agents/openai.yaml   │  (SKILL.md + métadonnées Codex
│   └── references/          │   + références chargées à la demande)
├── performance/             │
│   └── …                    │
├── doc-cleanup/             ┘
│   └── …
├── maintainability-cycle/    ┐  orchestrateurs
│   ├── SKILL.md             │  (SKILL.md + agents/openai.yaml)
│   └── agents/openai.yaml   ┘
└── performance-cycle/
    └── …
```

Les vues de projet sont de simples symlinks vers cette source unique, et le dépôt porte les deux manifests de distribution :

```text
.claude/skills/   → vue Claude Code  (symlinks vers ../../skills/<name>)
.agents/skills/   → vue Codex        (symlinks vers ../../skills/<name>)
.claude-plugin/plugin.json
.codex-plugin/plugin.json
```

Il n'y a pas de fichiers de commandes séparés : chaque skill est nativement invocable en slash command, les arguments étant interprétés par le dispatch du `SKILL.md`.

## Contribuer

Ajouter un skill :

1. Créer `skills/<name>/SKILL.md` et ses ressources éventuelles.
2. Ajouter `skills/<name>/agents/openai.yaml` pour les métadonnées Codex.
3. Créer les symlinks `.claude/skills/<name>` et `.agents/skills/<name>` vers `../../skills/<name>`.
4. Lancer `make validate`.

`make validate` vérifie la structure des skills, la portabilité du frontmatter (intersection Claude/Codex), les références citées, les symlinks et la validité des manifests JSON.

## Licence

[MIT](LICENSE)
