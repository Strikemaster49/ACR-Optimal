# Stockage SQLite experimental — premiere version Windows

Cette version importe les exports du lecteur, pas les sauvegardes du jeu.
Aucune surveillance automatique d'ACR n'est activee. Les exports d'origine
restent inchanges. La base est separee de toute future base principale.

## 1. Installation et premier import

Telecharger le ZIP de la branche add-windows-diagnostic sur GitHub et **extraire
tout le depot**. Conserver stockage-windows et diagnostic-windows cote a cote.
Windows 10/11 x64, Windows PowerShell 5.1 64 bits et la DLL systeme winsqlite3.dll
sont requis. Aucun Python, SDK .NET, DLL telechargee ou droit administrateur.
Si une politique d'organisation bloque PowerShell/Add-Type, le lanceur ne la
contourne pas : demander une autorisation a l'administrateur.

Double-cliquer stockage-windows\Lancer-Stockage-Experimental.bat. Accepter O
apres lecture de l'avertissement d'autorisation limitee au processus. Choisir **1**.
Donner le chemin complet du dossier **Comparaison-ACR** contenant les trois
nouveaux dossiers d'export du lecteur (secteurs.csv, blocs.csv, preuve.json).
Copier son chemin avec Ctrl+L puis Ctrl+C dans l'Explorateur ; pas de guillemets,
pas de %LOCALAPPDATA% litteral, pas de fichier .sav.

Resultat attendu pour vos trois derniers exports : **7 nouvelles tentatives,
11 observations deja presentes, 0 conflit ; 7 conservees, 0 admissible**.
Les 11 observations repetent des tentatives deja vues dans les autres copies :
elles ne sont pas des lignes supplementaires dans la table des tentatives.

Base locale :

```text
%LOCALAPPDATA%\ACR-Optimal\Experimental\acr-experimental.sqlite3
```

Rapports : %LOCALAPPDATA%\ACR-Optimal\Experimental\Rapports\<dossier unique>.
Le lanceur affiche les chemins complets. Pour ouvrir le dossier dans Windows,
utiliser Windows+R avec %LOCALAPPDATA%\ACR-Optimal\Experimental.

## 2. Test de doublons et de redemarrage

Relancer le BAT, choisir **1**, indiquer le meme dossier. Attendu : **0 nouvelle,
18 deja presentes, 0 conflit**, toujours 7 tentatives conservees.
Fermer puis relancer le BAT, choisir **2** : les sept tentatives doivent rester.
Les originaux secteurs.csv et les copies .sav ne sont ni supprimes ni modifies.
Un CSV ancien sans cles, un cumul incoherent ou un fichier illisible fait echouer
l'import de l'ensemble du lot sans importer les autres fichiers partiellement.

La cle candidate est associee au profil joueur : joueur-local par defaut. Ne pas
importer les exports d'autres joueurs sous ce profil. La stabilite a ete verifiee
sur les echantillons, pas sur tous les modes/resets possibles du jeu.

## 3. Quarantaine et validation des donnees

Les exports actuels ne demontrent pas automatiquement mode, validite, arrivee et
penalites : chaque tentative entre donc en quarantaine. **0 admissible est normal**.
Une revue manuelle explicite peut autoriser des calculs EXPERIMENTAUX apres
comparaison avec les resultats du jeu. Cela n'est pas une validation automatique
du decodeur ou une preuve de la politique de penalites d'ACR.

Choisir **3** dans le BAT : un fichier revue-<id>.json est cree, sans ecraser un
fichier existant. Ouvrir ce JSON dans un editeur texte. Chaque decision indique
speciale, voiture, jeton de bloc et index local (0 = tentative 1 du bloc).
Ne pas changer AttemptKey, RawHash, PayloadHash ni les informations de contexte.
Les champs importants a renseigner pour UNE tentative verifiee sont :

```json
"Mode": "TT",
"Validity": "valid",
"Complete": true,
"SectorsVerified": true,
"ExpectedSectorCount": 2,
"PenaltySeconds": 0,
"OfficialFinalSeconds": 138.296,
"ConfirmAgainstGame": true,
"Note": "Comparee au classement de session et sans penalite"
```

