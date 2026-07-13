# Re-vérification en cascade

Référence chargée par SKILL.md quand un fix déclenche la cascade (résolution intra-session, ou `fix B<n>` depuis `list`). But : détecter et tenir à jour les findings dont la localisation chevauche le diff du fix sans relancer un `update` complet.

> La checklist d'invariants de fin de mode (auparavant hébergée ici) vit désormais dans SKILL.md — toujours en contexte, sans chargement supplémentaire.

**Pas de cascade dans ces cas** :
- Moves NO-GO (pas de fix, pas de diff).
- Résolutions issues de `update` (déjà exhaustif par construction).

### Algorithme

1. **Capter le diff** : `git show --name-only <hash>` où `<hash>` est le commit de la `Resolution` du finding primaire. Pour des fixes batchés (plusieurs primaires dans le même turn) : union des paths sur tous les commits associés. Si pas de commit identifiable (cas rare où le fix n'est pas committé au moment de la résolution) : sauter la cascade et noter en chat *"Cascade re-check sautée : pas de commit identifié pour `<ID>`."*

2. **Filtrer les candidats** parmi `## Pending`, hors les primaires déjà déplacés. Un finding est candidat ssi **au moins un** de ses paths :
   - matche exactement un path du diff, ou
   - est descendant d'un dossier du diff, ou
   - est ancêtre d'un path du diff (cas god file dont le contenu est splitté en sous-fichiers).
   
   Pour un finding mono-fichier : "ses paths" = le path du titre. Pour un finding multi-fichiers (bullet `Localisation` énumérant plusieurs emplacements, typiquement issu d'un crosscut) : "ses paths" = tous les paths listés dans `Localisation`.

   **Si zéro candidat** : sortie silencieuse, aucune écriture, aucun message en chat.

3. **Re-check par candidat** — réutilise la logique par-dimension du mode update (`references/mode-update.md`) : lire ~20 lignes autour de la localisation, vérifier si le pattern décrit est encore reconnaissable. Trois issues possibles :
   - **Pattern toujours présent** → laisser pending. Si la ligne a shifté significativement, mettre à jour `path:line` dans le titre. Pas d'autre écriture.
   - **Pattern absent** (fichier toujours là, observation ne tient plus) → cascade-resolved. Move vers `## Resolved` au format compact. Bullet `Resolution :` au format : *"résolu collatéralement par fix de `<ID-primaire>` (YYYY-MM-DD). Δ LoC mesuré : intégré dans `<ID-primaire>`. Commit : `<hash-primaire>`."* — pas de fragmentation du Δ, la valeur globale reste dans la `Resolution` du primaire ; le commit est celui du primaire (le cascadé n'a pas son propre commit).
   - **Fichier disparu / renommé** (path absent du repo après le fix) → laisser en pending et **remplacer** la bullet `Status` par `Status : stale-after-<ID-primaire> (YYYY-MM-DD) — localisation invalidée par le fix, à relocaliser ou archiver`. Pas de question synchrone.

4. **Mettre à jour `maintainability_history.md`** : pour chaque cascade-resolved, retrouver la zone et la date de l'audit d'origine via la bullet `Détecté` de l'entrée Pending (lue **avant** le move qui la drop) et compléter `(résolus <IDs>+...)` sur la ligne d'audit correspondante.

5. **Appliquer l'invariant cap Resolved** (cf. `references/file-formats.md > Cycle de vie d'un finding` étape 5).

### Confirmation utilisateur (flux intra-session)

Le flux intra-session existant (*"Ce fix résout DUP-007. Je marque comme résolu ?"*) est étendu : la cascade s'exécute en lecture seule **avant** le prompt, et son résultat est inclus dans le **même prompt** que la confirmation primaire. Le template `resolution:confirm` (cf. `references/templates.md`) gère les deux variantes (avec/sans cascade) en un format unifié.

L'utilisateur valide tout en un mot. Si push-back partiel (*"garde INC-008 en pending"*) : appliquer le reste, ne pas insister.

### Sortie en chat (flux pré-validés)

Les flux `fix B<n>` (mode list) ont déjà un OK explicite avant exécution. La cascade s'exécute alors **sans nouveau prompt** ; son résultat agrégé est intégré au récap final via le template `cascade:recap-batch` (cf. SKILL.md > Sorties chat — conventions, et `references/templates.md`). Si overlap = 0 sur tous les fixes du batch : la ligne `Cascade re-check :` est omise.

### Edge cases

- **Cascade qui résout un autre item du batch en cours** (cas `fix B<n>`) : si le re-check post-fix de l'item #1 résout DUP-008 et que DUP-008 est l'item #2 du batch → skip DUP-008 dans la suite avec annonce *"DUP-008 déjà résolu collatéralement par DUP-007, skip."*
- **`update` rencontre un `stale-after-<ID>` existant** : passe par l'investigation self-heal (cf. `references/mode-update.md > étape 2.b`) — le commit primaire est connu, signal direct. Trois issues possibles : auto-relocalisation (pattern retrouvé ailleurs), auto-résolution (pattern dissout par le fix primaire), ou préservation du tag `stale-after-<ID>` si l'investigation est inconclusive. Dans ce dernier cas, **ne pas remplacer** par un `stale` générique — l'info de cause reste plus précieuse.

### Idempotence et borne de coût

- Idempotent : re-runner la cascade sur le même commit ne re-bouge rien (les cascadés sont déjà dans Resolved, le filtre à l'étape 2 les exclut).
- Coût : ∝ |pendings ∩ overlap diff|, pas |pendings|. ≤ ~20 lignes lues par candidat (le re-check par-dim borne lui-même).
- Aucun coût si overlap zéro (filtrage tôt à l'étape 2, sortie silencieuse à l'étape 3).

### Distinction avec le mode update

`update` est exhaustif et explicite — l'utilisateur le lance pour rattraper des fixes hors-session. La cascade est **ciblée et automatique** — elle couvre les fixes faits dans la conversation courante. Les deux cohabitent : la cascade limite la dérive intra-session, `update` ratisse plus large quand la dérive a échappé.
