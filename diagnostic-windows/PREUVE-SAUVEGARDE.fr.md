# Preuve d'extraction sur les captures utilisateur

Les trois fichiers fournis sont des sauvegardes GVAS non chiffrees avec un bloc
contenant l'identifiant AlsaceS4SaverneShort1Forward et la voiture SkodaFabiaRSRally2.
La capture du classement identifie cette speciale comme Obersteigen.

Le bloc correspondant au classement contient 2, puis 3, puis 4 tentatives.
Les deux ajouts de 79 octets sont des tentatives, pas seulement des changements
de statistiques globales. Structure observee : index de tentative uint32,
voiture FString UTF8, nombre de passages uint32, puis triplets
(index uint32, cumul Float32, duree Float32), et 12 octets nuls de sens inconnu.
Toutes ces valeurs sont little-endian. Le passage 0 vaut zero ; les passages
1 et 2 contiennent les deux secteurs. L'arrivee est incluse dans le dernier cumul.

Tableau des valeurs decodees arrondies au ms pour lecture (pas une garantie
de la regle d'arrondi d'affichage du jeu) :

| Tentative | Secteur 1 | Secteur 2 | Dernier cumul |
|---|---|---|---|
| 1 | 112.621 s | 76.365 s | 188.986 s |
| 2 | 78.991 s | 99.292 s | 178.283 s |
| 3 | 79.194 s | 59.646 s | 138.840 s |
| 4 | 77.933 s | 59.870 s | 137.803 s |

La capture affiche apparemment 138.839 s pour la tentative 3 contre
138.8400115966797 s pour le dernier cumul stocke : ecart d'environ 1 ms,
non resolu. Conserver les floats bruts et ne pas promettre un affichage exactement
identique au jeu avant verification sur une capture plus lisible.

Les nouvelles tentatives (3 et 4 a l'ecran, 1 et 2 dans les reperes du diagnostic)
sont presentes dans 000004.sav et 000005.sav, captures apres l'arrivee mais AVANT
l'ouverture du classement selon les reperes. Le bloc est deja present dans
000003.sav avec les tentatives 1 et 2. La disparition de l'interface au relancement
n'empeche donc pas la presence des donnees dans ces copies. La retention dans
le fichier ORIGINAL apres fermeture n'a pas ete testee par ces trois captures.

## Lecteur Windows experimental

Extraire tous les fichiers de la branche add-windows-diagnostic, puis lancer
Lancer-Lecture-Secteurs.bat. Donner le chemin d'une COPIE .sav (000003, 000004
ou 000005) du diagnostic, sans guillemets. Le lecteur utilise les identifiants
de cette speciale/voiture par defaut. Il exporte secteurs.csv et preuve.json sous
%LOCALAPPDATA%\ACR-Optimal\DecodedEvidence. Il ne modifie pas la source.

Attendu : respectivement 4, 6, 8 lignes de secteurs, soit 2, 3, 4 tentatives.
Ces trois extractions ont ete executees avec succes sous PowerShell 7/Linux sur
les vraies copies fournies : valeurs attendues et hash de source verifies. Les
tests de signature invalide et de speciale inconnue refusent bien l'export.
Le lancement sur Windows PowerShell 5.1 reste a verifier sur le PC utilisateur.
Comparer les deux colonnes de temps avec l'ecran. Reouvrir la meme copie produit
un nouveau dossier de PREUVE ; ce n'est pas encore un import d'historique.
Un format inconnu, plusieurs blocs correspondants ou des metadonnees non nulles
entrainent un refus, pas une inference de penalites ou de validite.

Le lecteur cherche les identifiants, pas un offset fixe. Il impose la structure
demontree sur ces echantillons et ne pretend pas etre un parseur complet GVAS.
Pour une autre combinaison, les identifiants internes doivent etre verifies :

```powershell
.\Lire-Sauvegarde-Secteurs.ps1 -SavePath 'C:\COPIE.sav' -StageId 'IDENTIFIANT_VERIFIE' -CarId 'IDENTIFIANT_VERIFIE'
```

## Limites avant le collecteur SQLite

La recuperation des SECTEURS est maintenant demontree pour ces trois copies,
pas encore le mode, la validite, les penalites ni les resets de cette structure.
Le contenu voisin mentionne DefaultTimeAttack mais cela ne prouve pas a lui seul
le mode de CHAQUE tentative. Ne pas activer des records TT sur cette seule base.

Prochaine verification : nouvelle session TT, tentative plus lente, abandon,
changement de voiture et redemarrage du jeu. Capturer le fichier avant/apres
chaque changement et comparer les index/identifiants. Cela permettra de definir
une cle de tentative persistante sans confondre une ancienne ligne avec un
nouveau run ayant les memes temps. Tester egalement un autre mode pour verifier
qu'il peut etre exclu ; aucun de ses resultats ne doit alimenter les records TT.

Pour les quatre tentatives fournies, minimum secteur 1 + minimum secteur 2 donne
77.9330062866211 + 59.64600372314453 = 137.57901000976562 s (environ 2:17.579).
Ce calcul sur echantillon est possible, sans le declarer record valide permanent.
Le stockage SQLite et la surveillance automatique a l'arrivee viendront apres
verification des limites ci-dessus. Aucun fichier .sav personnel n'est publie
dans le depot GitHub.
