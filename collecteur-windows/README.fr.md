# Collecteur passif pour les sessions quotidiennes

Dans ACR-Optimal, onglet **Chronométrage** :

1. Sélectionner la spéciale/voiture. Le format a été vérifié sur Obersteigen /
   Fabia RS Rally2 ; ne pas présumer la compatibilité des autres combinaisons.
2. Cocher **Je confirme le contre-la-montre**.
3. Laisser **Durée test = 0** pour une collecte SANS limite de temps.
4. Cliquer **Démarrer la collecte**, confirmer l'autorisation temporaire du
   processus PowerShell de fond. Aucune politique permanente ni demande admin.
5. Cliquer **Arrêter** pour arrêter proprement après la transaction en cours.
   Fermer ACR-Optimal demande également l'arrêt. Une fermeture brutale de
   l'application est détectée par l'identité de son processus propriétaire.

Les anciens fichiers BAT du collecteur restent disponibles : ils utilisent
maintenant le même worker, sans limite par défaut. Pour un diagnostic court,
choisir une durée positive (1 à 1440 minutes). Le paramètre CLI -Minutes conserve
ce rôle ; -Once conserve le test d'une seule lecture. Lancer l'application à
nouveau puis cliquer Démarrer reprend la lecture sans doublons. La collecte ne
démarre pas silencieusement au lancement de l'application : confirmer TT.

## États et indicateurs

- Arrêté : worker terminé ou pas encore démarré.
- Démarrage : lancement du worker et ouverture de la base.
- En attente du jeu : aucun processus configuré détecté. Le worker reste actif.
- Connecté au jeu : processus détecté, source pas encore prête.
- Collecte active : processus détecté et surveillance de la source disponible.
- Erreur : lecture/import refusé, conflit, démarrage bloqué ou suivi indisponible.

« Connecté » signifie UNIQUEMENT processus présent : aucune connexion API,
mémoire partagée ou reconnaissance automatique du mode TT. Les noms proposés
sont acr et acr-Win64-Shipping. S'ils ne correspondent pas au jeu sur votre PC,
relever le nom dans Gestionnaire des tâches > Détails et le renseigner dans
Processus du jeu (séparés par virgules, extension .exe facultative). Ne pas
utiliser un nom générique comme Steam. Un nouvel identifiant PID/heure de
lancement provoque une reprise de lecture. Après fermeture du jeu, les derniers
changements du fichier sont encore lus et le worker attend le prochain lancement.
La déclaration TT doit rester vraie pour les sessions jouées pendant la collecte.
Le worker ne peut pas détecter un passage à un autre mode : toute donnée inconnue
reste en quarantaine.

L'écran indique état, nombre total conservé/admissible, dernier événement reçu
(heure locale) et dernière tentative ajoutée durant cette collecte. Cette
« dernière » est une ligne importée, PAS une date d'arrivée automatiquement
prouvée. Aucun nouveau record n'est créé à partir d'une tentative non revue.
Les changements déclenchent une actualisation du tableau de bord ; les chronos
admissibles restent seuls dans les statistiques.

## Données, journaux et fiabilité

La base EXISTANTE %LOCALAPPDATA%\ACR-Optimal\Experimental\acr-experimental.sqlite3
est conservée sans migration. Même importeur, mêmes clés/hashes, transactions
et exclusions. Un verrou de fichier propre à la base refuse deux collecteurs
concurrents (GUI/CLI/deux applications), se libère à la fin du processus et ne
verrouille aucun fichier du jeu. Les revues et imports manuels restent possibles.

Chaque démarrage crée %LOCALAPPDATA%\ACR-Optimal\CollectorEvidence\<session> :
- session.json : contexte, durée, noms de processus, propriétaire ;
- status.json : état atomiquement publié et dernier événement ;
- events.csv / errors.csv : événements et erreurs (créé si erreur) ;
- collecteur.csv : imports et source SHA256 ;
- stdout.log / stderr.log : sortie du processus lancé depuis l'interface ;
- evidence-001, evidence-002... : copies SAV et dossiers d'export.

