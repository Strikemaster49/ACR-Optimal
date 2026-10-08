# Diagnostic ACR en contre-la-montre

Ce paquet ne contient PAS de connecteur solo verifie. Il observe Windows sans
modifier le jeu, lire sa memoire ou envoyer une requete a ses serveurs. Aucun
Python, SDK .NET ou paquet a installer : Windows PowerShell 5.1 suffit.
Verification ici : analyse syntaxique PowerShell 7 reussie ; test avec commandes
Windows simulees reussi pour transitions TCP, deduplication UDP, changements de
fichier et arret du processus. Ces simulations ne valident pas les API Windows.
Le script n'a pas encore ete execute sur Windows avec ACR. Les essais ci-dessous
sont necessaires avant de conclure quoi que ce soit sur les chronos.

## 1. Premier lancement

Extraire tout le paquet. Lancer ACR, puis ouvrir le Gestionnaire des taches,
onglet Details, et relever le PID du processus executable du jeu (pas Steam).
Double-cliquer Lancer-Diagnostic.bat et entrer ce PID. La premiere version
n'observe alors que les connexions reseau, pendant 15 minutes maximum.

Si Windows bloque un fichier telecharge, verifier sa provenance puis utiliser
Proprietes > Debloquer pour le BAT et le PS1 si cette option est presente.
Si une politique PowerShell bloque encore le script, l'erreur est affichee :
ne pas modifier une politique d'entreprise. Sur un PC personnel, une exception
limitee au processus peut etre utilisee apres lecture du script :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Diagnostic-ACR.ps1 -GameProcessId 1234
```

Remplacer 1234 par le PID reel. Aucun changement persistant de politique.
Commencer sans elevation ; si errors.csv indique un refus d'acces aux commandes
reseau, refaire le diagnostic dans un terminal administrateur.

## 2. Observer les fichiers du jeu

Identifier les dossiers reellement utilises par ACR sur ce PC. Ne pas supposer
un nom de dossier Saved, une structure ou un format de sauvegarde.
Pour les localiser, Process Monitor de Microsoft Sysinternals peut etre filtre
sur le PID du jeu, operations WriteFile/CreateFile. Son utilisation et son
installation sont facultatives. Ne pas surveiller tout le profil utilisateur.

Lancer depuis PowerShell, dans le dossier du paquet :

```powershell
.\Diagnostic-ACR.ps1 -GameProcessId 1234 -WatchPath 'C:\CHEMIN_REEL\Logs','C:\CHEMIN_REEL\SaveGames' -DurationMinutes 20
```

Les chemins doivent exister. Le script enregistre uniquement chemin, taille et
date de modification. Il ne copie pas le contenu des fichiers. Des changements
de contenu conservant taille et date, des fichiers supprimes ou des fichiers
temporaires entre deux scans peuvent ne pas etre observes. Choisir de petits
dossiers pour limiter le cout du scan. errors.csv rapporte les dossiers illisibles.
Le dossier de sortie ne doit pas se trouver dans un dossier observe.

## 3. Protocole d'essai

1. Noter la version du jeu, speciale exacte, sens, voiture et conditions.
2. Rester 30 secondes dans le menu pour avoir une reference.
3. Choisir explicitement le contre-la-montre. Le diagnostic ne detecte PAS le mode.
4. Finir une tentative A et photographier les temps affiches au resultat.
5. Faire une tentative B plus lente au total mais meilleure sur un secteur.
6. Consulter le classement et photographier les secteurs de son entree.
7. Faire une tentative interrompue/recommencee ; puis changer voiture ou speciale.
8. Quitter avec Q dans la console.

Les touches D/S/F/R/C marquent depart/secteur/arrivee/redemarrage/classement
UNIQUEMENT quand cette console a le focus. Ce ne sont pas des raccourcis globaux.
Ne pas interrompre la conduite pour les presser : un second operateur ou une
video de reference peut remplacer ces reperes. Leur horodatage mesure votre
action, jamais le chrono du jeu. D incremente l'identifiant manuel de tentative.

Sortie : %LOCALAPPDATA%\ACR-Optimal\Diagnostics\<session unique>.
- session.json : PID, nom du processus, debut, dossiers choisis.
- network.csv : apparition/disparition d'endpoints TCP/UDP appartenant au PID.
- files.csv : fichiers initialement observes ou modifies.
- markers.csv : reperes manuels si vous en avez saisi.
- errors.csv : echecs, s'il y en a ; ended.txt : fin de session.

Un CSV absent signifie qu'aucune ligne correspondante n'a ete ecrite ; verifier
errors.csv. UDP expose ici les ports LOCAUX, pas les destinataires. Le sondage
peut manquer les connexions breves, les sous-processus ou le trafic de Steam.
Aucune connexion observee ne prouve l'absence de communication.

## 4. Capture de paquets facultative

Les endpoints ne contiennent aucun payload. Pour examiner les echanges, utiliser
Packet Monitor (pktmon, integre aux Windows recents) ou Wireshark avec Npcap.
Ne pas installer de pilote pour le simple diagnostic des etapes precedentes.

Exemple avec pktmon, dans un terminal administrateur, pour une session courte :

```powershell
pktmon status
pktmon filter list
pktmon help start
pktmon start --capture --pkt-size 0 --file-name "$env:TEMP\ACR-TT.etl"
# Effectuer une tentative, puis consulter le detail des secteurs du classement.
pktmon stop
pktmon etl2pcap "$env:TEMP\ACR-TT.etl" --out "$env:TEMP\ACR-TT.pcapng"
```

Verifier les commandes avec l'aide locale, elles peuvent varier selon Windows.
Si une capture est deja active, ne pas l'arreter : utiliser une autre session
ou demander a son proprietaire. Des filtres preexistants peuvent masquer le
trafic utile : ne pas les supprimer aveuglement. Arreter uniquement la capture
que vous avez demarree, meme en cas d'echec du test.
Cet exemple peut capturer le trafic d'autres applications. Fermer les applications
inutiles ; conserver les captures localement. Elles peuvent contenir identifiants,
jetons et donnees privees. Ne pas transmettre une capture brute sans examen.

Dans Wireshark, rapprocher les IP/ports TCP de network.csv et utiliser les ports
UDP locaux comme candidats, pas comme preuve d'identite. Comparer les periodes
menu, passage, arrivee et ouverture du classement. Rechercher une structure
decodable et des valeurs correspondant aux temps affiches, pas seulement des
paquets au meme instant. TLS ou un flux non decode ne permet pas de lire les
secteurs. Ce paquet n'installe aucun certificat, ne desactive pas TLS et ne
contourne pas le chiffrement.

## 5. Tests de l'outil avant une session reelle

- PID inexistant : erreur claire, aucune collecte attribuee a un autre processus.
- Dossier inexistant : erreur avant le lancement de la session.
- Petit dossier temporaire : creer puis modifier un fichier pendant la collecte ;
  verifier first-seen puis changed dans files.csv.
- Quitter le processus observe : errors.csv doit signaler sa fin, ended.txt existe.
- D, S, F, D, R, Q : verifier l'ordre des reperes et les numeros de tentatives.
- Deux executions : deux dossiers distincts, aucune sortie ecrasee.

## 6. Conditions pour implementer le collecteur

Une source est exploitable seulement si les valeurs identifiees correspondent
aux secteurs affiches sur A ET B, meme si B ne bat pas le record total. Identifier
aussi depart, reset, arrivee, validite, speciale et voiture, et prouver le mode TT.
Verifier unites, cumul/duree, penalites, nombre de secteurs, precision et changements
de version. Un resultat du classement seul ne suffit pas pour toutes les tentatives.

Le futur collecteur Windows pourra etre une application C#/.NET autonome :
source verifiee -> evenements normalises -> validation de tentative -> SQLite.
Champs proposes : sessionId, attemptId, gameVersion, mode, stageId, carId,
sectorIndex, rawValue, unit, cumulativeOrDuration, penalty, validity, source.
Conserver la precision de la source sans inventer de millisecondes. Un mode inconnu
ou multijoueur ne doit pas alimenter les records TT. Une tentative incomplete
reste distincte d'un resultat valide. Le calcul des meilleurs secteurs vient ensuite.
