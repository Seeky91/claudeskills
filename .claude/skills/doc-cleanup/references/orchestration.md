# Orchestration & sécurité d'exécution

Référence chargée par `mode-project.md` (toujours) et `mode-zone.md` (si la zone est grosse). Décrit comment exécuter le nettoyage à grande échelle sans saturer le contexte ni casser le code via des renames inter-zones.

## Fan-out vs main-loop : quand déléguer

Le nettoyage d'une zone tient-il dans le contexte courant ?

- **1 fichier, ou petit dossier (≲ 1500 LoC)** → **main-loop** directement. Pas de sous-agent : l'overhead d'orchestration dépasse le gain.
- **Dossier moyen/gros, ou campagne multi-zones** → **fan-out** : un sous-agent à contexte vierge par zone. C'est le seul moyen de traiter un gros projet sans empiler tout le code dans un seul contexte.

L'orchestrateur (main-loop) ne lit **jamais** le code de toutes les zones : il tient l'inventaire, le ledger de couverture, et les **résumés** que chaque agent lui renvoie. Chaque agent ne charge que **sa** zone.

## Stratégie par défaut : agents de zone sérialisés

Modèle aligné sur l'intention « un agent par zone, puis on passe à la suivante » :

1. L'orchestrateur prend la **prochaine zone** non couverte de l'inventaire.
2. Il **instancie un sous-agent** (contexte vierge) avec le briefing ci-dessous, scopé à cette zone.
3. L'agent nettoie sa zone (SUPPRIMER / RENOMMER / GARDER+dé-drifter), **grep le projet entier avant chaque rename** et met à jour tous les sites, puis renvoie un **résumé structuré**.
4. L'orchestrateur **lance la validation** (cf. *Validation*). KO → stop, report, arbitrage utilisateur (pas de zone suivante). OK → écrit la ligne de couverture.
5. Zone suivante.

**Sérialisé, pas parallèle** — c'est délibéré : un rename a un blast radius inter-zones. Deux agents qui mutent en parallèle se marchent dessus (un renomme un symbole que l'autre lit). La sérialisation garantit qu'à tout instant un seul agent écrit, et que chaque rename est propagé au projet entier avant la zone suivante.

### Variante parallèle (optionnelle, gros repo à renames rares)

Si les zones sont très indépendantes et les renames rares/absents, on peut accélérer :

- **Phase 1 — analyse R/O parallèle** : N agents lecture seule, un par zone, qui *proposent* (sans éditer) la liste des suppressions et des renames + leur blast radius. Sans danger (aucune mutation).
- **Phase 2 — apply sérialisé** : l'orchestrateur applique zone par zone, en traitant les renames inter-zones en premier et de façon cohérente.

Ne prendre cette variante que si le gain de temps est réel ; sinon, la stratégie sérialisée par défaut est plus simple et plus sûre. (Isolation `worktree` par agent : possible mais overkill ici — réservée aux mutations vraiment concurrentes.)

## Briefing d'un sous-agent de zone

Le sous-agent a un **contexte vierge** : il ne connaît ni la doctrine ni les règles. Le briefing doit être **auto-suffisant**. Template à remplir par l'orchestrateur :