Deux lectures identiques espacées de 600 ms précèdent l'import. Un fichier
absent ou momentanément verrouillé ne tue pas le worker ; une erreur déclenche
une nouvelle tentative après 10 secondes et un message visible. Les conflits
sont conservés puis arrêtent le worker en erreur pour examen. Aucun ancien
contenu n'est remplacé. Un changement de jeu redémarre la lecture même si le
hash du fichier est inchangé ; l'importeur empêche les doublons.

Les anciennes limites de 500 captures/100 MiB n'arrêtent plus la collecte :
un nouveau segment de preuves est créé. Aucune ancienne preuve n'est supprimée.
Prévoir l'espace disque pour les preuves, et archiver les anciens dossiers
manuellement après arrêt si nécessaire. Le jeu peut écraser plusieurs fois une
sauvegarde entre lectures : une tentative jamais persistée reste inaccessible.
La lecture reste limitée à 8 MiB et aux structures vérifiées du décodeur.

## Protocole de test Windows

Avant le premier test, fermer les outils puis copier la base SQLite et les
preuves ailleurs. Garder les originaux. Noter le total initial : actuellement
11 tentatives conservées, dont les seules revues sont admissibles.

1. Démarrer depuis ACR-Optimal avec durée 0 AVANT le jeu : état attente du jeu,
   historique relu sans doublon. Lancer ACR en TT : collecte active.
2. Jouer plus de 20 minutes. Faire une tentative APRÈS la quinzième minute :
   nouvelle ligne importée, sans arrêt du worker. Vérifier secteurs/classement.
3. Faire une tentative moins rapide : elle doit être ajoutée aussi, en attente.
4. Fermer complètement le jeu : attente, application toujours ouverte. Relancer
   même spéciale/voiture : reprise automatique, anciennes lignes inchangées.
5. Cliquer Arrêter puis Démarrer : pas de doublons. Fermer ACR-Optimal et relancer,
   confirmer TT et Démarrer : mêmes données, collecte reprise.
6. Tester durée 1 minute dans un essai séparé : arrêt à l'expiration, interface
   toujours utilisable. Puis revenir à 0 pour l'usage normal.
7. Ouvrir un second collecteur : erreur explicite, premier reste actif.
8. Vérifier que les nouvelles tentatives n'entrent pas dans les statistiques
   avant revue. Ne pas marquer valides des pénalités/abandons par supposition.

Transmettre status.json, session.json, collecteur.csv, events.csv, errors.csv si
présent, derniers secteurs.csv et captures du classement pour les nouvelles
lignes. Les journaux ne peuvent pas prouver seuls le moment où vous avez ouvert
le classement : noter cette action durant le test.

## Tests réalisés et limites

PowerShell 7/Linux, SQLite réelle (uniquement le nom de DLL adapté dans une
copie de test) : import/réimport/nouvelle copie, quarantaine, source intacte,
intégrité SQLite et lecture seule ; six états et durée 0 sans limite vérifiée
avec une horloge de test ; publication atomique des états. Cycle de processus
simulé : attente, lancement, fermeture, relancement, capture, refus du second
worker, arrêt et reprise sans doublon. Ce test n'exécute PAS Assetto Corsa Rally.
Une session Windows réelle >15 minutes, les noms du processus, le processus
PowerShell de fond et les commandes WPF restent à valider sur votre PC.

Les relances d'une même erreur réutilisent la copie déjà conservée au lieu de
recopier indéfiniment le même SAV. Les preuves et données existantes ne sont pas
supprimées. Le test de cycle de vie vérifie également l'arrêt après disparition
du processus propriétaire, afin de ne pas laisser un worker orphelin.

Le harnais Linux vérifie la disparition du propriétaire par PID, sans comparer
son horodatage (les horodatages .NET Linux peuvent varier entre lectures). Sur
Windows, la commande GUI transmet et vérifie également l'heure exacte de création
pour éviter la confusion en cas de réutilisation du PID ; ce point reste inclus
dans le protocole de test Windows, pas présenté comme vérifié sous Linux.
