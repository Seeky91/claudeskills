# Mode : crosscut

Référence chargée par SKILL.md en mode **crosscut**. Sweep cross-zone sur **une dimension** intrinsèquement transverse — repère les patterns qu'un audit zonal ne voit pas par construction (duplication entre zones, conventions divergentes, types parallèles, dead code global, violations de frontière). Les conventions transverses (date déterministe, écritures en delta) et la doctrine d'évaluation vivent dans SKILL.md et s'appliquent ici.

## A. Bootstrap

Même logique que `references/mode-audit.md > A. Bootstrap`. Si `<STATE_DIR>/maintainability_*.md` est absent : créer, annoncer *"Bootstrap maintainability sur ce projet, aucun historique préalable."*, puis continuer.

## B. Sélection de la dimension

Une seule dimension par invocation (granularité fine, plus précis qu'un sweep multi-dim). Éligibles : `DUP`, `INC`, `DRF`, `DED` (global), `BND`, `ARC`. Les autres (`CPX`, `SIZ`, `IDM`, `TST`, `CFG`, `DOC`) sont intrinsèquement intra-zone — non éligibles. (`ARC`, comme `DUP`, existe aussi en zonal — la cohésion se juge en audit, le couplage profond en crosscut, cf. `references/dimensions.md > Cadrage de la dimension ARC`.)

Algorithme :

1. **Lire `maintainability_history.md` en entier**. Parser les lignes `- YYYY-MM-DD — crosscut:<DIM> — …` (les lignes zonales sont ignorées pour ce calcul).
2. `Nx = 6` (override possible via `<!-- crosscut_rolling_size: M -->` en tête de history). Avec 6 dimensions éligibles et `Nx = 6`, le rolling actif est plein après 6 invocations consécutives — le système bascule alors naturellement en round-robin via le cas dégénéré ci-dessous (chaque dimension est re-crosscutée à son tour avant de revenir à la première).
3. Vues :
   - `rolling_actif_crosscut` = les `Nx` dimensions les plus récentes parmi les lignes crosscut.
   - `dimensions_jamais_crosscutées` = `{DUP, INC, DRF, DED, BND, ARC} − {toutes dimensions vues dans les lignes crosscut}`.
4. **Candidats** = `{DUP, INC, DRF, DED, BND, ARC} − rolling_actif_crosscut`.
5. **Pondération** :
   - Candidats dans `dimensions_jamais_crosscutées` → priorité haute.
   - Sinon, **signal préliminaire léger** sur les candidats restants (examen rapide, pas un mini-audit) : exports sans call site visible → `DED` ; symboles voisins / signatures similaires dans plusieurs zones → `DUP` ; imports d'internes inter-zones → `BND` ; types parallèles repérés → `DRF` ; styles multiples d'un même concept (3 paginations, 2 formats d'erreur) → `INC` ; cycles dans le graphe d'imports ou co-changes répétés inter-modules → `ARC`. Signaux mous → aléatoire pondéré.
6. **Annonce en chat** : template `crosscut:dim-proposition`.
7. **Validation utilisateur** : accepter, demander une alternative parmi les éligibles, ou imposer (y compris une dimension dans le rolling — l'utilisateur sait ce qu'il veut).

**Cas dégénéré** : si toutes les dimensions sont dans le rolling (situation courante dès que ≥ 6 crosscut ont eu lieu, avec `Nx = 6` par défaut), relâcher : proposer la moins récemment crosscutée, annoncer *"Toutes les dimensions sont dans le rolling — j'ai pris la moins récente : `<DIM>` (crosscut le YYYY-MM-DD)."*. C'est le mode round-robin attendu.

## C. Exécution

Pour la dimension validée, scanner **tout le projet** (mêmes exclusions que l'inventaire de l'audit zonal : `node_modules`, `.git`, `dist`, `build`, `vendor`, `target`, `.venv`, généré). L'inventaire des zones (`references/mode-audit.md > B`) sert de carte pour structurer les comparaisons inter-zones — pas de sélection, juste un découpage utile.

**Scalabilité (le crosscut n'a pas le garde-fou des 5000 LoC de l'audit zonal — `references/mode-audit.md > D.3` — par construction).** Un scan whole-project par lecture intégrale ne passe pas à l'échelle sur un gros repo, surtout `DUP`/`DED` qui comparent toutes les zones entre elles. Donc :
- **Privilégier l'outil** quand il est présent (cf. `references/dimensions.md > Outils de détection opportunistes` — `jscpd` repo-wide pour `DUP`, `knip`/`deadcode`/`cargo-udeps` pour `DED` global, etc.), puis trier les candidats au jugement. C'est le chemin nominal sur un projet de taille réelle.
- **Sinon, fallback borné** : échantillonner les zones les plus pertinentes via la carte d'inventaire (mêmes top-N que le garde-fou de coût du *Signal d'activité*) plutôt que de prétendre tout lire, et **annoncer la couverture partielle** en chat (« couverture : N zones sur M scannées — outil X absent »). Ne jamais laisser croire à une exhaustivité non tenue — et **persister cette restriction** : la ligne history est suffixée de `[partiel : N/M zones]` (cf. `references/file-formats.md > Lignes crosscut`). Sans cette annotation, un sweep partiel entrerait dans le rolling comme un sweep complet et la restriction se perdrait à la fin du chat.

Intent par dimension (jugement, pas algorithme prescriptif) :

- **`DUP`** : fonctions / blocs fonctionnellement équivalents dans plusieurs zones. Privilégier les helpers utilitaires (faciles à factoriser) ; ne pas forcer sur la business logic (souvent légitimement séparée).
- **`INC`** : concepts récurrents (pagination, error handling, logging, config, retries) implémentés différemment dans plusieurs zones.
- **`DRF`** : types / schemas parallèles divergeant accidentellement (`User` côté API + DB + client, `Order` côté service + worker, etc.).
- **`DED` global** : exports publics sans call site dans le projet. Borner aux candidats raisonnables (skip les API publiques de plug-in, hooks de framework, exports re-exposés via barrel files).
- **`BND`** : imports cross-zone qui contournent l'API publique (`_*` Python, `internal/` Go, deep relative imports). Chaque violation = un finding (ou groupe si pattern répété). Les **cycles inter-modules / fan-in-out** que révèle un outil de graphe d'imports relèvent d'`ARC`, pas de `BND` (cf. `references/dimensions.md > Frontières entre dimensions voisines` : `BND` = frontière déclarée violée, `ARC` = la structure elle-même est le défaut).
- **`ARC`** : forme du graphe de dépendances et placement des responsabilités à l'échelle du projet — cycles inter-modules, modules à fort fan-in × fort churn, couplage temporel (co-change git à travers les frontières sans lien d'import), shotgun surgery, abstractions fuyantes transverses. Heuristiques, preuve de friction exigée et reco incrémentale : cf. `references/dimensions.md > Cadrage de la dimension ARC`. Privilégier les outils de graphe + `git log` (langage-agnostique) — la lecture intégrale ne voit pas ces patterns, et le co-change ne coûte aucune dépendance externe.

