# Diagnostic cible : classement de SESSION, contre-la-montre

La source visee est le classement de session, qui affiche selon vos observations
les secteurs de toutes les tentatives. Le classement mondial n'est plus la source
prioritaire : il ne garde que le meilleur resultat global.

## Lancement simple

Double-cliquez Lancer-Classement-Session.bat. Confirmez TT, indiquez speciale/sens
et voiture, puis un dossier REEL de logs ou sauvegardes du jeu. Aucun chemin ACR
n'est suppose. Entree sans dossier permet seulement une observation reseau.
Le nom de processus recherche est acr, observe dans vos precedents resultats.
Le programme retrouve son PID apres relancement.

Suivez les sept etapes affichees : avant speciale, apres tentative A, apres B,
classement ouvert, classement ferme, session et jeu quittes, jeu relance.
A chaque etape, revenez a la console et pressez Entree. La capture est effectuee
apres votre confirmation et n'est pas instantanee. Conservez les valeurs exactes
du classement et les temps totaux de A et B, ainsi que la version du jeu.
Les captures d'ecran sont manuelles ; aucun hook de clavier ou d'ecran n'est utilise.

Si le chemin est inconnu, commencez par examiner les petits dossiers de sauvegardes
et logs visibles sous %LOCALAPPDATA%, Documents et le dossier du jeu. Ne choisissez
pas l'ensemble du disque/profil ni les archives d'installation. Une absence de
fichier observe dans les dossiers choisis ne prouve pas une absence de stockage.

Si PowerShell bloque le fichier, lisez les instructions du README.fr.md sur le
deblocage et les politiques. Aucun besoin d'administrateur pour commencer.

## Contenu des resultats

%LOCALAPPDATA%\ACR-Optimal\SessionDiagnostic\<session unique> contient :
- session.json : contexte confirme MANUELLEMENT, non detecte dans le jeu ;
- phases.csv : horodatages et notes ;
- processes.csv et network.csv : processus et endpoints par phase ;
- files.csv : tailles, dates, hashes SHA256 des petits fichiers candidats,
  changements et nombres d'indices textuels ;
- removed-files.csv et errors.csv si necessaire ; ended.txt en fin d'observation.

Pour conserver des copies locales des petits candidats (optionnel) :

```powershell
.\Diagnostic-Classement-Session.ps1 -WatchPath 'C:\DOSSIER_REEL\Saved' -CopyCandidates
```

La limite est 4 MiB par fichier et 50 MiB copies par phase. Les grandes archives
ne sont pas lues. Les copies sont numerotees ; files.csv relie chacune a son chemin.
Les fichiers du jeu ne sont jamais modifies. Un fichier actif peut etre observe
pendant une ecriture : une copie n'est pas forcement un document ou une base valide.
Pour SQLite, conserver db/wal/shm ne garantit PAS une sauvegarde coherente en cours
d'utilisation. La phase apres fermeture normale du jeu est donc essentielle.
Le lecteur textuel cherche des motifs UTF-8 ; un format binaire, UTF-16 ou des
secondes numeriques simples peuvent ne produire aucun indice. Les mots sector ou
split ne prouvent rien a eux seuls. Les copies peuvent contenir des donnees privees :
ne partager que les candidats examines, jamais tout le profil utilisateur.

## Comment etablir les preuves

1. Localisation : un candidat doit contenir les valeurs exactes de A et B, et leurs
   associations a la speciale/voiture. Son changement a l'ouverture du classement
   est une piste, pas une preuve qu'il est la source de l'interface.
2. Durees/cumuls : pour deux secteurs, comparer le total brut avec S1+S2 puis avec
   le dernier passage. Repeter sur plusieurs tentatives sans penalite. Pour des
   cumuls, convertir par differences ; pour des durees, conserver les valeurs.
   Identifier si le dernier element inclut l'arrivee et les unites/arrondis.
3. Persistance : rechercher les DEUX tentatives dans le candidat apres fermeture,
   puis apres relancement et dans l'interface. Un hash identique ne prouve pas que
   les tentatives y figurent. Une disparition de l'interface n'exclut pas un fichier.
4. Collecte automatique : seulement ensuite, implementer le parseur du format
   constate et verifier des resets, tentatives moins rapides, invalides et penalites.

Si seuls des endpoints sont disponibles, utiliser la capture pktmon facultative
du README pendant l'ouverture/fermeture du classement. Les endpoints ne donnent
pas le payload, et TLS peut empecher la lecture. Ne pas installer de certificat
intercepteur ni desactiver une verification TLS. Le diagnostic n'utilise pas
d'injection, de lecture memoire, d'UE4SS ou de pilote de capture ; il n'interagit
pas avec le processus du jeu. Aucun logiciel ne peut promettre un risque nul avec
toutes les politiques anti-triche ; les commandes ici se limitent a la lecture
de fichiers choisis et aux outils reseau standard de Windows.

## Tests de l'outil

Verification effectuee ici sous Linux : syntaxe PowerShell 7 valide, puis executions
avec API Windows et reponses utilisateur simulees. Les sept phases, changements
d'empreinte, suppression/recreation, integrite des copies, absence de copie par
defaut, deux executions distinctes et refus d'un mode autre que TT ont passe.
Ces tests ne prouvent pas le fonctionnement avec Windows/ACR ni la presence des
secteurs. Les essais reels ci-dessous restent necessaires.

Essayer d'abord un dossier temporaire contenant un fichier .json. Entre deux
phases, modifier ce fichier ; verifier changed et un nouveau hash. Supprimer le
fichier ; verifier removed-files.csv. Creer une nouvelle version ; verifier
first-seen. Avec -CopyCandidates, comparer la copie a la version de cette phase.
Sans ce switch, aucun contenu de fichier ne doit etre copie. Deux executions
doivent produire deux dossiers distincts. Un mode autre que TT doit etre refuse.

## Collecteur et stockage prevus, pas encore actives

Un adaptateur non intrusif du format DEMONTRE produira les evenements de tentative
(identifiant, speciale, sens, voiture, mode, secteurs, final, penalites, validite,
version de source). Un lecteur de resultats ne devra pas reimporter les memes lignes
a chaque ouverture du classement. Les mesures inconnues restent en quarantaine.
SQLite conservera les tentatives sources et leurs secteurs entre les sessions.
Il faudra une preuve du mode TT dans la source pour accepter automatiquement un
record ; le contexte saisi ici est uniquement un repere experimental.

Pour chaque tentative on conserve TOUS les secteurs, et le meilleur temps complet
valide. Pour chaque index de secteur, on calcule le minimum entre tentatives de
la MEME speciale/sens/voiture/disposition des secteurs. L'optimal est la somme
de ces minima. Le meilleur secteur d'une tentative pris seul n'est pas suffisant.
Des secteurs manquants ne doivent pas devenir des zeros. Les conditions et versions
incompatibles doivent pouvoir etre filtrees. Aucun collecteur de chronos ni stockage
de records fictifs n'est active dans ce diagnostic : la preuve d'acquisition vient
d'abord. Ce paquet ne change pas l'outil Diagnostic-ACR.ps1 existant.
