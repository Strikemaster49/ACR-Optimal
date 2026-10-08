# ACR-Optimal — cahier des charges

## Objectif et priorité technique

Application Windows de suivi des performances en contre-la-montre dans Assetto
Corsa Rally. Elle récupère les secteurs, conserve les tentatives entre les sessions
et calcule un optimal par spéciale et voiture. Le multijoueur est exclu.

La priorité reste l'acquisition : collecte automatique, reconnaissance du mode TT,
spéciale/sens, voiture, arrivée, validité, pénalités et identifiants de tentative.
Aucun fichier du jeu ne doit être modifié. Privilégier la lecture non intrusive
des sauvegardes locales ; pas d'injection ou de lecture de mémoire du processus.

État démontré : extraction de quatre tentatives depuis trois copies de
PlayerDataSaveSlot.sav pour Obersteigen / Skoda Fabia RS Rally2. Les données
incluent cumul et durée par secteur et apparaissent avant ouverture du classement.
Le lecteur fonctionne sur le PC Windows utilisateur pour cet échantillon.
Mode, validité, pénalités, resets et compatibilité générale ne sont pas encore
démontrés. Les exports actuels `Mode=unverified`, `Validity=unverified` ne sont
donc pas admissibles aux statistiques de production.

La remise à zéro du classement après relancement impose de sauvegarder dès que
les données sont disponibles. Leur persistance dans la sauvegarde originale
après fermeture reste à vérifier ; ne pas dépendre d'une récupération ultérieure.

## Conditions d'admission aux statistiques

Une tentative admissible en version initiale doit être terminée, complète,
identifiée comme TT, valide et sans pénalité, avec tous les secteurs réellement
récupérés, leurs unités et leur provenance vérifiées. Les tentatives inconnues,
partielles, invalides ou pénalisées restent dans l'historique de diagnostic,
explicitement exclues des records et analyses. L'utilisation de secteurs d'une
tentative abandonnée pourra faire l'objet d'une extension après validation.

Conserver la mesure brute, le type cumul/durée et les durées normalisées.
Pour un cumul C : s1=C1, si=Ci−C(i−1). Identifier l'inclusion de l'arrivée et ne
pas compter le passage initial nul comme un secteur. Aucun secteur manquant ne
devient zéro ; aucune valeur estimée/OCR non validée n'alimente les statistiques.

Contrôler la cohérence entre somme des durées et temps total brut. La tolérance
doit être justifiée par la représentation de la source et les essais de chaque
version, conservée avec sa provenance. Un écart inexpliqué bloque l'admission.
Préserver la précision disponible sans prétendre que l'arrondi de l'application
est celui du jeu. L'écart d'environ 1 ms observé sur une capture reste à résoudre.

Une population comparable est définie par spéciale interne, sens/variante,
voiture interne et disposition des secteurs. Ne pas fusionner des tracés ou
dispositions homonymes. Conserver conditions, version du jeu et version du
décodeur ; isoler les données incompatibles et afficher les conditions mélangées.

## Module avancé d'analyse par secteur

Les indicateurs ci-dessous utilisent uniquement la population admissible choisie.
Le contexte et le nombre de tentatives doivent rester visibles. Sans données
suffisantes, afficher « Données insuffisantes », jamais une valeur fictive.

### Meilleur chrono complet et minimum théorique

Le meilleur complet B est le minimum des temps bruts des tentatives admissibles.
Sa ligne source et ses secteurs doivent rester consultables. En cas d'égalité,
sélectionner de façon déterministe la première tentative selon l'ordre de collecte,
puis son identifiant ; permettre de consulter les autres ex æquo.

Pour chaque secteur i, mi=min(sri) sur les tentatives admissibles. Le minimum
théorique T=Σmi. Chaque minimum est relié à sa tentative d'origine. Présenter T
comme une combinaison de secteurs, pas un temps effectivement réalisé.

### Gain potentiel et secteurs prioritaires

Pour les secteurs bi de la tentative portant B : gain secteur gi=bi−mi.
Gain potentiel total G=B−T. Classer les secteurs par gi décroissant, puis par
index en cas d'égalité. Afficher durée de référence, meilleur historique, gain
et tentative source ; une barre rend les gains comparables.

La somme des gains sectoriels vaut Σbi−T. Si elle diffère légèrement de B−T
dans la tolérance validée, conserver et expliquer l'écart d'arrondi ; ne pas
forcer les secteurs à absorber cet écart. Un écart hors tolérance bloque le calcul.
Un secteur au gain nul ne signifie pas qu'aucun progrès futur n'est possible.

### Comparaison de deux tentatives

Choisir A comme référence et B comme comparaison, uniquement dans le même
contexte compatible. Afficher, pour chaque secteur, sAi, sBi et Δi=sBi−sAi :
négatif = B plus rapide, positif = B plus lente. Afficher également les cumuls
pour situer le changement d'écart, et la différence des temps complets.
Identifier les deux tentatives, dates/sessions et conditions. Une différence de
secteurs ou un contexte incompatible empêche la comparaison chiffrée.

### Graphiques d'évolution

- Temps complet par tentative et record progressif.
- Durée d'un secteur sélectionné et son meilleur historique progressif.
- Minimum théorique progressif, calculé seulement avec les données connues à
  chaque point : ne pas appliquer les records futurs au passé.

Ordonner par horodatage d'arrivée vérifié ou, à défaut, ordre de collecte indiqué
comme tel, jamais par position dans le classement trié par performance. Utiliser
les valeurs réellement observées, sans interpolation qui inventerait des runs.
Les tentatives exclues peuvent être repérées séparément sans alimenter les courbes
de records. Infobulles : tentative, session, valeur, conditions et provenance.

