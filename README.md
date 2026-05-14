# Claude Skills

Une collection de skills réutilisables pour Claude Code.

## Skills disponibles

### 🛠 maintainability

Audit de maintenabilité ciblé avec :

* suivi des findings via des IDs stables
* état persistant par projet (`.claude/`)
* historique d'audits **append-only** : le rolling à éviter (N dernières zones) est une vue sur le journal, la couverture historique scanne le fichier entier — pas de zone re-proposée par perte de mémoire après quelques audits
* **sélection auto qui pousse vers les zones effectivement modifiées** : signal d'activité (git log croisé avec les fixes maintainability) qui priorise les zones jamais auditées et les zones « chaudes » (du code utilisateur a bougé depuis le dernier audit) avant les zones froides
* **sweeps cross-zone** sur une dimension transverse (`DUP`/`INC`/`DRF`/`DED`/`BND`) — rolling crosscut indépendant (`Nx = 5`) pour cycler naturellement sur les 5 dimensions éligibles
* re-vérification et approfondissement des problèmes
* re-vérification en cascade automatique après chaque fix (les findings dont la localisation chevauche le diff sont rechecké, marqués résolus collatéralement, ou taggés `stale-after`)
* sorties chat normalisées via templates nommés (`audit:summary`, `list:dashboard`, `resolution:confirm`, …) — forme stable d'une invocation à l'autre

Permet de détecter et suivre la dette de maintenabilité dans le temps sans repasser toujours sur les mêmes zones.

---

## Installation

Depuis la racine de ce dépôt :

```bash
make install     # sync repo → ~/.claude (skill + slash commands)
make diff        # voir ce qui diffère entre repo et ~/.claude
make uninstall   # retirer le skill + ses commands de ~/.claude (avec confirmation)
```

Le skill est composé d'un `SKILL.md` (hub de contrôle) et de cinq fichiers de référence chargés à la demande :

* `references/file-formats.md` — format des fichiers d'état (`maintainability_history.md`, `maintainability_findings.md`, `maintainability_resolved_archive.md`), compteur d'IDs, cycle de vie.
* `references/cascade.md` — algorithme de la re-vérification en cascade post-fix.
* `references/templates.md` — templates normatifs des sorties chat.
* `references/dimensions.md` — catalogue des 11 dimensions seed (`DUP`, `CPX`, `SIZ`, …) et cadrage strict d'`IDM`.
* `references/quality.md` — grille de sévérité, garde-fous anti-bruit (« quand ne PAS produire de finding »), convention `Δ LoC`.

Le `make install` copie l'ensemble dans `~/.claude/skills/maintainability/` et les slash commands dans `~/.claude/commands/` (sync via `rsync`, avec `--delete` côté skill pour garantir que `~/.claude` reflète exactement le repo).

Si tu préfères installer à la main :

```bash
mkdir -p ~/.claude/skills/maintainability ~/.claude/commands
cp -r .claude/skills/maintainability/SKILL.md .claude/skills/maintainability/references ~/.claude/skills/maintainability/
cp .claude/commands/maintainability*.md ~/.claude/commands/
```

---

## Utilisation

Le skill `maintainability` expose une famille de slash commands, une par mode. Chaque sous-commande possède son propre `argument-hint` dans l'autocomplétion.

### Commandes disponibles

#### 🔍 Audit automatique

```bash
/maintainability
```

* Sélectionne automatiquement une zone à auditer
* Propose des alternatives
* Lance l’audit après validation

---

#### 📁 Audit d’un scope précis

```bash
/maintainability <path>
```

* Audite directement le dossier ou fichier spécifié

---

#### 🌐 Sweep cross-zone sur une dimension transverse

```bash
/maintainability-crosscut
```

* Auto-propose une dimension parmi `{DUP, INC, DRF, DED, BND}` (rolling crosscut `Nx = 5`, signal préliminaire si toutes ont déjà été crosscutées)
* Scan **tout le projet** sur cette dimension après validation utilisateur
* Findings produits sont multi-fichiers (`Localisation` énumère tous les emplacements impliqués) et suivent le même cycle de vie que les findings d'audit zonal

---

#### 📊 Afficher le tableau de bord

```bash
/maintainability-list
```

* Liste les findings en cours
* Affiche les résolus récents (30 derniers jours)
* Montre le rolling zonal et le rolling crosscut (les `Nx` dernières dimensions crosscutées)
* Suggère des batches de findings groupables et marque le batch recommandé

---

#### 🔄 Mettre à jour les findings

```bash
/maintainability-update
```

* Re-vérifie tous les findings `pending`
* Marque ceux qui sont résolus
* **Self-heal sur les fichiers déplacés** : investigation auto via git history / lecture de diff / recherche pattern — auto-relocate si le pattern est retrouvé ailleurs, auto-résolu si dissout, ou tag `stale` / `stale-after-<ID>` + arbitrage utilisateur si signaux insuffisants

---

#### 🔎 Approfondir un finding

```bash
/maintainability-double-check <ID>
```

* Analyse en profondeur un finding existant
* Évalue le blast radius
* Affine la recommandation et l’effort
* Donne un verdict (GO / NO-GO)

---

#### 🗃 Purger l’archive des résolus

```bash
/maintainability-archive-clear [--all | --keep N | --older-than <durée>]
```

* Purge `maintainability_resolved_archive.md` selon le critère choisi
* Sans flag : supprime les entrées résolues il y a plus de 6 mois
* `--older-than <durée>` : seuil personnalisé (`90d`, `6m`, `1y`)
* `--keep N` : conserve uniquement les `N` entrées les plus récentes
* `--all` : vide totalement l’archive
* Demande confirmation avant écriture, recompute les compteurs d’IDs pour préserver leur monotonie

---

## Fichiers générés

Le skill maintient automatiquement plusieurs fichiers dans votre projet :

* `.claude/maintainability_history.md` — historique des audits
* `.claude/maintainability_findings.md` — liste des problèmes détectés (pending + resolved récents)
* `.claude/maintainability_resolved_archive.md` — archive des anciens findings résolus (au-delà de la limite de rétention)

---

## Objectif

Ce skill ne cherche pas à produire un audit ponctuel, mais à :

* couvrir progressivement tout le code
* prioriser les vrais problèmes
* suivre leur résolution dans le temps

---

## Licence

MIT
