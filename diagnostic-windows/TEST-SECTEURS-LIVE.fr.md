# Priorite : sauvegarder les secteurs avant la fin de session

Confirmation utilisateur : apres fermeture complete et relancement, le classement
de session repart a zero. Cela prouve sa disparition de l'interface, pas l'absence
de donnees residuelles sur disque. Nous ne dependons plus d'une recuperation future
du classement. Aucun acces aux secteurs n'est encore demontre par nos diagnostics.

## Lancement

Depuis le ZIP de la branche add-windows-diagnostic, extraire tous les fichiers,
puis lancer diagnostic-windows\Lancer-Secteurs-Live.bat. Confirmer TT, speciale/sens,
voiture et choisir un petit dossier REEL du jeu contenant logs ou sauvegardes.
Si vous ne connaissez pas ce dossier, ne pas inventer un chemin : la localisation
du dossier est un prerequis a cette piste. Examiner les dossiers du jeu sous
Documents ou %LOCALAPPDATA%. Ne pas choisir un disque ou le profil entier.
Les limites sont 2000 fichiers, 4 MiB par fichier lu et 100 MiB de copies au total.

Repondre O pour conserver les petits fichiers candidats LOCALement : sans copies,
les hashes permettent de localiser des changements mais pas de decoder les temps.
L'outil n'ecrit que dans %LOCALAPPDATA%\ACR-Optimal\SectorEvidence\<session unique>.
Si PowerShell bloque le script, suivre README.fr.md. Aucun besoin de Python.

## Test sur PC : ne pas fermer ACR avant verification des preuves

1. Lancer le diagnostic avant le debut d'une session TT ; attendre cinq secondes
   pour la reference. Noter version du jeu et conditions.
2. Dans la console presser D avant de partir. Finir A, SANS ouvrir le classement.
   Revenir a la console, presser A et attendre cinq secondes. Noter le temps global.
3. Ouvrir le classement de SESSION, photographier A et tous ses secteurs ; presser
   O dans la console, attendre cinq secondes. Fermer le classement, presser F.
4. Refaire avec B, plus lente au total mais meilleure sur un secteur si possible.
   Presser D/A/O/F aux memes etapes et conserver les deux lignes du classement.
5. Faire une troisieme tentative ou un redemarrage pour tester les doublons et
   les tentatives interrompues. Rouvrir deux fois le classement SANS nouveau run.
6. Finir le diagnostic avec Q dans sa console AVANT de fermer la session.
   Verifier ended.json, files.csv, errors.csv s'il existe, et snapshots si O choisi.
   Si la duree de dix minutes expire, reprendre dans un nouveau dossier : ne pas
   considerer des periodes hors observation comme validees.

Touches uniquement lorsque la console a le focus : aucun hook global. Ne pas
interrompre la conduite ; un second operateur ou une video peut remplacer les
reperes. Attempt et Phase sont des labels MANUELS, pas une detection du jeu.
Les changements de fichiers sont sondes en continu entre ces reperes ; 500 ms
est l'attente entre scans, pas une garantie de frequence ni d'exhaustivite.

Les fichiers textuels candidats sont seulement examines pour des mots indicateurs.
Les formats binaires, UTF-16 ou secondes numeriques peuvent ne pas produire d'indice.
Un fichier en cours d'ecriture est reessaye ; une copie peut quand meme etre
incoherente. Les db/wal/shm ne constituent pas une sauvegarde SQLite atomique.
Un format inconnu ou une erreur de lecture ne doit pas etre interprete comme
l'absence de secteurs. Les copies peuvent contenir des donnees privees ; ne
partager que les candidats verifies, pas l'ensemble des fichiers personnels.

## Ce qui permettra de choisir un collecteur

Validation ici : syntaxe PowerShell 7 reussie ; tests sous Linux avec saisie et
temporisation simulees passes pour scans repetes, changements, absence de doublons
sur fichiers inchanges, hashes des copies, suppression, sortie finale, absence de
copies par defaut et refus d'un mode autre que TT. Aucun test Windows/ACR effectue.
Pour tester l'outil sur PC avant le jeu : choisir un dossier temporaire avec un
petit .json, le modifier deux fois, puis le supprimer pendant la collecte. Verifier
files.csv, removed-files.csv et les copies si O choisi. Les doublons de tentatives
du jeu restent un probleme distinct des fichiers inchanges du diagnostic.

- Source disponible a l'arrivee : un candidat capture AVANT l'ouverture doit
  contenir les valeurs exactes de A et B. Apres preuve, on pourra envisager une
  collecte a chaque arrivee ; le signal d'arrivee doit lui aussi etre identifie.
- Source mise a jour seulement a l'ouverture : les valeurs existent uniquement
  dans les captures APRES ouverture. On pourra observer cette source en continu
  et importer lorsque de nouvelles lignes y apparaissent ; cela ne signifie pas
  que le diagnostic sait ouvrir ou detecter automatiquement l'interface.
- Aucun fichier exploitable : source inconnue, pas necessairement en memoire.
  Tester une courte capture reseau en clair selon README.fr.md, ou rechercher
  une sortie de telemetrie documentee. Le port 443 ne prouve pas du TLS ni une API.
  Un flux chiffre ne donnera pas ses secteurs par simple capture.
- Uniquement les pixels du classement : OCR externe de captures manuelles pourrait
  etre teste comme repli, mais necessite preuve de precision, identite et doublons.
  Aucun OCR ni automatisation de l'interface n'est implemente ici.

Dans tous les cas, comparer les valeurs aux deux captures du classement et aux
totaux sans penalites. Somme des valeurs = total : piste durees individuelles.
Derniere valeur = total : piste cumuls. Repeter et verifier l'arrivee, les unites,
arrondis, penalites et statut valide. La monotonie seule n'est pas une preuve.

## SQLite apres preuve de recuperation, pas de base de records fictifs

Schema prevu : sessions (UUID persistant de capture, version, contexte), tentatives
(session + identifiant source stable, speciale/sens, voiture, mode, validite,
temps brut/final/penalite), secteurs (tentative + index, valeur brute, duree,
type cumul/duree et provenance). Importer tentative ET secteurs dans une seule
transaction. Contrainte unique sur (session, identifiant source), et sur
(tentative,index). A l'ouverture repetee, la meme tentative doit etre mise a jour
ou ignoree, jamais dupliquee. Ne pas dedupliquer uniquement sur voiture/temps :
deux tentatives reelles peuvent avoir les memes chronos. Sans identifiant source,
il faudra prouver une correspondance de lignes et leurs resets avant de promettre
une deduplication fiable. Les UUID de sessions restent stockes entre relancements
du collecteur pour ne pas reimporter une session deja vue.

Les meilleurs secteurs sont derives des tentatives valides compatibles avec la
meme speciale, sens, voiture et disposition des secteurs. L'optimal est la somme
des minima PAR INDEX, pas la somme des passages cumules. Ne pas utiliser zeros
pour les secteurs manquants. Les donnees TT doivent etre identifiables dans la
source avant d'activer les records automatiquement. Historique SQLite local
persistant sous %LOCALAPPDATA%\ACR-Optimal, sauvegarde independante du jeu.

Limite actuelle : aucune lecture memoire, injection, modification du jeu ou
interception TLS. Observation de fichiers selectionnes uniquement. Les anciens
diagnostics sont conserves. Tant que les valeurs reelles ne sont pas extraites,
ni collecte d'arrivee ni collecte de classement ni base de chronos ne sont actives.
