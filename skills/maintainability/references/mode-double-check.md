# Mode : double-check

Référence chargée par SKILL.md en mode **double-check** avec un ID, par exemple `DUP-007`. Approfondit un finding existant, ne crée pas de nouveau finding. Les conventions transverses (date déterministe, écritures en delta) vivent dans SKILL.md et s'appliquent ici.

## Flux

1. **Localiser le finding** : scanner `maintainability_findings.md`, trouver l'entrée `### <ID> — …`. Si absent → demander à l'utilisateur un ID valide (ne pas inventer).
2. **Lire le fichier référencé** intégralement, plus les fichiers voisins / importeurs. **Finding multi-fichiers** (bullet `Localisation` énumérant plusieurs emplacements) : lire **tous** les fichiers listés ; le blast radius devient l'union des call sites / tests / surfaces touchées par chaque emplacement.
3. **Trace** :
   - **Localisation complète** : tous les call sites, imports, références au symbole/pattern concerné.
   - **Blast radius** : tests qui touchent la zone, surfaces publiques affectées, couplages cachés (ce qui casse si on applique le fix proposé).
   - **Faisabilité de la reco initiale** : tient-elle ? Y a-t-il une contrainte (typage, signature publique, dépendance circulaire, contrat externe) qui invaliderait la reco ?
   - **Effort estimé** : `S` (≤2h), `M` (≤1j), `L` (>1j, plusieurs commits). Distinct de la faisabilité.
   - **Δ LoC affiné** : ré-estimer à la lumière du blast radius et des contraintes. Si l'écart avec l'estimation initiale est > 50 %, expliquer brièvement pourquoi.
   - **Reco affinée** : ajustée à la lumière des contraintes découvertes, ou alternatives si l'originale ne tient plus.
   - **Verdict** : GO / NO-GO / GO-mais-après-X.
   - **Apport** (uniquement si Verdict GO ou GO-mais-après-X — jamais sur NO-GO) : une seule phrase concrète qui nomme ce qui s'améliore. Une formulation générique type *"améliore la maintenabilité"* reste valable si elle est étoffée par le **comment** (ce qui rend le code plus maintenable, concrètement, dans ce cas précis).
4. **Possibilité de reclasser la sévérité** : si l'analyse montre que HIGH était excessif (effort L mais impact en réalité MED), proposer le changement à l'utilisateur. **Ne pas changer l'ID.**

## Écriture dans le fichier findings

Ajouter une section `Double-check (YYYY-MM-DD) :` dans l'entrée existante du finding, **juste après la bullet `Status:`** (dernière position, conformément à l'ordre normatif des bullets — cf. `references/file-formats.md > Règles de format` et son exemple `SIZ-003`). Format : une bullet unique contenant tous les éléments de la trace.

Si la sévérité change : modifier également le titre de l'entrée (`### SIZ-003 — MED — core/api_handler.py`).

## Sortie

1. Récap du verdict via le template `double-check:output`.
2. Proposition d'action via le template `double-check:proposition` (variante filtrée selon verdict GO/GO-mais-après-X vs NO-GO).

## Action selon le choix utilisateur

- **Fix maintenant** (verdict GO / GO-mais-après-X) :
  1. Plan (1-3 lignes : fichiers touchés, ordre, Δ LoC attendu) — réutilise `Reco affinée`.
  2. Plan affiché, OK explicite. Si OK, exécuter.
  3. Avant le marquage `Resolution`, lancer la suite de tests (détectée via marqueurs : `cargo test`, `npm test`, `pytest`, `go test ./...` ; sinon demander la commande). Tests OK → flux résolution intra-session (cf. `references/mode-update.md > Détection intra-session`). Tests KO → arrêt, ne pas marquer.
  4. Cascade re-check automatique (cf. `references/cascade.md`).
  5. Récap final via `resolution:done`.
- **Archiver** (verdict NO-GO) : move Pending → Resolved au format compact, `Resolution: archivé après double-check (NO-GO motivé : <raison>)`. Compléter la ligne history correspondante. Cap Resolved respecté (cf. `references/file-formats.md > Cycle de vie d'un finding` étape 5).
- **Plus tard** / **Garder pending** : terminer sans écriture supplémentaire. Le Double-check (date) est déjà persisté.

## Invariants de fin de mode (double-check)

Avant de rendre la main, valider (une case **non applicable** est considérée cochée ; cf. SKILL.md > *Invariants de fin de mode* pour la règle transverse) :

- Section `Double-check (YYYY-MM-DD) :` ajoutée à l'entrée du finding ciblé.
- Si reclassification de sévérité validée : titre `### <ID> — <NEW-SEV> — …` modifié.
- Si l'utilisateur a choisi *Fix maintenant* à la proposition : invariants de *Résolution intra-session* (`references/mode-update.md`) applicables.
- Si l'utilisateur a choisi *Archiver* (NO-GO) : entrée déplacée Pending → Resolved au format compact, `Resolution: archivé après double-check (NO-GO motivé : <raison>)`, ligne history correspondante complétée, cap Resolved respecté.