```
Tu nettoies AGRESSIVEMENT la documentation de code d'UNE zone : <chemin de la zone>.
Objectif : supprimer le bruit de commentaires, rendre le code auto-documenté, fiabiliser le reste. Comportement du code constant.

RÈGLE CENTRALE : un commentaire qui décrit CE QUE le code fait ("what") est du bruit ~90% du temps → SUPPRIME. Un commentaire qui explique POURQUOI ("why" : logique métier, intention non-évidente) → GARDE. Dans le doute sur un "what", supprime.

3 actions possibles par commentaire/nom :
1. SUPPRIMER à vue : paraphrase du code, narration étape par étape, bannières décoratives, docstring/JSDoc qui répète la signature et des types déjà typés, code commenté mort, TODO périmés, changelog en commentaire.
2. RENOMMER pour supprimer : si un commentaire ne compense qu'un nom vague, renomme l'identifiant et supprime le commentaire. MAIS : pas de nom-fleuve illisible (sinon garde un commentaire court) ; grep est TEXTUEL et rate les usages dynamiques/reflection/homonymes — pour un symbole LOCAL/PRIVÉ, rename après grep désambiguïsé (frontières de mot) ; pour un rename CROSS-FICHIERS, utilise un outil sémantique (rename LSP/compilateur, ou find_referencing_symbols + rename_symbol) s'il existe, SINON ne renomme PAS (garde un commentaire court) ; ne renomme JAMAIS un symbole exporté / nom d'API publique / clé de sérialisation.
3. GARDER + corriger : garde le "why" réel (métier, tradeoff, sécurité, limitation plateforme, contrat d'API publique) ET corrige son drift (rends-le conforme au comportement réel actuel ; vérifie ses affirmations par grep avant de les garder).

NE TOUCHE PAS : en-têtes de licence/copyright, directives à sémantique (eslint-disable, type: ignore, noqa, @ts-expect-error, pragmas), fichiers générés/vendored, contrats d'API publique (garde+corrige). Emoji = pas un critère.

GIT EN LECTURE SEULE : édite les fichiers, mais AUCUN git add/commit/push/reset/checkout. Laisse tout dans l'arbre de travail.

Analyse transverse autorisée et encouragée : grep inter-fichiers pour vérifier l'impact d'un rename et la véracité des commentaires gardés.

RENVOIE un résumé structuré (et RIEN d'autre) :
- fichiers inspectés : <liste ou compte>
- commentaires supprimés : <N>
- renames effectués : <liste "ancien → nouveau" + nb de sites mis à jour + outil utilisé (grep / sémantique)>
- docs dé-driftées : <N> (+ 1 ligne par correction notable)
- fichiers modifiés : <liste>
- fichiers/sous-zones explicitement NON traités (et pourquoi) : <…>
- points d'attention / incertitudes laissées en l'état : <…>
```

Adapter : pour `--touched` (mode session), ajouter *« limite-toi aux lignes des hunks suivants : <hunks> »*. Pour la variante R/O, remplacer « édite » par « ne modifie rien, propose seulement ».

Utiliser un agent de modèle capable (Opus) : le tri *what/why* et le jugement de rename demandent de la finesse, pas un petit modèle.

## Vérification d'intégrité du résumé

Le résumé d'un sous-agent n'est **pas auto-certifiant** : les tests prouvent que le code compile/passe, pas que la zone a été inspectée ni que l'agent n'a pas été timide. Avant d'écrire la couverture, celui qui drive **recoupe le résumé avec le diff réel** :

- `git diff --stat -- <zone>` : cohérent avec le résumé (suppressions/renames annoncés → diff non vide ; `0 supprimés (déjà propre)` → diff vide attendu).
- **Scope** : les fichiers du diff doivent rester **dans la zone**, **plus** les sites de propagation de rename hors-zone légitimement déclarés dans le résumé (un rename cross-fichiers fait *légitimement* déborder le diff — ne pas le traiter comme une anomalie). Un débordement **sans** rename déclaré = anomalie → investiguer.
- Résumé manifestement incomplet (zone non triviale mais `fichiers inspectés` vide, ou diff vide alors que la zone est visiblement bruitée) → relancer l'agent ou reprendre en main-loop ; **ne pas marquer couvert** sur la seule foi du résumé.

## Validation

Lancée par celui qui **drive** (l'orchestrateur en `project` ; le main-loop en `zone`/`session`), **après chaque zone entièrement appliquée** — jamais par edit (un rename n'est valide qu'une fois tous les sites mis à jour).

Détection de la commande, opportuniste, dégradation gracieuse :

1. Détecter le runner : scripts `package.json` (`test`, `lint`, `typecheck`), cibles `Makefile` (`test`, `lint`, `check`), `cargo test`/`cargo check`, `go test ./...`/`go vet`, `pytest`/`tox`, `pyproject`/`ruff`, etc.
2. **Ambigu ou plusieurs candidats** → demander **une fois** à l'utilisateur la commande de validation au début de la campagne, puis la réutiliser pour toutes les zones (ne pas redemander à chaque zone).
3. **Rien de détecté** → l'annoncer (*"Pas de suite de tests détectée — validation en mode dégradé : compilation/lint seuls si dispo, sinon aucune."*) et continuer.

**Tests KO sur une zone** : git étant en lecture seule, pas de revert automatique. **Stop** : ne pas passer à la zone suivante, reporter l'échec et les fichiers concernés, laisser l'utilisateur arbitrer (corriger, ou revoir/annuler manuellement le diff de la zone).
