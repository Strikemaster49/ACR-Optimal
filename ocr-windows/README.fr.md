# Détection expérimentale du setup chargé

Ce prototype est intégré à **ACR-Optimal → Setup Engineer → Détection OCR
(expérimentale)**. L'OCR est désactivé par défaut. Il fonctionne localement avec
le moteur OCR de Windows, sans Python, service distant, lecture de mémoire du
jeu, injection, interception de clavier ou écriture SAV. Il ne renseigne aucune
tentative SQLite et ne change ni les snapshots existants ni le collecteur.

## Ce qui est démontré et ce qui reste à tester

Le clip fourni montre successivement une sélection rouge, la confirmation
« Charger le préréglage », puis le titre « CONFIGURATION DE LA VOITURE | GPT ».
Il ne montre pas l'utilisation de « Revenir et appliquer ». Le titre constitue
une indication du **nom chargé**, pas une preuve du setup effectif en course.
Le prototype ne regarde pas la liste rouge ni la fenêtre de confirmation :
**seule une bande du titre passe à l'OCR**. La confirmation de chargement peut
être déclarée par le joueur ; elle n'est pas détectée automatiquement.

Les tests du moteur d'états et de la structure d'intégration passent dans
l'environnement cloud. La capture, le moteur OCR WinRT et les événements WPF
restent à vérifier sous **Windows PowerShell 5.1, Windows 10/11**, sur votre PC.
La voiture n'apparaissant pas dans cette bande, elle doit être confirmée
manuellement. Le titre seul ne permet pas de constater une modification de
réglage non sauvegardée, ni de prouver si « Revenir et appliquer » est nécessaire.

## Lancement et premier essai

1. Télécharger et extraire **tout le dépôt** de la branche `add-windows-diagnostic`.
2. Double-cliquer sur `Lancer-ACR-Optimal.bat`. Lire l'avertissement puis répondre
   `O` pour l'autorisation PowerShell limitée au processus. Aucun droit
   administrateur ni modification permanente de politique de sécurité.
3. Dans Setup Engineer, utiliser « Lire et conserver » pour conserver vos
   versions du fichier `CarSetupsDataSaveSlot.sav`. Cela lit le SAV et écrit
   uniquement des snapshots JSON dans le dossier ACR-Optimal.
4. Ouvrir le sous-onglet OCR, cliquer « Relire les snapshots », sélectionner la
   voiture et confirmer qu'elle correspond à celle du jeu.
5. Activer l'OCR, ouvrir le menu **Configuration de la voiture** dans le jeu.
   Cliquer « Capturer dans 3 secondes » dans ACR-Optimal puis remettre le jeu au
   premier plan. Vérifier l'aperçu : **uniquement le titre**, sans listes ni
   boutons. Ajuster X, Y, largeur et hauteur en pourcentages si nécessaire.
   Les valeurs proposées sont un point de départ, pas une calibration validée.
6. Cette première capture établit une référence : elle ne prouve pas un nouveau
   chargement. Dans le jeu, sélectionner un autre setup et confirmer son
   chargement. Capturer à nouveau le titre après son changement.
7. Si le nom ne change pas (rechargement du même setup), cocher « Je viens de
   confirmer Charger le préréglage » avant cette capture. Cette attestation est
   enregistrée comme **manuelle** et consommée une seule fois.
8. Vérifier nom, voiture et version candidate. L'historique doit contenir une
   seule version distincte correspondant au nom et à la voiture pour la
   correspondance automatique. Plusieurs versions du même nom restent ambiguës.
9. Utiliser « Revenir et appliquer » dans le jeu. Si vous pouvez personnellement
   confirmer les réglages inchangés, cocher les deux attestations puis
   « Déclarer pour la prochaine tentative (manuel) ».

Cette déclaration est conservée comme preuve prospective. Elle **n'associe pas
le setup au prochain chrono** : cette liaison reste désactivée, et aucun ancien
chrono ne reçoit de setup. Une nouvelle observation ou une invalidation annule
la déclaration en mémoire et impose une nouvelle confirmation.

Si le jeu n'est pas au premier plan, la capture est refusée. Si le nom du
processus diffère, renseigner celui constaté dans le Gestionnaire des tâches,
sans `.exe`. Une bande noire ou un OCR incorrect demande une nouvelle capture ;
essayer le jeu en fenêtre sans bordure et vérifier le recadrage, notamment avec
la mise à l'échelle Windows ou plusieurs écrans. Si le moteur OCR local manque,
installer une langue OCR via les paramètres Windows ; aucune dépendance n'est
téléchargée automatiquement par le programme.

## Confirmation manuelle et modification d'un réglage

En cas d'OCR illisible ou de plusieurs versions portant le même nom, choisir
explicitement le snapshot dans la liste puis « Choisir ce snapshot
manuellement ». Confirmer la voiture, l'application et les réglages. Cette
procédure fonctionne aussi avec l'OCR désactivé et est enregistrée comme choix
manuel, sans prétendre avoir détecté un chargement.

Après une modification non sauvegardée, cliquer **« J'ai modifié un réglage —
invalider »**. Un titre inchangé ne rétablit pas la correspondance. Pour repartir,
recharger réellement le setup dans le jeu et attester ce rechargement, ou choisir
explicitement une nouvelle version manuellement et vérifier ses réglages.