### Régularité de chaque secteur

Afficher nombre d'observations, médiane, écart interquartile et écart-type
échantillonnal en secondes : σ=√(Σ(si−moyenne)²/(n−1)). Afficher également le
coefficient de variation 100σ/moyenne si la moyenne est positive. Les durées
absolues et leur dispersion relative doivent être distinguées.

Au moins trois tentatives admissibles sont nécessaires pour les indicateurs de
dispersion ; signaler « petit échantillon » jusqu'à dix. Ne pas qualifier de
« régulier » un secteur avec une seule mesure. Ne pas supprimer automatiquement
les tentatives lentes valides : proposer un filtre de période explicite.

### Estimation d'un optimal réaliste

Indicateur distinct du minimum théorique, nommé « Estimation basée sur les
performances récentes ». Première méthode proposée, à valider par rétrotests :
somme des premiers quartiles des durées par secteur sur les 20 dernières
tentatives admissibles du même contexte. Au moins dix tentatives requises.
Tous les secteurs utilisent le même ensemble de tentatives complètes.

Définition reproductible des quantiles : valeurs triées x0…x(n−1), h=(n−1)p,
interpolation linéaire entre floor(h) et ceil(h), p=0,25. Cette convention sert
aussi au calcul des quartiles de régularité. Les quantiles sont calculés sur les
durées, jamais sur les passages cumulés.

Afficher méthode, fenêtre, effectif et avertissement bref : cette combinaison
n'est ni une prédiction garantie ni une probabilité de réussite. Elle est au
moins égale au minimum théorique de la même population, mais peut être plus
lente que le meilleur complet historique ; ne pas masquer ou plafonner ce cas.
Les corrélations entre secteurs et les changements de conditions limitent
l'interprétation. Si la méthode ne passe pas les rétrotests, rester désactivée
plutôt que présenter une estimation non étayée.

### Filtres et conservation de l'historique

Filtres obligatoires : spéciale exacte et voiture. Filtres complémentaires :
période, session, conditions connues et versions compatibles. Tous les panneaux,
comparaisons et graphiques appliquent le même contexte. « Historique » signifie
l'historique conservé par ACR-Optimal, pas tous les anciens records du joueur.

SQLite local conserve sessions, tentatives, secteurs, mesures brutes, statut de
validation et provenance. L'import de chaque tentative et de ses secteurs est
transactionnel. Définir la clé d'identité après preuve des resets de la source :
ne pas utiliser uniquement les chronos pour dédupliquer deux tentatives réelles.
Une même tentative relue doit être ignorée ou mise à jour, jamais ajoutée deux
fois. Le contexte de session persiste aussi lors du redémarrage du collecteur.
Les records sont dérivables des tentatives sources ; sauvegardes et migrations
préservent l'historique entre lancements. Base hors du dossier d'installation,
sous %LOCALAPPDATA%\ACR-Optimal, avec export/sauvegarde utilisateur.

## Interface Windows

Interface native moderne, lisible, compatible Windows 10/11 x64, DPI élevé,
redimensionnement et navigation clavier. Architecture envisagée : C#/.NET LTS,
WPF/MVVM, moteur de calcul indépendant du décodeur et de l'affichage.

En haut : contexte spéciale/voiture, état de collecte, dernière acquisition et
compteur de tentatives validées/exclues. Cartes : meilleur complet, théorique,
gain potentiel et estimation récente lorsqu'elle est disponible.

Tableau des secteurs : référence du meilleur complet, minimum historique, gain,
rang de priorité, dispersion et effectif. Panneaux de comparaison et graphiques.
Les couleurs sont doublées par texte/signes ; ne pas dépendre du rouge/vert seul.
Respecter les formats de temps et paramètres régionaux, en conservant une
représentation numérique indépendante de la locale dans la base.
Une déconnexion, donnée provisoire ou non validée doit être visible immédiatement.
Distribution finale : installateur Windows autonome sans installation de Python.

## Développement progressif et critères d'acceptation

1. **Acquisition validée** : vérifier nouvelles sessions/resets, autre combinaison,
   tentatives moins rapides, abandon, pénalités et exclusion des autres modes.
   Identifier le signal de collecte à l'arrivée ou les changements exploitables.
2. **Collecteur et SQLite** : importer chaque tentative une seule fois, résister
   à des lectures répétées, écritures incomplètes et relancements. Une source
   inconnue reste en quarantaine ; aucun ancien record n'est effacé implicitement.
3. **Calculs fondamentaux** : meilleur complet, minima, optimal et gains. Vérifier
   les égalités, secteurs manquants, cumuls et écarts de précision.
4. **Analyses et interface** : comparaison, courbes, dispersion puis estimation
   récente validée. Tester filtres et cohérence de tous les panneaux.
5. **Distribution** : installation/lancement sur un Windows propre et restauration
   d'une sauvegarde locale sans Python installé.

Pour les vérifications du moteur, des jeux de données de test explicitement
séparés peuvent être utilisés ; ils n'alimentent jamais les données utilisateur.
Critères : une tentative exclue ne change aucun record ; deux lectures identiques
ne changent pas l'effectif ; une nouvelle tentative identique mais distincte
augmente l'effectif ; une autre voiture/spéciale ne change pas les résultats
du filtre actif ; les records survivent à une fermeture complète ; les courbes
progressives n'utilisent pas le futur ; les estimations indisponibles sont
clairement signalées et ne remplacent pas le minimum théorique.

Ce document spécifie les fonctionnalités à développer. Il ne déclare pas ces
fonctionnalités implémentées, et ne réduit pas la priorité donnée à l'acquisition.