**Conventions de finding multi-fichiers** :
- Title : fichier *primaire* (occurrence majoritaire ou premier alphabétiquement à égalité).
- `Localisation` : énumère tous les fichiers/lignes impliqués (le champ accepte plusieurs lignes).
- Préfixe : standard (`DUP`, `INC`, `DRF`, `DED`, `BND`) — **aucun marqueur "crosscut" dans l'entrée**. La nature transverse se lit de la `Localisation` multi-fichiers et de la ligne history correspondante.

**Edge cases existants applicables** : doublons potentiels (référencer l'ID existant en chat sans créer de doublon), trade-off check (cf. `references/quality.md > Quand ne PAS produire de finding`), reclassification (garder l'ID).

## D. Écritures (append-only)

1. **Append des findings** dans `## Pending` de `maintainability_findings.md`. IDs assignés via le mécanisme normal (mêmes compteurs `<!-- id_counters: ... -->` que les audits zonaux — pas de fork).
2. **Préfixer une nouvelle ligne en tête** de `maintainability_history.md` :
   ```
   - YYYY-MM-DD — crosscut:<DIM> — N findings (X HIGH, Y MED, Z LOW) (pending)
   ```
   Sweep partiel (fallback échantillonné) : suffixer `[partiel : N/M zones]`.
3. **Pas de trim** — append-only, comme les audits zonaux.

### Cas dimension propre (0 findings)

- Ligne history : `- YYYY-MM-DD — crosscut:<DIM> — 0 findings (clean)` — suffixée `[partiel : N/M zones]` si le sweep était échantillonné (un « clean » partiel n'est pas un clean complet).
- Aucun append dans le findings file.
- Sortie chat : template `crosscut:clean`.

L'écriture de la ligne history est importante — sans elle, la dimension serait re-proposée trop tôt par le rolling crosscut.

## E. Sortie chat (post-crosscut)

- Findings produits → template `crosscut:summary`.
- 0 finding → template `crosscut:clean`.

## F. Proposition post-crosscut

Si findings ≥ 1, **réutiliser** `references/mode-audit.md > H. Proposition de double-check autonome` tel quel (templates `audit:proposition` ou `audit:proposition-min` selon le nombre de findings) puis `references/mode-audit.md > I. Action post-proposition batch` pour l'exécution. Logique de sélection des panels, critères, et flux d'exécution **identiques** — pas de duplication. Les templates et la mécanique sont génériques sur la nature de l'audit.

## Invariants de fin de mode (crosscut)

Avant de rendre la main, valider (une case **non applicable** est considérée cochée ; cf. SKILL.md > *Invariants de fin de mode* pour la règle transverse) :

- Dimension validée par l'utilisateur (template `crosscut:dim-proposition`) avant l'exécution.
- Findings appendés dans `## Pending` de `maintainability_findings.md` — un par finding produit (ou aucun si dimension propre). Findings multi-fichiers respectent la convention `<localisation>` du titre = primaire + bullet `Localisation` énumérant tous les fichiers.
- Header `<!-- id_counters: ... -->` incrémenté pour chaque préfixe utilisé (mêmes compteurs que les audits zonaux, pas de fork).
- Ligne préfixée en tête de `maintainability_history.md` au format `- YYYY-MM-DD — crosscut:<DIM> — ...`, suffixée `[partiel : N/M zones]` si le sweep était échantillonné. **Pas de trim** — history est append-only.
- Si bootstrap a eu lieu : fichiers `<STATE_DIR>/maintainability_*.md` créés avec le contenu initial.
- Si proposition post-crosscut choisie : invariants des modes correspondants (`references/mode-double-check.md` pour single, *Résolution intra-session* de `references/mode-update.md` pour fix) applicables.
