# Interface Windows experimentale

Extraire tout le ZIP de la branche add-windows-diagnostic puis double-cliquer
**interface-windows\Lancer-Interface.bat**, accepter O apres l'avertissement.
Windows 10/11 x64 et Windows PowerShell 5.1 : WPF natif, sans Python ni admin.
La base existante %LOCALAPPDATA%\ACR-Optimal\Experimental\acr-experimental.sqlite3
est ouverte avec SQLITE_OPEN_READONLY. Aucun import, changement de statut,
effacement ou migration depuis cette interface. Base absente : message d'erreur,
pas de creation silencieuse. Les rapports sont generes dans InterfaceRapports.

1. Selectionner speciale / voiture / disposition des secteurs.
2. Lire meilleur chrono, optimal et gain total ; seuls les admissibles comptent.
3. Consulter Meilleurs secteurs, classes par gain recuperable decroissant.
4. Tentatives et validation montre toutes les lignes. Selectionner une ligne pour
   voir mode, validite, completude, secteurs verifies, penalite et cle.
5. Progression affiche chrono complet et optimal connu a chaque import, avec
   graphique. L'ordre est celui du premier import, PAS une date d'arrivee prouvee.
6. Comparer deux lignes du meme contexte. Ecart B-A : positif = B plus lente.
   Les lignes en attente peuvent etre examinees mais ne creent aucun record.
7. Actualiser apres import/revue via le lanceur de stockage ou capture experimentale.

Les chronos sont arrondis au millieme (milieu arrondi en s'eloignant de zero),
avec report vers la minute suivante. Gain -0.000010 s s'affiche 0.000 s.
Les floats bruts, les hashes et les exports ne sont jamais arrondis/modifies.
Penalite absente = inconnue, pas zero. Dernier cumul n'est pas un chrono final
confirme pour les lignes incompletes. Les conditions/meteo ne sont pas connues.
Les identifiants internes de speciale/voiture sont affiches pour eviter une
correspondance de noms erronee. Revue : utiliser le lanceur de stockage existant.

Test PC : avec vos donnees, 7 conservees / 2 admissibles (ou 8 si la nouvelle
capture a ete importee), meilleur et optimal 2:17.413, gain 0.000 s. Comparer
les deux admissibles, fermer/rouvrir et verifier les memes effectifs. Verifier
les nouvelles captures via Actualiser. Les graphiques WPF et le double-clic
restent a valider sur Windows ; ils ne peuvent pas etre executes sur Linux.

Tests developpeur : tests/verify_presentation.ps1 couvre arrondi, retenues de
minutes, nombres negatifs, locale et statuts. tests/verify_collector.ps1 verifie
l'ouverture SQLite readonly (UPDATE refuse), generation de rapports et hash
inchange de la base. Syntaxe PowerShell et XML XAML verifiees ; rendu et actions
WPF restent a tester sur Windows. Aucun installateur autonome n'est fourni ici.