Cet exemple de chrono concerne uniquement la nouvelle tentative 1 de votre
capture ; ne pas recopier ce chrono sur les autres tentatives. Utiliser un point
decimal dans JSON, des secondes (pas 2:18.296), true/false sans guillemets, et
respecter les virgules de l'objet existant. Pour la nouvelle tentative 2, le
chrono affiche est 137.413 s. Le token de leur bloc est 9019ef0e2825df08.
Ne valider ces lignes que si leurs secteurs ont ete verifies, la tentative est
complete et la penalite nulle effectivement confirmee. Les anciennes tentatives
non verifiees gardent ConfirmAgainstGame=false.

Choisir **4**, puis fournir le chemin du JSON complete. La revue est liee aux
hashes du contenu importe ; une revue obsolete est refusee. Tous les changements
du fichier sont transactionnels : une decision incoherente annule l'application
des autres decisions de cette invocation.

En validant uniquement les deux nouvelles tentatives confirmees, attendu :
2 admissibles, meilleur complet ~137.413 s, optimal ~137.413 s, gains sectoriels
nuls. Un ecart numerique de quelques microsecondes entre le cumul et la somme
des floats peut rester visible ; le chrono officiel de la capture est conserve
separement. Les anciennes tentatives restent stockees mais exclues.

Pour une penalite connue, renseigner PenaltySeconds et, si disponible, le chrono
officiel incluant la penalite. Ne pas supposer qu'une penalite inconnue vaut zero.
Penalises, invalides (Validity=invalid), abandonnes (Validity=abandoned), incomplets
(Complete=false), autres modes (Mode=other) et inconnus restent exclus des calculs
de cette version, tout en etant conserves. Pour revoquer une revue, appliquer une
decision explicite avec ConfirmAgainstGame=true et les statuts corriges ; une
decision non confirmee est ignoree et ne revoque pas une revue precedente.

## 4. Rapports et graphiques a venir

- tentatives.csv : toutes les tentatives du profil, statut de revue et conflits.
- conflits.csv : cles existantes avec un nouveau contenu (vide s'il n'y en a pas).
- resume.csv/json : meilleur complet, optimal et gain par speciale/voiture et
  disposition des secteurs, seulement pour les tentatives admissibles.
- gains-secteurs.csv/json : secteurs du meilleur complet, minima historiques et
  gains individuels. Ex aequo : premiere tentative importee, puis id interne.
- progression.csv/json : temps de chaque tentative admissible, record et optimal
  connus a ce point. Ordre de premiere importation, **pas dates d'arrivee verifiees**.
  Un import historique tardif n'est pas replace artificiellement dans le passe.
- rapport.json : effectifs, regles et limites.

Les CSV de statistiques sont vides si aucune tentative n'est admissible ; les
JSON correspondants contiennent []. Les JSON numeriques sont independants de
la locale ; les CSV peuvent employer la virgule decimale selon Windows.
Les graphiques ne sont pas encore dessines, mais leurs series sont preparees.
Les profils et les dispositions differentes ne sont pas melanges. Les conditions
meteo ne sont pas connues dans l'export actuel : les rapports ne garantissent
pas une comparaison a conditions identiques et n'implementent pas encore ce filtre.
La version du jeu n'est pas non plus presente dans ces CSV ; ne pas melanger
des exports de versions incompatibles. Les lignes totalement absentes de l'export
(par exemple un abandon sans aucun secteur) ne peuvent pas etre inventees/importees.

## 5. Fiabilite et interpretation des temps

raw_final dans tentatives.csv est le DERNIER CUMUL de la source. Il n'est un chrono
global confirme que lorsque l'arrivee/complete a ete verifiee. Aucun chrono final
n'est invente pour un abandon. Le temps officiel de revue est stocke separement.
Les penalites absentes de ces exports sont inconnues ; seuls leurs montants
explicitement verifies en revue sont enregistres.

