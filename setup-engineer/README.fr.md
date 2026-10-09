# ACR Setup Engineer - prototype Windows

Lire [l'audit](AUDIT.fr.md) : sources/licence tierces absentes dans les archives
examinees, aucune incorporation du logiciel tiers. Extraction independante
prouvee sur une copie utilisateur ; aucun executable tiers lance.

## Lancer simplement

Telecharger le ZIP de la branche add-windows-diagnostic, extraire TOUT le depot.
Windows 10/11 x64 + Windows PowerShell 5.1/WPF, sans Python, SDK ni admin.
Double-cliquer setup-engineer\Lancer-Setup-Engineer.bat et accepter O apres
l'avertissement (autorisation temporaire au processus, aucune politique permanente).
Ou ouvrir le tableau de bord puis cliquer **Setup Engineer**.

1. Le champ source propose automatiquement :
   C:\Users\<vous>\AppData\Local\acr\Saved\SaveGames\CarSetupsDataSaveSlot.sav
   Pour le premier test, choisir une COPIE .sav du diagnostic avec « Choisir SAV ».
   Vos copies numerotees n'ont pas toutes le meme type : 000001.sav du dernier
   lot est la sauvegarde des setups ; 000005.sav est celle des tentatives.
2. Cliquer « Lire et conserver ». Selectionner la voiture et le nom du setup.
3. Verifier les reglages dans le tableau. Unite/plage inconnue est intentionnel.
   UnitCandidate est une hypothese, pas une conversion autorisee.
4. Le snapshot JSON est conserve dans :
   %LOCALAPPDATA%\ACR-Optimal\SetupEngineer\Snapshots
   Ouvrir ce dossier via Windows+R ; aucune version existante n'est ecrasee.
5. Creer une deuxieme version DANS LE JEU : modifier un seul parametre, noter sa
   valeur et sauvegarder le setup. Ne pas editer le SAV avec un outil externe.
6. Lire de nouveau la sauvegarde, puis onglet Comparer versions : choisir A/B
   pour la MEME voiture, cliquer Comparer. Delta = B-A en valeur brute ; un enum
   change est signale sans delta numerique. Les identifiants de contenu sont
   stables si les reglages et le contexte restent identiques.
7. Apres fermeture/relancement, « Ouvrir une version JSON » charge chaque ancien
   snapshot. Charger A et B puis comparer : l'historique est conserve localement.
8. Onglet Comportement : tarmac=asphalte, gravel=gravier, snow=neige ;
   understeer=sous-virage, oversteer=survirage, braking=freinage,
   traction=motricite, stability=stabilite, bumps=bosses ;
   entry=entree, mid-corner=appui, exit=sortie, straight=ligne droite.
   Renseigner le ressenti observe ; hypotheses avec compromis et protocole.
   Il ne s'agit ni d'un diagnostic telemetrique ni d'une garantie de gain.

## Donnees et limites

Aucune ecriture dans les fichiers du jeu, aucun encoder SAV. La base SQLite des
chronos n'est ni ouverte ni modifiee par ce module. Snapshots JSON separables.
Il n'y a pas de surveillance setup automatique ni detection du setup applique.
On peut lire automatiquement le chemin connu, mais seuls les setups sauvegardes
et compatibles sont visibles : le fichier ne prouve pas celui utilise en course.
Si le jeu ecrit pendant la lecture, recommencer apres la sauvegarde stabilisee ;
la version de source est identifiee par son hash, pas par sa date seule.

Chaque reglage contient Key, RawValue, Value/Kind, Unit=null, UnitStatus=unknown,
UnitCandidate, AllowedRange (min/max/pas/choix inconnus), offset et validation.
Ne pas convertir les raideurs/toe/garde au sol sur la seule base du nom de cle.
Voiture/version de jeu/surface devront figurer dans le futur catalogue valide.
La surface n'est pas extraite : elle est declaree uniquement pour une analyse.
La recommandation n'est pas appliquee, ne modifie aucun snapshot existant et
n'utilise pas de service IA. Les limites doivent etre lues dans les menus du jeu.

## Liaison prospective aux chronos

Le moteur expose New-AcrSetupLinkTemplate : modele de liaison initialement
NON CONFIRME, sans AttemptKey ni StageId. Aucun lien historique n'est cree.
Exemple de ligne de commande optionnelle dans une session PowerShell autorisee :

```powershell
Import-Module .\setup-engineer\SetupEngine.psm1
$s = Read-AcrSetupSnapshot 'C:\CHEMIN\setup-xxx.json'
New-AcrSetupLinkTemplate $s.Setups[0] | ConvertTo-Json
```

Ce template prepare la future table de liaisons sans importer ces hypotheses
dans SQLite. Il faudra conserver la preuve du setup applique avant la tentative,
associer la cle du bon joueur/voiture/speciale et confirmer les secteurs. Un nom,
une date proche ou un fichier « le plus recent » ne suffisent pas.

## Protocole de validation PC

Attendu sur votre copie 000001.sav : Polo « Sisteron 06 », Fabia « alsace 06 »,
65 parametres chacun, version 0.6.0.100866. Comparer surtout bias, ressorts,
pressions, carrossage et amortisseurs avec les menus du jeu. Photographier les
valeurs et les limites affichees. Changer UN parametre dans le jeu, lire une
seconde copie puis transmettre les deux snapshots et les captures. Verifier
que le delta correspond et que les autres reglages restent identiques.
Conserver les originaux et ne pas valider en bloc les unites.

Tests developpeur : tests/verify_setups.ps1 -ModulePath chemin\SetupEngine.psm1
-SavePath copie\000001.sav -WorkDir dossier-neuf. Tests PowerShell 7/Linux sur
votre copie : extraction reelle, valeurs, hashes, versions, comparaison, modification
SYNTHETIQUE separee, refus des donnees inconnues et source intacte. WPF/double-clic
et correspondance aux menus doivent encore etre verifies sur votre PC.

## Intégration à l'application principale

Lancer maintenant **Lancer-ACR-Optimal.bat** à la racine, puis la section Setup
Engineer. Le module est embarqué dans la fenêtre principale. L'ancien lanceur
ouvre la même application directement sur cette section. L'historique des JSON
existants est chargé au démarrage ; Actualiser historique recharge sans doublons
les mêmes fichiers. Les snapshots et la base SQLite restent à leur emplacement.
Voir [la procédure intégrée](../interface-windows/README.fr.md) pour les tests.
