# Collecteur passif EXPERIMENTAL

Cette version teste l'enchainement surveillance -> copie -> decodeur -> SQLite.
Elle ne prouve PAS encore une acquisition automatique fiable a chaque arrivee,
ne detecte pas le mode du jeu et ne valide jamais automatiquement une tentative.
Elle ne lit pas la memoire du jeu, ne capture pas le reseau et ne modifie aucun
fichier du jeu. Source ouverte en lecture partagee, deux lectures egales espacees
 de 600 ms avant copie ; ce controle n'est pas une garantie absolue d'atomicite.

## Test simple sur votre PC

1. Fermer les lanceurs de stockage puis sauvegarder acr-experimental.sqlite3
   dans un autre dossier. Conserver tous les exports originaux.
2. Extraire tout le ZIP. Double-cliquer collecteur-windows\Lancer-Collecteur.bat.
   Accepter O (processus temporaire), puis saisir TT si la session est bien TT.
   Aucune demande admin. Parametres par defaut : Obersteigen / Skoda Fabia RS
   Rally2, joueur-local, PlayerDataSaveSlot.sav dans acr\Saved\SaveGames.
3. La premiere capture importe egalement les tentatives historiques compatibles.
   Les doublons restent uniques, les validations existantes sont conservees.
4. Faire une tentative, rester a l'arrivee 10 secondes SANS ouvrir le classement.
   Noter l'heure et le chrono. Observer si le collecteur annonce une nouvelle ligne.
5. Ouvrir ensuite le classement de SESSION, photographier secteurs et global.
   Noter l'heure. Ne pas supposer que l'ouverture est necessaire.
6. Faire une seconde tentative moins rapide et repeter. Puis fermer completement
   ACR, relancer meme speciale/voiture, refaire une tentative.
7. Dans l'interface, Actualiser : les nouvelles lignes doivent etre EN ATTENTE.
   Valider uniquement apres comparaison avec le jeu via une revue de stockage.
8. Transmettre collecteur.csv, session.json, les nouvelles copies .sav et captures
   afin de verifier chronologie, secteur/global, identifiants, retention et doublons.

Les preuves sont dans %LOCALAPPDATA%\ACR-Optimal\CollectorEvidence\<session>.
Le collecteur s'arrete apres 15 minutes (configurable 1-120), 500 captures ou
100 MiB. Fermer sa fenetre pour arreter plus tot. Conflit : capture et conflit
conserves, arret ; consulter les rapports du stockage. Source non reconnue :
copie conservee, erreur visible, pas d'import fabrique. Un fichier non reconnu
n'est pas retraité avant que son contenu change ; relancer apres correction.
Une courte indisponibilite du fichier differe la lecture. Une sauvegarde peut
remplacer plusieurs fois son contenu entre lectures : une tentative jamais
persistee peut manquer. Collecteur actif uniquement pendant ce test.

Source actuelle demontree sur les copies : blocs contenant durees individuelles
et cumuls. Les trailers non nuls/voitures differentes dans un bloc restent refuses
par le lecteur. Pas de detection automatique speciale/voiture/penalites/validite,
pas de validation globale du format. Ne pas utiliser hors TT ou sur d'autres
speciales/voitures sans protocole adapte. Pas d'installateur unique encore.

Ligne de commande optionnelle : Collecteur-Experimental.ps1 -SavePath 'C:\...\PlayerDataSaveSlot.sav'
-DatabasePath 'C:\...\autre-base-experimentale.sqlite3' -Minutes 30.
StageId, CarId et Profile sont egalement parametres ; ne pas changer leurs valeurs
sans connaitre les identifiants exacts et la compatibilite du lecteur.

## Validation developpeur

Tests offline avec les copies fournies : 7 imports initiaux, 0 nouvel import en
relecture, puis 1 nouvelle tentative dans la derniere copie ; 8 inconnues,
0 conflit, sources intactes et integrite SQLite OK. Tests PowerShell 7/Linux :
seul le nom de la DLL native est adapte vers libsqlite3.so.0 dans une copie de
travail ; la declaration Windows du harnais permet de tester le script offline.
Aucun jeu n'est simule, ces tests ne prouvent ni la surveillance Windows ni
la capture a l'arrivee. -Once effectue un seul passage (utile au diagnostic).
Suite : tests/verify_collector.ps1, Root, WorkDir neuf, BaselineSave, NewSave.
