# Templates de sortie chat

Référence chargée par SKILL.md avant chaque sortie chat d'un mode. Les modes citent un template par nom (e.g. `audit:summary`) ; ce fichier en donne le format normatif. Les conventions transverses (header, trailer, séparation récap / proposition d'action) sont définies dans SKILL.md — pas répétées ici.

Suivre ces templates **à la lettre** (structure, headers, trailers, placeholders). Le contenu des placeholders s'adapte au contexte, mais l'ossature ne change pas. Garde-fou contre la dérive de format d'une invocation à l'autre.

## `selection:proposition` — Annonce de la zone candidate (mode audit auto)

```
Je propose : <zone> (<motif>, <taille LoC>)
Alternatives : <zone-alt-1> (<motif>, <taille>) ou <zone-alt-2> (<motif>, <taille>)
```

- `<motif>` reflète à la fois la nature de la zone et son état d'activité (cf. `references/mode-audit.md > C. Signal d'activité`) :
  - **Couverture** : `jamais auditée`, `god file`, `pipeline traçable`, `landmark architectural`, `composition root locale`, `façade publique structurante`.
  - **Activité** : `chaude — <N> commits depuis le dernier audit (YYYY-MM-DD)`, `froide — auditée le YYYY-MM-DD, aucune activité hors-maintainability depuis`.
  - Les deux peuvent se combiner : `pipeline traçable, chaud — 12 commits depuis 2026-03-08`.
  - En mode dégradé (repo non-git) : omettre toute mention d'activité, ne garder que le motif de couverture.
- 2 alternatives par défaut. Si l'inventaire en propose moins, lister celles disponibles. Idéalement, montrer un mélange (une zone du niveau de priorité retenu + une d'un niveau différent pour donner du choix à l'utilisateur).

## `audit:summary` — Audit avec findings

```
Audit terminé — <zone>

