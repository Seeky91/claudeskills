# Doctrine de nettoyage

Référence chargée par SKILL.md au début de **chaque** mode. C'est le cœur du skill : la calibration de ce qu'on supprime, renomme, ou garde. À lire avant tout edit.

## Posture : agressif par défaut

Un agent compétent **sous-supprime spontanément**. Laissé à lui-même, il garde « au cas où », trouve une justification à presque chaque commentaire, et le code reste noyé. Ce skill corrige ce biais en **inversant la charge de la preuve** :

> Un commentaire est du bruit **jusqu'à preuve de son utilité**. Le défaut est la suppression.

Concrètement : quand tu hésites sur un commentaire, **supprime**. L'allowlist ci-dessous est volontairement étroite ; tout ce qui n'y entre pas clairement tombe. Le garde-fou contre l'excès n'est pas la timidité, c'est l'allowlist + la validation (tests) + le diff non commité que l'utilisateur revoit.

## L'heuristique centrale

> Un commentaire qui décrit **ce que** le code fait (« *what* ») est du bruit dans ~90 % des cas → **supprime**.
> Un commentaire qui explique **pourquoi** (« *why* ») — logique métier, intention non-évidente — est la vraie valeur → **garde**.

Le code dit déjà *ce qu'il fait*. Le relire en français n'ajoute rien et ment dès que le code change (drift). Le ~10 % de « *what* » qu'on garde : un algorithme dense et non-trivial dont le résumé en une ligne fait gagner du temps de lecture (et là encore, préférer un bon nom).

## Les 3 verbes

Pour chaque commentaire / nom rencontré, une seule des trois actions :

1. **SUPPRIMER** — le bruit (la majorité). Liste indicative ci-dessous.
2. **RENOMMER pour supprimer** — quand le commentaire ne compense qu'un nom vague : renommer l'identifiant, puis supprimer le commentaire.
3. **GARDER (+ dé-drifter)** — le « *why* » de l'allowlist : on le conserve, et on corrige son éventuel drift.

## 1. SUPPRIMER à vue

Liste **indicative, non exhaustive** — elle amorce le jugement, elle ne le remplace pas. Le critère reste l'heuristique centrale.

- **Paraphrase du code** : `// incrémente i`, `# boucle sur les items`, `// retourne le résultat`, `// constructeur`.
- **Narration étape par étape** qui double la lecture du corps de fonction.
- **Bannières / séparateurs décoratifs** : `// ===== SECTION =====`, `//////// HELPERS ////////`.
- **Docstring / JSDoc / doc-comment qui répète la signature** : redit le nom, les paramètres et des types déjà typés statiquement sans rien ajouter (`@param user the user`).
- **Doc de type redondante** sur du code déjà typé.
- **Code commenté laissé en place** (mort) — supprimer ; l'historique git le garde.
- **TODO/FIXME périmés** ou sans contenu actionnable ; mini-changelog en commentaire (`// modifié le 12/03 par X`) — l'historique git est la source.
- **Tout commentaire « *what* »** sur du code déjà lisible.

Emoji dans un commentaire : **pas un critère** de suppression en soi. Juger le commentaire sur le fond (utile → garder ses emoji ; bruit → supprimer le tout).

## 2. RENOMMER pour supprimer le commentaire

Beaucoup de commentaires n'existent que pour **compenser un nom vague**. Le bon réflexe : déplacer l'information dans le nom, puis supprimer le commentaire.

```
let d = 86400; // secondes dans une journée      →   let seconds_per_day = 86400;
function proc(x) { // valide et normalise l'email →   function validateAndNormalizeEmail(email) {
```

**Garde-fou de pragmatisme** (sans lui le renommage dérape) :

- **Pas de nom-fleuve illisible.** Si l'information n'entre pas dans un identifiant raisonnable, **garder** un commentaire court plutôt que créer `processAndValidateAndNormalizeUserEmailThenLog`.
- **Pas de rename qui casse un contrat public.** Un symbole exporté / nom d'API publique / clé de sérialisation ne se renomme pas pour le confort de lecture interne (cf. *Quand NE PAS toucher*).
- Si la logique est **structurellement trop dense** pour qu'un nom la résume, garder et **compresser** le commentaire (le réduire à son « *why* »).

**Sécurité du rename — `grep` est textuel, pas sémantique** : il rate les imports dynamiques, la reflection, les strings protocolaires, les clés de sérialisation, les surcharges, les homonymes, les ré-exports indirects et les usages hors repo. Comme le skill *pousse* à renommer, c'est le principal point de danger. Procéder par **paliers de risque** :

