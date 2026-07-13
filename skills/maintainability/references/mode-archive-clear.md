# Mode : archive-clear

Référence chargée par SKILL.md en mode **archive-clear**, avec `[--all|--keep N|--older-than <duration>]`. Purge `maintainability_resolved_archive.md` selon les critères. Toujours confirmer avant d'écrire. Les conventions transverses (date déterministe) vivent dans SKILL.md et s'appliquent ici.

## Flux

1. Si l'archive n'existe pas : abort avec *"Pas d'archive sur ce projet, rien à clearer."*
2. Parser les entrées de l'archive : extraire `ID` et la date `(résolu YYYY-MM-DD)` du titre.
3. Calculer `dropped` / `kept` selon les args :
   - **Défaut** (aucun flag) : drop entrées résolues il y a > 6 mois.
   - `--older-than <duration>` : format `<entier><unité>` avec unités `d`/`m`/`y` (`m`=30j, `y`=365j). Ex. `6m`, `1y`, `90d`. Parse échoué → *"Durée `<input>` non reconnue. Format attendu : `6m`, `1y`, `90d`."*
   - `--keep N` : conserver les N entrées les plus récentes (date du titre).
   - `--all` : drop tout.
4. **Recompute des compteurs d'IDs, en mémoire** : scanner findings + archive complète **avant** la suppression et calculer le futur header `<!-- id_counters: ... -->`. Garantit que les IDs futurs continuent de monter monotonement. **Ne rien écrire à ce stade** — la confirmation n'a pas encore eu lieu.
5. **Confirmation utilisateur** : utiliser le template `archive-clear:confirm-all` (cas `--all`) ou `archive-clear:confirm-partial` (autres cas).
6. **Après confirmation seulement**, appliquer les deux écritures ensemble : le header recalculé dans `maintainability_findings.md`, puis l'archive réécrite avec les seules entrées `kept`. Si `kept = []` (cas `--all`) : supprimer le fichier (recreation paresseuse au prochain débordement). Refus ou annulation → aucune écriture, header compris.
7. Annoncer en chat via le template `archive-clear:done`.

## Garde-fous

- Aucune modification sur `maintainability_findings.md` (sauf le header de compteurs) ni sur `maintainability_history.md`. Les références dangling depuis history vers une entrée archivée disparue restent — convention "voir git".
- Confirmation obligatoire dans tous les cas, même par défaut — et **aucune écriture avant elle** (le recompute de l'étape 4 reste en mémoire jusqu'à l'étape 6).
- Si le filtre ne capture aucune entrée : *"Filtre `<critère>` ne capture aucune entrée. Archive inchangée."* — pas d'écriture, pas même du header.

## Invariants de fin de mode (archive-clear)

Avant de rendre la main, valider (une case **non applicable** est considérée cochée ; cf. SKILL.md > *Invariants de fin de mode* pour la règle transverse) :

- Archive réécrite avec les seules entrées `kept` (ou supprimée si `kept = []`, cas `--all`).
- Header `<!-- id_counters: ... -->` recomputed — **calculé avant** la suppression, **écrit après** la confirmation, jamais écrit si l'utilisateur annule.
- Pas d'écriture sur history ni sur findings (sauf le header de compteurs).
