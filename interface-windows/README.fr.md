# ACR-Optimal — application Windows intégrée

Télécharger le ZIP de la branche add-windows-diagnostic, extraire TOUT le dépôt
puis double-cliquer **Lancer-ACR-Optimal.bat** à la racine. Accepter O après lecture
de l'avertissement PowerShell temporaire. Aucun Python ni droit administrateur.
Windows 10/11 x64, Windows PowerShell 5.1 et WPF natif sont requis.

Une seule fenêtre ACR-Optimal, quatre sections :

- **Chronométrage** : meilleur chrono, optimal, gains, tentatives et validation.
- **Performances** : meilleurs secteurs, courbe de progression et comparaison
  des tentatives. Seules les admissibles alimentent les records.
- **Setup Engineer** : lecture SAV, versions sauvegardées, comparaison et outils
  existants. Aucun développement de recommandations avancées dans cette étape.
- **Historique** : toutes les tentatives du profil et versions JSON des setups.

Le sélecteur spéciale/voiture/secteurs filtre les deux premiers écrans. Historique
présente toutes les tentatives du profil. Les graphiques restent ordonnés par
premier import, pas par date de course vérifiée. Les chronos s'affichent au millième,
les valeurs brutes et les hashes restent inchangés.

## Retrouver les données existantes

La base %LOCALAPPDATA%\ACR-Optimal\Experimental\acr-experimental.sqlite3 est ouverte
avec SQLITE_OPEN_READONLY. Aucun import, effacement ou migration depuis la fenêtre.
L'import et la revue restent assurés par le lanceur de stockage existant, qui est
conservé. Cliquer Actualiser après un import/revue. Base absente : aucune création
silencieuse ; Setup Engineer reste utilisable. Base inconnue/incompatible : refus.

Les snapshots existants dans %LOCALAPPDATA%\ACR-Optimal\SetupEngineer\Snapshots
sont chargés automatiquement et conservés. Setup Engineer propose directement
%LOCALAPPDATA%\acr\Saved\SaveGames\CarSetupsDataSaveSlot.sav, sans imposer ce chemin.
Choisir SAV permet une copie ou un autre fichier. Cliquer Lire et conserver
réalise une lecture volontaire et crée un nouveau JSON. Il n'y a pas de watcher
setup ni détection du setup actif. Une modification du menu doit être sauvegardée
DANS LE JEU avant lecture. Aucun SAV n'est écrit par ACR-Optimal.

Dans Setup Engineer, Actualiser historique recharge les nouveaux JSON sans
réajouter les mêmes fichiers. Ouvrir une version JSON permet une version ailleurs.
Pour comparer : A ancien, B nouveau, même voiture, puis Comparer. Écart B-A en
valeur brute ; état Identique/Modifié/Ajouté/Retiré. Unité/plage inconnue reste
explicite. Les identifiants internes des réglages restent inchangés.

## Test simple Windows

1. Fermer les outils. Copier la base SQLite et le dossier Snapshots pour sauvegarde.
2. Lancer Lancer-ACR-Optimal.bat. Vérifier les mêmes effectifs et records :
   notamment 2:17.413 pour les deux tentatives validées de votre premier lot.
3. Passer entre les quatre sections : aucune seconde fenêtre Setup Engineer.
4. Setup Engineer : retrouver alsace 06 et test125 si leurs JSON sont présents.
   Comparer : précharge arrière 115 -> 125, écart +10, autres réglages inchangés.
5. Lire une copie SAV ; passer dans Chronométrage : les effectifs restent identiques.
6. Fermer/relancer : les anciennes versions sont toujours accessibles. Actualiser
   historique deux fois : pas de doublons d'affichage pour un même fichier.
7. Tester Choisir SAV avec une copie ; vérifier l'original inchangé.
8. Un JSON illisible doit apparaître comme tel dans Historique sans cacher les
   autres versions. Ne pas supprimer vos données pour tenter de corriger une erreur.

Les anciens Lancer-Interface.bat et Lancer-Setup-Engineer.bat sont conservés comme
points d'entrée vers LA MÊME application (ce dernier démarre sur Setup Engineer).
La console de consentement reste ouverte pendant la fenêtre, puis peut être fermée.

## Architecture et vérifications

Interface.ps1 : fenêtre et navigation. SetupView.psm1/SetupView.ps1 : UserControl
embarqué avec état isolé dans un module dynamique, sans fenêtre autonome.
SetupEngine.psm1 : moteur inchangé. SetupHistory.psm1 : consultation des JSON,
sans écriture. Aucun nouveau runtime Python ou dépendance native téléchargée.

Tests cloud : syntaxe PowerShell, structure XML (une Window + une UserControl),
chargement de l'historique existant, JSON invalide signalé, hashes des snapshots
intacts ; tests du moteur et du stockage conservés. WPF ne fonctionne pas sous
Linux : navigation, rendu et callbacks doivent encore être testés sur Windows.
Test développeur Windows disponible : tests/verify_windows_setup_view.ps1
avec Root, SavePath vers UNE COPIE et WorkDir neuf, PowerShell x64 STA.

L'[installateur unique](../packaging-windows/README.fr.md) est préparé avec Inno
Setup. Aucun installateur compilé/testé n'est encore fourni. Il conservera les
données utilisateur lors des mises à jour et de la désinstallation.

Correction de compatibilité PowerShell 5.1 : les tableaux JSON des rapports sont
énumérés explicitement avant formatage. Cela évite la conversion Object[] vers
Double observée au lancement. Test verify_json_records.ps1 : erreur initiale
reproduite puis zéro/une/plusieurs lignes testées avec les deux sémantiques de
pipeline ; ce test s'exécute sous PowerShell 7 en reproduisant l'énumération 5.1.
Le lanceur affiche désormais la ligne et la pile d'appel en cas d'erreur.

## Collecte depuis l'application

Chronométrage contient maintenant Démarrer/Arrêter, une confirmation TT, durée
de test (0 = illimitée), noms de processus et indicateurs d'état/dernier événement.
Le moteur de chronométrage ouvre sa propre connexion SQLite transactionnelle ;
la vue conserve sa connexion readonly et s'actualise après un événement.
Le collector ne valide jamais les nouvelles lignes. [Protocole quotidien et
reconnexion](../collecteur-windows/README.fr.md). Setup Engineer est inchangé.