À chaque détection donnant une version unique, le prototype relit le SAV en
lecture seule et compare l'identifiant de version observé. Un réglage sauvegardé
ayant changé, un setup absent ou plusieurs versions actuelles invalident la
correspondance. Un SAV illisible est signalé dans le résultat de vérification,
avec confirmation manuelle nécessaire. **Un SAV identique ne prouve pas que
ses valeurs sont celles actuellement appliquées dans le jeu.**

## États et preuves

| État interne | Sens |
| --- | --- |
| `Selectionne` | Référence de titre ou absence de preuve de chargement ; aucune sélection rouge analysée. |
| `ChargeDetecte` | Changement de titre ou chargement déclaré ; version/voiture encore non confirmées. |
| `AppliqueNonConfirme` | Version candidate unique, ou choix manuel ; application effective non établie. |
| `ConfirmePourLaTentative` | Attestation manuelle pour la prochaine tentative, sans liaison SQLite. |
| `CorrespondanceInvalidee` | Modification déclarée, divergence sauvegardée ou erreur ; nouvelle validation requise. |

Les nouvelles preuves se trouvent dans :

```text
%LOCALAPPDATA%\ACR-Optimal\SetupOcrEvidence\<date-identifiant>\
```

Chaque capture conserve le PNG recadré et un JSON : texte OCR brut, nom
normalisé, voiture et origine de sa confirmation, changement de titre,
version candidate, contrôle du SAV et son SHA-256 si lisible, horodatages UTC,
SHA-256 de l'image, état et confiance. Les déclarations et invalidations ont leurs
propres JSON ; une invalidation référence la déclaration en cours lorsqu'elle
existe. Les fichiers sont créés sans écraser les preuves précédentes.

La confiance est **qualitative**, fondée sur les règles (`low`, `medium`,
`manual`, `none`) ; aucune probabilité de reconnaissance n'est inventée.
`AutomaticAssociation` reste toujours faux. Les noms de setups et les captures
restent locaux ; rien n'est transmis automatiquement.

## Protocole de validation Windows

Tester avec un setup sauvegardé identifiable et une seule voiture :

1. **OCR local** : recadrer une capture PNG autour du titre uniquement.
   Double-cliquer `ocr-windows\Tester-OCR-Windows.bat`, accepter le lancement
   temporaire, sélectionner cette image puis saisir le nom attendu. Conserver
   le résultat affiché ; le test échoue si le titre/nom ne correspondent pas.
2. **Sélection seule** : établir un titre de référence, surligner un autre nom
   sans charger. Ne pas cocher l'attestation de chargement. Aucun changement
   vers un setup chargé ne doit être enregistré.
3. **Chargement** : confirmer « Charger le préréglage », revenir au menu avec
   le nouveau titre, capturer. Vérifier le texte et le snapshot candidat.
4. **Application** : noter les valeurs visibles après chargement, utiliser
   « Revenir et appliquer », rouvrir le menu et vérifier les mêmes valeurs.
   Cela documente leur persistance ; cela ne démontre pas à lui seul qu'une
   tentative antérieure utilisait ces valeurs, ni que l'application était
   nécessaire. Garder cette étape dans les attestations tant qu'aucune preuve
   supplémentaire ne permet de l'automatiser.
5. **Modification non sauvegardée** : changer un réglage sans sauver. Comparer
   le titre ; s'il reste identique, utiliser l'invalidation manuelle. La
   déclaration doit être refusée jusqu'à une nouvelle vérification explicite.
6. **Modification sauvegardée** : changer puis sauvegarder le setup sous le même
   nom. Refaire une capture avant de créer le nouveau snapshot. La version
   précédente doit être invalidée par la divergence SAV.
7. **Ambiguïté / voiture** : conserver deux versions du même nom puis tester une
   voiture différente. Aucune version ne doit être choisie automatiquement.
   La voie manuelle doit demander un choix explicite et la bonne voiture.
8. **Arrêt / relancement** : décocher l'OCR pendant le délai de capture, puis
   fermer et relancer l'application. Aucune capture en arrière-plan ni reprise
   automatique d'une déclaration ne doit se produire. Les preuves restent.
9. **Chronométrage** : vérifier que vos tentatives, statuts, meilleurs temps et
   snapshots existants sont inchangés. Ce module n'ouvre jamais SQLite.

Pour partager les résultats, fournir les JSON et les PNG **recadrés** des cas
chargement/application/modification, avec les actions effectuées. Ne pas activer
l'association automatique aux chronos sur la seule base d'un titre reconnu.

## Organisation du code

- `SetupDetection.psm1` : règles testables sans Windows ni OCR.
- `WindowsTitleOcr.psm1` : moteur OCR local WinRT, chargé à la demande.
- `TitleCapture.cs` : capture de la bande du titre du jeu au premier plan.
- `OcrView.ps1` / `OcrView.psm1` : UserControl intégré, état isolé, preuves locales.
- `tests/verify_setup_detection.ps1` : scénarios de validation et refus.
- `tests/verify_windows_title_ocr.ps1` : vérification réelle Windows du moteur OCR
  et de l'intégration inactive ; lancé par le BAT de test.
