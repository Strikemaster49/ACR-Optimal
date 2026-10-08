# Acquisition : audit acr-live-timing

Source examinee : https://github.com/FlorentDChamps/acr-live-timing
Commit : 81906637e1c7dbf43ec766f831e3b6d948eca083.
Audit de code, sans execution avec le jeu. ACR-Optimal est vide au debut de ce travail.

## Sources reelles

- src/Net/RawSocketSniffer.cs : socket IPv4 raw et SIO_RCVALL, paquets entrants,
  droits administrateur. Pas de memoire partagee ou API de telemetrie dans ce chemin.
- src/Net/ServerDetector.cs : selection d'un serveur public via signatures ;
  ignore IP privees/loopback et plusieurs ports Steam. Le detecteur seul reste
  heuristique : un endpoint reconnu n'est pas une validation des chronos.
- src/Decode/LobbyDecoder.cs et ReplicationDecoder.cs : decodage du protocole de
  replication Unreal en clair, pas appels a une API de classement mondial.
- src/Net/PcapWriter.cs et PcapReplay.cs : enregistrement/relecture offline du
  trafic. Les PCAP sont une source de replay, pas un export de resultats du jeu.
- tools/extract-acr-replayout.py : generation de descriptions de structures depuis
  un dump UE4SS. Ce n'est pas le lecteur de memoire utilise pendant la collecte.
- src/Web/WebServer.cs : serveur d'affichage local de l'application, pas une API ACR.

## Donnees decodees

ReplicationDecoder.ApplySectors lit RaceSectorsPlayerData.SectorsRecords et les
champs Time, conserves par index. ApplyRaceState lit RaceId, RaceTime, Phase,
DistanceOnMainSpline et bRaceTimeValid. Les identifiants de speciale comprennent
TravelTrackId/TrackId/PendingTrackId ; les participants/resultats portent CarId.
Les resultats portent des passages cumules et PenaltyTotalTime. Engine.ApplyResults
additionne raw et penalty pour le total affiche et ignore ResultSource.Best dans
ce chemin. La matrice gere egalement des passages de l'ancienne speciale presentes
au spawn : reprendre des valeurs sans gerer les resets serait dangereux.

Les valeurs Time sont lues en float ; cela ne suffit pas a promettre une precision
absolue au milliseconde. La documentation rapporte des comparaisons avec l'ecran,
non reproduites ici. Pour un cumul C, duree du secteur i = C[i] - C[i-1].
Le dernier secteur doit etre traite selon que l'arrivee fait partie ou non du tableau.

## Contre-la-montre et reutilisation

Aucun connecteur TT ni endpoint du classement mondial n'a ete identifie dans
ce chemin. En solo, un serveur public et son flux de replication peuvent manquer.
La capture utilisateur prouve l'affichage de durees par secteur au classement ;
elle ne prouve ni le transport, ni une API accessible, ni la conservation de toutes
les tentatives. Une requete de classement et l'envoi de resultat peuvent utiliser
un autre protocole, du TLS ou un autre processus : a mesurer, pas a supposer.

Reutilisable conceptuellement : collecte passive, separation decodeur/modele,
captures rejouables, correlation speciale/voiture, gestion resets et penalites.
Le sniffing et le decodeur ne sont reutilisables pour TT qu'apres preuve d'un flux
compatible. Le projet declare GPL-3.0-or-later : une reprise de code impose une
analyse de compatibilite de licence. Le diagnostic fourni ici est independant et
ne copie pas son code. Il ne depend pas de son installation.

Decision : fournir un diagnostic Windows maintenant ; choisir le connecteur
seulement apres le protocole de test du README. Si un fichier expose les tentatives,
preferer sa lecture ; si une sortie telemetrique documentee existe, la verifier ;
si un flux en clair contient les secteurs, le decoder avec captures de reference.
La piste objets internes reste une recherche distincte, non implementee ici.
