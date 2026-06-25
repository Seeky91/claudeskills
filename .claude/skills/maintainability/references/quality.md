# Qualité d'évaluation d'un finding

Référence chargée par SKILL.md à l'exécution d'un audit, d'un crosscut ou d'un double-check, pour calibrer sévérité, garde-fous anti-bruit, et estimation Δ LoC.

## Grille de sévérité

Sévérité = **impact × exposition**. Ce n'est pas un goût, c'est une calibration sur l'effet sur la maintenabilité du code.

- **HIGH** — bloque ou alourdit toute évolution future de la zone.
  Exemples : god file dans un hot path, composition root centrale qui force chaque évolution boot/runtime/web à modifier le parent, duplication structurante (3+ copies de logique), drift de contrat utilisé partout, tests fondants empêchant tout refactor, cycle entre modules cœur, shotgun surgery récurrente (chaque feature touche 5+ fichiers).
- **MED** — friction notable mais contournable.
  Exemples : entrypoint ou root de sous-système qui mélange orchestration et wiring détaillé, incohérence locale de pattern, redondance modérée de tests, sprawl de config sur 2-3 modules, duplication 2× sur fonction utilitaire, couche pass-through, feature envy localisé.
- **LOW** — cosmétique, nettoyage sans impact comportemental.
  Exemples : commentaire stale, var inutilisée, doublon trivial dans helper jamais touché, doc d'une fonction self-explanatory, généricité spéculative sur un helper peu touché.

**La sévérité est mutable.** Un `double-check` peut révéler que ce qu'on pensait HIGH est en fait MED (ou inversement). Dans ce cas : amender l'attribut sévérité dans l'entrée, **ne pas changer l'ID.**

## Quand ne PAS produire de finding

Le skill est intrinsèquement orienté détection, ce qui crée un biais structurel à sur-produire des findings pour "justifier" l'invocation. Sans contre-poids, l'audit dérive vers du **paperclip maximizing** : on optimise la maintenabilité jusqu'à dégrader d'autres aspects du projet. Cette section est le contrepoids.

### Conscience du biais à sur-produire

Une zone qui produit 0 finding sur toutes les dimensions est un audit **réussi**, pas un audit raté. Corollaires opérationnels :

- Ne pas remplir du vide pour rentabiliser l'invocation.
- Si une dimension n'a rien produit après examen sérieux, passer à la suivante sans forcer.
- Si la zone entière est propre, l'écrire (ligne history `0 findings (clean)`) et s'arrêter là — pas de finding "consolation" pour avoir l'air d'avoir travaillé.
- Une dimension qui ne produit jamais rien sur une zone donnée n'est pas un échec d'audit ; le code peut être propre sur cet axe.

### Trade-off check sur les autres axes du projet

Si la reco améliorerait la maintenabilité au prix d'une dégradation visible sur un autre axe : **ne pas produire le finding** par défaut, ou le produire en annotant explicitement le trade-off dans la bullet `Reco`. Axes à vérifier avant production :

- **Performance** : abstraction qui ajoute du coût per-call dans un hot path, allocation supplémentaire, indirection runtime introduite par un helper, copies de données en plus.
- **Sécurité** : suppression d'un check, élargissement d'une surface d'attaque, partage d'état précédemment isolé, secret précédemment scopé qui devient transitif.
- **Scalabilité** : suppression d'un seam d'extension, fusion de variantes "presque identiques" qui pourraient diverger demain, aplatissement qui bloque l'ajout futur d'une nouvelle responsabilité, suppression d'une couche d'indirection qui était un point de branchement. Trop simplifier aujourd'hui se paye cher quand on voudra accueillir une feature.
- **Lisibilité paradoxale** : sur-abstraction qui crée des indirections plus difficiles à suivre que la duplication originale (DRY pathologique : 3 copies divergentes fusionnées en un helper paramétré incompréhensible avec un boolean qui change le comportement à mi-chemin), ou chaîne fonctionnelle dense / one-liner clever qui remplace trois lignes limpides par une expression à déplier mentalement.

**Règle par défaut** : si le trade-off est significatif, ne pas produire le finding. Si le finding est produit malgré un trade-off identifié, l'annoter dans la bullet `Reco` pour que l'utilisateur puisse trancher en connaissance de cause.

Ce check intervient **en amont** de la production du finding. Il ne remplace pas le double-check (qui creuse la faisabilité d'un finding existant) — il intervient une étape avant, à la décision même de produire.

### Dogme ≠ défaut

S'applique surtout aux dimensions de jugement (`ARC`, `IDM`, `CPX`). Un écart à un paradigme, un pattern ou une école d'architecture n'est **pas** un finding en soi. Le finding exige un **symptôme concret de friction de maintenabilité**, citable et vérifiable : la modification qui a dû toucher N fichiers, le call site qui contourne l'abstraction, le bug pattern récurrent, la fonction que personne n'ose toucher. « Ce n'est pas conforme à X » (hexagonale, clean architecture, style fonctionnel pur…) n'est jamais une observation — c'est une préférence. Une densité élevée peut être un symptôme légitime si elle rend la séquence difficile à scanner ou empêche de nommer les sous-concepts ; l'objectif reste de rendre les responsabilités lisibles sans cacher les décisions importantes derrière des noms vagues. En l'absence de symptôme : abstention. Le cadre d'évaluation multi-paradigme vit dans `references/dimensions.md > Référentiel paradigmatique` ; ce garde-fou en est le pendant côté décision de produire.

## Estimation Δ LoC

Chaque finding doit indiquer un `Δ LoC` estimé : la variation de lignes de code source que produirait l'application de la reco. Format `~±N` (le `~` marque l'estimation, le signe indique l'effet net).

**Convention de signe :**
- **Négatif** (`~-40`) : la reco réduit le code (extraction de duplication, suppression de dead code, fusion de variantes).
- **Positif** (`~+30`) : la reco ajoute du code (split d'un god file en modules avec boilerplate, ajout d'une couche d'abstraction).
- **Quasi-nul** (`~±5`) : la reco déplace ou réécrit sans réduire (renommage transverse, restructuration locale, harmonisation de pattern).

**Méthode d'estimation à l'audit :**
- Mesurer la taille des occurrences impliquées (lignes du pattern × nombre de copies).
- Soustraire la taille du helper / module extrait, en incluant un peu de boilerplate (signature, imports, docstring si nécessaire).
- Pour les splits de god files : estimer à partir de la taille des responsabilités identifiées + ~10-20 % de boilerplate (imports, signatures, ré-exports).
- Si l'estimation est trop incertaine pour être utile (e.g. la reco dépend de choix d'architecture non tranchés) : noter `Δ LoC : indéterminé — à affiner en double-check`.

**À l'application du fix (résolution) :** mesurer le delta réel via `git diff --stat` ou comptage direct, et le consigner dans `Resolution :`. Format `Δ LoC mesuré : -47`. C'est cette valeur qui compte dans les bilans, pas l'estimation initiale.

**À un double-check :** raffiner l'estimation à la lumière du blast radius et des contraintes découvertes. Format `Δ LoC affiné : ~-35`. Si le raffinement contredit l'estimation initiale (> 50 % d'écart), expliquer brièvement pourquoi.