<N> nouveaux findings (<X> HIGH, <Y> MED, <Z> LOW) :
  <ID> (<SEV>, Δ ~<delta>) — <observation-courte>
  ... (un par finding, ordre : HIGH > MED > LOW, ID croissant à l'intérieur)

Δ LoC net estimé si tout est appliqué : ~<sum> (somme algébrique — suppressions et ajouts confondus ; le détail signé par finding est ci-dessus).

Files mis à jour : .claude/maintainability_findings.md (+<N> findings), .claude/maintainability_history.md (+1 ligne).
Pour creuser un item à la main : /maintainability-double-check <ID-exemple>.
```

Suivi du bloc `audit:proposition` ou `audit:proposition-min` selon le nombre de findings.

## `audit:clean` — Audit zone propre (0 findings)

```
Audit terminé — <zone>. Aucun finding produit, zone propre sur toutes les dimensions examinées.

Files mis à jour : .claude/maintainability_history.md (+1 ligne `0 findings (clean)`).
```

Pas de bloc de proposition derrière (rien à proposer).

## `audit:proposition` — Proposition de double-check autonome (3 options)

```
Tu peux aussi me laisser creuser en autonomie. Sur quoi ?
  (a) un panel de quick-wins : <ID-1>, <ID-2>, <ID-3> — <K> findings au fix court et peu de blast radius.
  (b) le finding le plus structurant : <ID-heavy> — <résumé observation>.
  (c) rien, je verrai plus tard.
```

Si aucun quick-win ne tient les critères : omettre (a). Si aucun HIGH/MED structurant : (b) prend le plus grand `|Δ LoC|` avec avertissement *"(pas un finding lourd au sens classique)"*.

## `audit:proposition-min` — Variante 1 ou 2 findings

```
Veux-tu que je fasse un double-check autonome sur <ID> ?
```

Si 2 findings : citer les deux IDs.

## `crosscut:dim-proposition` — Annonce de la dimension candidate (mode crosscut)

```
Je propose un crosscut sur : <DIM> (<motif>)
Alternatives : <DIM-alt-1> (<motif>) ou <DIM-alt-2> (<motif>)
```

- `<motif>` ∈ {`jamais crosscutée`, `non vue depuis Nj`, `signal fort sur <zones>`, `aléatoire pondéré`, etc.}
- 2 alternatives par défaut, parmi les éligibles `{DUP, INC, DRF, DED, BND, ARC}` hors `<DIM>` proposé. Si moins disponible (rolling restrictif), lister celles disponibles.

## `crosscut:summary` — Crosscut avec findings

```
Crosscut <DIM> terminé

<N> nouveaux findings (<X> HIGH, <Y> MED, <Z> LOW) :
  <ID> (<SEV>, Δ ~<delta>, <K> fichiers) — <observation-courte>
  ... (un par finding, ordre : HIGH > MED > LOW, ID croissant à l'intérieur)

Δ LoC net estimé si tout est appliqué : ~<sum> (somme algébrique — suppressions et ajouts confondus ; le détail signé par finding est ci-dessus).

Files mis à jour : .claude/maintainability_findings.md (+<N> findings), .claude/maintainability_history.md (+1 ligne `crosscut:<DIM>`).
Pour creuser un item à la main : /maintainability-double-check <ID-exemple>.
```

`<K> fichiers` = nombre d'emplacements distincts listés dans la `Localisation` du finding (1 pour un finding mono-fichier comme `DED` global, ≥2 pour `DUP`/`INC`/`DRF`/`BND`).

Suivi du bloc `audit:proposition` ou `audit:proposition-min` selon le nombre de findings (les templates de proposition d'action sont génériques sur la nature de l'audit — pas de version dédiée crosscut).

## `crosscut:clean` — Crosscut sans finding

```
Crosscut <DIM> terminé. Aucun finding cross-zone produit sur cette dimension.

Files mis à jour : .claude/maintainability_history.md (+1 ligne `crosscut:<DIM> — 0 findings (clean)`).
```

Pas de bloc de proposition derrière (rien à proposer).

## `list:dashboard` — Tableau de bord (read-only)

```
Maintainability board — <projet>

Pending (<total>) :
  HIGH (<n>) : <ID-1> (<desc-50char>), <ID-2> (<desc>), …
  MED  (<n>) : <ID> (<desc>), …
  LOW  (<n>) : <ID> (<desc>), …

Stale (<n>) — à relocaliser, marquer résolu, ou archiver :
  <ID> — stale-after-<ID-cause> (fix du <date>, localisation invalidée)
  <ID> — stale (<raison>)

Recently resolved (30 derniers j.) :
  <ID> (<SEV>) — <date> — <résumé-fix>

Rolling (N=<N>) :
  <date> — <zone> — <N findings (status)>
  ... (N lignes, les plus récentes en premier)

Rolling crosscut (Nx=<Nx>) :
  <date> — crosscut:<DIM> — <N findings (status)>
  ... (Nx lignes max, les plus récentes en premier)

Batches suggérés (<K>) :

  B1 · <zone-ou-multi> · Δ ~<sum> · <K> findings  [★ recommandé : <raison>]
       <ID·SEV> + <ID·SEV> + … — <rationale 1 ligne>

  B2 · <zone> · Δ ~<sum> · <K> findings
       <ID·SEV> + … — <rationale>

Je propose `double-check B<reco>` (recommandé).
Sinon : `fix B<reco>` direct, un autre batch (`double-check B<n>` / `fix B<n>`), ou `rien`.
```

Omissions :
- Section Stale : omise si zéro.
- Section Recently resolved : afficher *"Aucun résolu dans les 30 derniers jours."* si zéro.
- Section Batches : si zéro batch détecté, remplacer par *"Pas de batch évident détecté — les pendings sont indépendants."* et **omettre** le prompt d'action.
- Si zéro pending actif : remplacer la ligne par `Pending actifs (0) : aucun finding actionnable.`.
- Section `Rolling crosscut` : omise entièrement si aucune ligne `crosscut:*` dans l'history. Si moins de `Nx` lignes crosscut existent, lister celles disponibles (pas de padding).

## `update:summary` — Récap update

```
Update terminé — <projet>

Re-vérifié <N> pendings :
  Résolus (<n>) : <ID-1>, <ID-2>
  Auto-relocalisés (<n>) : <ID> (<old-path> → <new-path>, <signal>)
  Auto-résolus stale (<n>) : <ID> (<raison : pattern dissout / commit <hash>>)
  Toujours présents (<n>) : <ID-3>, <ID-4>, <ID-5>
  Stale (<n>) : <ID> (<raison investigation inconclusive>)
  Stale-after (<n>) : <ID> (stale-after-<ID-cause> préservé)
  Archivés (<n>) : <ID-1>, <ID-2> (cap Resolved atteint)

Files mis à jour : .claude/maintainability_findings.md, .claude/maintainability_history.md[, .claude/maintainability_resolved_archive.md].
```

Lignes à 0 : omises (e.g. pas de stale-after → pas de ligne, pas d'auto-relocalisé → pas de ligne).

## `double-check:output` — Sortie standard d'un double-check

```
Double-check <ID> — <verdict>

Localisation : <path:line>
Blast radius : <N> imports, <N> tests touchés, <surfaces>
Faisabilité : <résumé>
Effort : <S|M|L> (~<estimation temps/commits>)
Δ LoC affiné : ~<delta> (<comparaison estimation initiale si écart >50%>)
Reco affinée : <reco>
Verdict : <GO|NO-GO|GO-mais-après-X>
Apport : <phrase concrète> (uniquement si verdict GO ou GO-mais-après-X)

[Extraits de code des call sites pertinents si utiles à la décision]

Files mis à jour : .claude/maintainability_findings.md (section Double-check ajoutée[, titre amendé : <SEV> → <NEW-SEV>]).
```

## `double-check:autonomous-batch` — Sortie agrégée d'un panel quick-wins ou batch fix

```
Double-check autonome terminé sur <K> <findings|quick-wins> :
  <ID-1> — <verdict> (Δ <delta>, <résumé-1-ligne>) — Apport : <phrase>
  <ID-2> — <verdict> (Δ <delta>, <résumé>) — Apport : <phrase>
  <ID-3> — <verdict> (Δ <delta>, <résumé>) [pas d'Apport si NO-GO]

Files mis à jour : .claude/maintainability_findings.md (+<K> sections Double-check).
```

## `double-check:proposition` — Proposition d'action après double-check simple

Affiché juste après `double-check:output`. Options filtrées selon le verdict.

**Variante verdict GO / GO-mais-après-X** :
```
Que faire pour <ID> ?
  (a) Fix maintenant — plan + tests + résolution intra-session.
  (b) Plus tard — le Double-check est écrit, tu pourras y revenir via /maintainability-list.
```

**Variante verdict NO-GO** :
```
Verdict NO-GO. Que faire pour <ID> ?
  (a) Archiver — marquer résolu avec motif `archivé après double-check (NO-GO : <raison-courte>)`.
  (b) Garder pending — utile si le NO-GO mérite re-statuation plus tard.
```

## `double-check:autonomous-batch-proposition` — Proposition d'action après batch double-check

Affiché juste après `double-check:autonomous-batch`. Options filtrées selon le mix de verdicts du batch.

**Variante mix GO + NO-GO** :
```
Que faire des <K> findings double-checkés ?
  (a) Fix tous les GO dans l'ordre : <ID-GO-1> → <ID-GO-2> → … (raison : <critère>). Archive auto des NO-GO : <ID-NG-1>, <ID-NG-2>.
  (b) Fix un seul GO — précise lequel parmi <liste-GO>.
  (c) Archiver les NO-GO seulement, garder les GO pending.
  (d) Rien.
```

**Variante tous GO** :
```
Que faire des <K> findings (tous GO) ?
  (a) Fix tous dans l'ordre : <ID-1> → <ID-2> → … (raison : <critère>).
  (b) Fix un seul — précise lequel parmi <liste>.
  (c) Rien.
```

**Variante tous NO-GO** :
```
Les <K> findings sont tous NO-GO. Que faire ?
  (a) Archiver tous (motif individuel par finding).
  (b) Garder pending.
```

**Règles d'ordering pour l'option « Fix tous »** (variantes mix et tous GO), par priorité décroissante :
1. **Dépendances explicites** : un verdict `GO-mais-après-<ID>` impose que `<ID>` soit fixé avant, **si** `<ID>` est dans le batch (sinon noter la dépendance externe et placer le finding dans l'ordre naturel).
2. **Blast radius croissant** : les findings au blast radius le plus contenu d'abord (moins de risque de casser le suivant).
3. **Path partagé** : regrouper les findings touchant le même fichier (une seule série de changements par fichier).
4. **Tie-break** : ID croissant.

La raison citée dans la sortie reprend le critère qui a tranché (ex. `couplage explicite`, `blast radius bas d'abord`, `regroupement par fichier`).

## `resolution:confirm` — Confirmation intra-session (avec ou sans cascade)

**Variante simple (overlap = 0, pas de cascade)** :
```
Ce fix résout <ID-primaire> (Δ <delta>). Je marque comme résolu ?
```

**Variante avec cascade** :
```
Ce fix résout <ID-primaire> (Δ <delta>). Cascade re-check sur <K> pendings touchant les mêmes fichiers :
  - <ID-cascade-1> — pattern absent → résolu collatéralement
  - <ID-cascade-2> — pattern toujours présent (l. <ancien> → <nouveau>, à mettre à jour)
  - <ID-cascade-3> — <fichier> renommé → stale-after-<ID-primaire>

Je marque <ID-primaire>[+ <IDs-cascadés>] résolus[, mets à jour <IDs-shift>][, et tag <IDs-stale> stale-after] ?
```

## `resolution:done` — Confirmation finale intra-session

```
Files mis à jour : .claude/maintainability_findings.md (move <ID> → Resolved[+ <N> cascadés][+ <M> stale-after]), .claude/maintainability_history.md (résolus <ID>+...).
```

Si push-back partiel à l'étape `resolution:confirm` : la ligne reflète seulement ce qui a été appliqué.

## `cascade:recap-batch` — Récap final d'un `fix B<n>` (mode list)

```
<X>/<Y> résolus, Δ LoC total mesuré : <sum>, commits : <hash1>+<hash2>+...
Cascade re-check : <N> résolu(s) collatéralement (<IDs>), <M> stale-after (<IDs>).
```

Si overlap = 0 sur tous les fixes du batch : la ligne `Cascade re-check :` est **omise**.

## `archive-clear:confirm-all` — Confirmation purge totale

```
Confirme la suppression totale de l'archive (<X> entrées). Tape 'oui' pour confirmer.
```

Attend "oui" littéral. Tout autre input → annoncer *"Annulé."* et terminer sans écrire.

## `archive-clear:confirm-partial` — Confirmation purge partielle

```
<X> entrées seront supprimées : <ID-1>, <ID-2>, … — <Y> conservées (la plus récente : <ID> du <date>). Confirmer ? (y/N)
```

## `archive-clear:done` — Récap purge

```
Archive clearée — <X> supprimées, <Y> conservées. Compteurs : DUP=<n>, SIZ=<n>, ...

Files mis à jour : .claude/maintainability_resolved_archive.md[, .claude/maintainability_findings.md (header id_counters)].
```