- **Symbole local / privé, scope lexical clair** → rename direct après un grep **désambiguïsé** (frontières de mot, écarter les homonymes). Cas le plus fréquent et le plus sûr.
- **Rename cross-fichiers** → grep **ne suffit pas**. Utiliser un **outil sémantique quand il est disponible** (rename LSP, rename du compilateur/IDE, ou `find_referencing_symbols` + `rename_symbol`) : il donne la liste exhaustive des références, l'agent valide. Posture « l'outil propose, l'agent dispose ».
- **Aucun outil sémantique disponible pour un rename cross-fichiers** → **ne pas auto-renommer** : garder un commentaire court (le fallback pragmatique ci-dessus) plutôt que risquer un rename textuel incertain. (L'utilisateur peut toujours forcer un rename explicitement.)
- **Jamais** : symbole exporté / nom d'API publique / clé de sérialisation (cf. *Quand NE PAS toucher*).

(Orchestration multi-zones : cf. `references/orchestration.md`.)

## 3. GARDER (allowlist étroite) + dé-drifter

On **garde** un commentaire seulement s'il porte un savoir que le code ne peut pas dire de lui-même. Allowlist (calquée sur une politique de commentaires stricte) :

- **Logique / règle métier** non déductible du code (« les remboursements > 30 j passent par le flux manuel — exigence légale »).
- **Intention non-évidente / pourquoi-pas** : pourquoi cette approche et pas l'évidente (« pas de `Promise.all` ici : l'API limite à 1 req/s »).
- **Tradeoffs délicats**, choix de perf contre-intuitifs.
- **Limitations plateforme / contournements** (bug d'un lib, quirk navigateur, contrainte OS).
- **Sécurité / sûreté** : invariants à ne pas casser, raison d'un check.
- **Contrats d'API publique** : doc d'un symbole exporté/public qui sert de documentation aux consommateurs (cf. cas langage ci-dessous).

**Dé-drifter les survivants** (directive d'audit) : un commentaire gardé doit être **vrai**. Pour chacun :

- Vérifier qu'il décrit le comportement **réel actuel** du code (le drift est fréquent : le code a évolué, le commentaire non).
- Corriger les données obsolètes (stale), clarifier les imprécisions, résoudre tout décalage commentaire ↔ code.
- **Vérifier les affirmations transverses** : si un commentaire avance un fait (« appelé seulement par X », « toujours non-null ici »), le confirmer par grep / lecture des call sites avant de le garder. Un commentaire qui ment est pire que pas de commentaire — le corriger ou le supprimer.

## Quand NE PAS toucher (garde-fous)

Ces garde-fous protègent une **minorité** de cas. Ils ne sont pas une invitation à la timidité : en cas de doute sur un commentaire « *what* » ordinaire, le défaut reste la **suppression**.

- **Ne pas supprimer** un commentaire qui porte un vrai « *why* » de l'allowlist, même maladroitement formulé (le reformuler plutôt).
- **Ne pas changer le comportement.** Le nettoyage est à comportement constant. Attention aux langages sans `defer`/RAII : un rename ou un déplacement ne doit pas altérer l'ordre d'exécution ou un cleanup.
- **Préserver les en-têtes légaux** : licences, copyright, mentions SPDX, avis générés obligatoires — ce ne sont pas de la doc de code.
- **Préserver les directives à sémantique** : `// eslint-disable`, `# type: ignore`, `# noqa`, `// @ts-expect-error`, pragmas, annotations de build/lint. Ce sont du code, pas des commentaires.
- **Fichiers générés** (`*.gen.*`, `*_pb2.py`, output de codegen, vendored) : ne pas y toucher.
- **Contrats d'API publique** : cf. cas langage.

## Cas langage : doc-comment privé vs contrat public

La nature d'un doc-comment dépend de l'**exposition** du symbole, et la syntaxe varie selon le langage (`///` Rust, docstrings Python, JSDoc/TSDoc, doc comments Go, Javadoc) :

- **Symbole privé / interne** : un doc-comment qui paraphrase la signature est du bruit → **supprime** (défaut agressif).
- **Symbole public / exporté** (lib consommée par d'autres, API publique, ce qui alimente une doc générée) : le doc-comment est un **contrat** → **garde et dé-drifte**. Mais supprime quand même la partie purement redondante (un `@param` qui redit le type sans rien ajouter reste du bruit, même sur du public).

En cas d'incertitude sur l'exposition (le symbole est-il vraiment consommé dehors ?), **grep les usages** avant de trancher. Abstention prudente sur une API publique mal cernée : garder et dé-drifter plutôt que supprimer.
