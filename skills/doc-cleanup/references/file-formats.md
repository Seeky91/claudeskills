# Format d'état & templates de sortie

Référence chargée quand un mode écrit l'état ou produit une sortie chat.

## `<STATE_DIR>/doccleanup_coverage.md`

**Ledger de couverture append-only.** Une ligne par passe de nettoyage, **préfixée en tête** (plus récent en premier). Jamais trimmé.

### Pourquoi markdown, pourquoi un seul fichier

L'état est en markdown (lisible, git-diffable, éditable à la main) et **minimal par choix** : le livrable du skill est le *code nettoyé*, pas un registre de findings. Le ledger ne sert qu'à **deux choses** — savoir où reprendre une campagne (couverture par zone) et garder une trace datée des passes. Pas de findings, pas d'IDs, pas de cycle de vie : ne pas réintroduire la machinerie de `maintainability` ici.

### Format

```markdown
# Doc-cleanup coverage

- 2026-06-25 — services/api/ — project — 34 supprimés, 5 renames, 2 docs dé-driftées — tests OK
- 2026-06-25 — src/utils/format.ts — zone — 8 supprimés, 1 rename — tests OK
- 2026-06-24 — session (7 files) — session — 22 supprimés, 3 renames, 1 dé-driftée — tests OK
- 2026-06-23 — services/billing/ — project — 0 supprimés (déjà propre) — tests OK
```

- Ligne : `- YYYY-MM-DD — <scope> — <mode> — <N> supprimés, <M> renames, <K> docs dé-driftées — <validation>`
- `<scope>` = chemin (dossier/fichier) pour `project`/`zone` ; `session (<N> files)` ou `session --touched (<N> files)` pour `session`.
- `<mode>` ∈ `project` | `zone` | `session`.
- `<validation>` = `tests OK` | `tests KO (<détail>)` | `validation dégradée (<ce qui a tourné>)`.
- Stats à 0 acceptées (`0 supprimés (déjà propre)`) — c'est une couverture valide, elle mémorise que la zone a été vue.
- **Couverture (reprise `project`)** : `zones_couvertes` = chemins des lignes `project`/`zone` dont la validation n'est **pas** `tests KO` — une passe en échec garde sa trace (la ligne s'écrit quand même) mais ne compte pas comme couverture : la zone revient en pending à la reprise. `validation dégradée` compte comme couverture (le nettoyage a bien eu lieu ; c'est l'environnement qui manque de tests). Les lignes `session` ne comptent pas comme couverture de zone (cf. `references/mode-project.md > C`).
- **Staleness** : la date de couverture sert aussi à **revalider**. Une zone couverte dont le code a bougé depuis (activité `git log` de date postérieure **ou égale** à la date de couverture) revient en pending au prochain `project` — du bruit a pu réapparaître. L'égalité compte comme stale : à granularité jour, impossible de savoir si le commit précède ou suit la passe, et re-balayer une zone propre coûte moins que rater du code nouveau. Auto-correcteur : re-balayer une zone redevenue propre ré-écrit une ligne à jour (cf. `references/mode-project.md > C`). Sans cette comparaison, la couverture par chemin seul deviendrait faussement rassurante dans la durée.

## Templates de sortie chat

Suivre l'ossature à la lettre (le contenu des placeholders s'adapte). Conventions transverses (header, trailer, séparation récap/proposition) : cf. SKILL.md.

### `zone:selection` — Annonce de la zone auto (mode zone, sans arg)

```
Je propose : <zone> (<motif : jamais nettoyée | moins récemment nettoyée le YYYY-MM-DD>, <LoC>)
Alternatives : <zone-alt-1> (<motif>) ou <zone-alt-2> (<motif>)
```

### `zone:summary` — Zone nettoyée

```
Doc-cleanup terminé — <zone>

<N> commentaires supprimés, <M> renames, <K> docs dé-driftées.
Renames : <ancien → nouveau (S sites)>, … (ou « aucun »)
Validation : <tests OK | tests KO : détail | dégradée>

Files mis à jour : <STATE_DIR>/doccleanup_coverage.md (+1 ligne). Code nettoyé non commité — review via `git diff`.
```

### `project:plan` — Plan de campagne (avant go-ahead)

```
Campagne doc-cleanup — <projet>

Zones : <pending>/<Z> à traiter<, reprise : <C> déjà couvertes>.
Validation : <commande détectée | à confirmer>.
Mode : nettoyage agressif, sérialisé zone par zone. Rien ne sera commité (review sur le diff final).

Je lance ? (go / ajuster la commande de validation / cibler une zone précise en mode zone)
```

### `project:zone-progress` — Avancement par zone (pendant la campagne)

```
[<i>/<pending>] <zone> — <N> supprimés, <M> renames, <K> dé-driftées — <tests OK|KO>
```

### `project:summary` — Fin de campagne

```
Campagne doc-cleanup terminée — <projet>

<Z-traitées> zones traitées<, <restantes> restantes (arrêt sur <raison>)>.
Totaux : <ΣN> commentaires supprimés, <ΣM> renames, <ΣK> docs dé-driftées.

Files mis à jour : <STATE_DIR>/doccleanup_coverage.md (+<Z-traitées> lignes). Tout est non commité — review via `git diff`, puis commit à ta main.
```

### `session:summary` — Session nettoyée

```
Doc-cleanup session terminé — <N> fichiers

<ΣN> commentaires supprimés, <ΣM> renames, <ΣK> docs dé-driftées.
Renames : <ancien → nouveau (S sites)>, … (ou « aucun »)
Validation : <tests OK | KO : détail | dégradée>

Files mis à jour : <STATE_DIR>/doccleanup_coverage.md (+1 ligne). Code nettoyé non commité — review via `git diff`.
```

### `session:none` — Rien à nettoyer

```
Aucun fichier source modifié dans l'arbre de travail. Si ton travail de session est déjà commité, invoque `doc-cleanup` en mode zone avec un chemin explicite.
```
