# Candidat de cle de bloc : resultats et test Windows

Les six copies fournies montrent, avant la FString de speciale, huit octets nuls
puis huit octets stables. Deux tokens sont observes pour les blocs Skoda avec
index consecutifs :

| Bloc | BlockToken (octets dans l'ordre du fichier) | Observations |
|---|---|---|
| Anciennes tentatives | e0b868351b25df08 | 2, 3, 4 puis 5 tentatives ; stable apres deplacement du bloc |
| Nouvelles tentatives | 9019ef0e2825df08 | 1 puis 2 tentatives ; index recommencant a zero |

Une interpretation little-endian en ticks de 100 ns depuis l'an 1 produit des
dates plausibles (2026-10-08 09:04:50.030 et 10:36:48.937). Nous ne connaissons
pas la signification ni le fuseau de ce champ : ce ne sont pas des heures d'arrivee
verifiees. Le code utilise les octets bruts, pas une conversion en date.

Cle experimentale : SHA256 du JSON canonique de la liste
[version de cle, BlockToken, StageId, CarId, RunIndex]. Le hash de contenu de la
tentative est SEPARE : deux tentatives reelles avec les memes chronos peuvent
avoir des identites differentes. La cle est pour un meme profil source ; ne pas
fusionner les exports de plusieurs joueurs. Une future base doit ajouter un
namespace de profil et refuser une collision de contenu plutot que la masquer.
Ne pas utiliser BlockOffset ou le hash de tout le fichier : tous deux changent
sans que les tentatives anciennes soient nouvelles.

## Ce qui a ete teste

Les six fichiers reellement fournis donnent 27 observations de tentative,
54 lignes de secteur et 7 cles distinctes : 5 anciennes et 2 nouvelles. Pour
chaque cle observee plusieurs fois, le contenu brut de la tentative est identique.
Les index 0/1 des deux blocs ont des cles differentes. Le deplacement reel de
l'ancien bloc ne change pas ses cles ; un deplacement synthetique supplementaire
de 16 octets ne change pas non plus les cles ni les hashes de contenu.

Un export de test avec une cle existante et un autre hash de contenu produit
content-conflict et un echec explicite du comparateur. Aucun conflit n'est ignore.
Les tests sont dans tests/verify_block_keys.py et ont passe sous PowerShell 7/Linux.
Les sauvegardes personnelles ne sont pas dans Git. Le diagnostic Windows n'a
besoin ni de Python ni d'une installation supplementaire ; Python sert uniquement
aux tests de developpement. La comparaison complete reste a tester sur Windows 5.1.

## Test simple sur votre PC

1. Telecharger la branche mise a jour et extraire tous les fichiers.
2. Lancer Lancer-Lecture-Secteurs.bat sur 000003, 000004, 000005 de la NOUVELLE
   serie. Les sorties s'ajoutent sous %LOCALAPPDATA%\ACR-Optimal\DecodedEvidence.
3. blocs.csv inclut maintenant BlockToken ; secteurs.csv ajoute aussi
   AttemptKeyCandidate et RawAttemptSHA256. Les offsets peuvent changer ; les
   cles des cinq anciennes tentatives doivent rester identiques.
4. Lancer Lancer-Comparaison-Cles.bat. Donner le chemin d'un dossier contenant
   UNIQUEMENT les exports du nouveau lecteur a comparer, pour le meme profil.
   Copier les nouveaux dossiers d'export dans un dossier de test distinct permet
   d'eviter les anciens CSV sans les supprimer. Un ancien export est refuse.
   Copier le chemin complet depuis la barre d'adresse de l'Explorateur ; ne pas
   saisir litteralement %LOCALAPPDATA% dans la question du script.
5. Le comparateur ecrit cles.csv sous %LOCALAPPDATA%\ACR-Optimal\KeyEvidence.
   Sur les trois nouvelles copies : 7 cles distinctes, 0 conflit.
6. Relire encore 000005 avec le lecteur puis refaire la comparaison : toujours
   7 cles distinctes, davantage d'observations des memes cles, aucun nouveau run.

Le comparateur est un outil de preuve et n'importe aucune donnee dans SQLite.
Mode/validite restent unverified. Les roles historique/session active ne sont
pas inferes. L'absence de conflit sur deux blocs ne garantit pas l'unicite
universelle de ce token, ni qu'il reste stable dans tous les resets du jeu.

## Etape suivante et limites

Tester une autre nouvelle session de la meme combinaison, ainsi qu'un abandon,
les penalites et le contexte de mode. Verifier si le token distingue ces sessions
et quels champs codent leur validite. Le nombre de tentatives peut aussi diminuer
ou une ligne peut changer : un conflit doit alors etre examine, pas transforme
automatiquement en nouveau record ou en suppression de l'historique.
Le stockage SQLite pourra accepter les captures en quarantaine avant validation
du mode ; seuls les secteurs explicitement valides alimenteront les records.
La cle definitive et la logique d'import restent conditionnees a ces preuves.