Le controle experimental accepte au plus 0.005 s entre chaque difference de
cumuls et sa duree, puis entre chrono officiel et dernier cumul + penalite lorsque
ces deux informations sont disponibles. Cette tolerance permet les ecarts de
representation observes ; elle ne justifie pas une difference de regles inconnue.
La semantique des penalites doit encore etre verifiee dans ACR avant automatisation.
Le rapport indique l'ecart entre chrono complet et somme des secteurs, sans le
masquer ou ajuster les secteurs. Le module avancé reste une etape ulterieure.

Si une cle existante change de contenu, le premier contenu reste intact, un
conflit est enregistre et la tentative est exclue, meme si elle etait revue.
Le lanceur indique un echec APRES sauvegarde du conflit et du rapport. Importer
encore le meme conflit ne cree pas de nouvelle tentative ni de nouveau conflit
identique. Aucun effacement ou remplacement automatique n'est prevu : une
resolution explicite devra etre developpee apres diagnostic du cas reel.
Les exports sont des preuves de travail, pas des signatures d'authenticite : un
CSV modifie coheremment ne peut pas etre authentifie sans sa source binaire.

Les tables SQLite sont attempts, sectors, observations, conflicts, reviews.
UNIQUE(profile,attempt_key) evite les doublons ; PRIMARY KEY(attempt_id,sector_index)
evite les secteurs dupliques. Les nombres sont stockes en REAL, jamais en texte
localise. Ce protocole contient des Float32 : l'import reconstruit ces valeurs
a partir des decimales exportees et compare leurs bits, pour eviter des conflits
causes uniquement par les formats a 15/17 chiffres ou point/virgule decimale.
Un futur format de source devra avoir un importeur/version adapte.
Requetes parametrees, cles etrangeres actives, transactions, timeout de
verrouillage et marqueur d'application/schema. Une base d'une autre application
est refusee. Aucun import automatique dans une future base principale.

Pour sauvegarder cette base : fermer tous les lanceurs de stockage, puis copier
acr-experimental.sqlite3 dans un dossier de sauvegarde. Ne pas copier une base
en cours d'ecriture. Ne pas supprimer la base pour reimporter : utiliser un
autre chemin experimental si un essai propre est necessaire.

## 6. Ligne de commande (optionnel)

Depuis stockage-windows, dans PowerShell apres l'autorisation appropriee :

```powershell
.\Stockage-Experimental.ps1 -Action Import -ExportFolder 'C:\CHEMIN\Comparaison-ACR'
.\Stockage-Experimental.ps1 -Action Rapport
.\Stockage-Experimental.ps1 -Action ExporterRevue
.\Stockage-Experimental.ps1 -Action AppliquerRevue -ReviewPath 'C:\CHEMIN\revue.json'
```

Tous les appels peuvent preciser -Profile 'pilote-2' et -DatabasePath vers une
AUTRE base experimentale. Ne jamais pointer ces commandes sur une base principale.
Le repertoire des scripts peut contenir des espaces ; ne pas deplacer seulement
le BAT hors du depot extrait.

## 7. Validation effectuee et limites

Tests passes avec PowerShell 7/Linux et une vraie SQLite via libsqlite3.so.0 :
import des vrais exports (7 tentatives), import repete, redemarrage dans un NOUVEAU
processus, preservation des sources, quarantaine, coherence des temps, rollback
de revue/import, conflits conserves sans remplacement, calculs/gains et progression
sans utilisation des minima futurs. Des fixtures explicitement separees testent
abandons, invalides, incomplets, penalises et autres modes. Ces fixtures ne prouvent
pas la lecture de ces etats dans le jeu.

Le test adapte uniquement le nom de la bibliotheque native pour Linux, pas les
requetes ni l'importeur. L'appel reel a winsqlite3.dll, Windows PowerShell 5.1 et
le double-clic restent a verifier sur votre PC. Aucun test n'est presente comme
une preuve d'acquisition automatique. Les vrais exports restent non admissibles
tant qu'aucune revue explicite et fiable n'a ete faite.

Tests developpeur : tests/verify_sqlite.ps1 avec ModulePath et un WorkDir neuf.
Sur Windows, passer le module original ; RealExports permet de tester vos trois
exports connus sans publier les fichiers personnels dans Git. Python n'est pas
necessaire a cette suite ni au fonctionnement de l'outil.
