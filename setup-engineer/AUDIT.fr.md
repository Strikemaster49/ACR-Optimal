# Faisabilite et reutilisation - ACR Setup Engineer

Depot etudie : https://github.com/ilborga70/ACR---Advanced-Setup-Extractor
HEAD 49916300f8618412be62466b07d95d442c129b4d.
Tag 3.0.0.0 : 63f39ee3dc0b823e0a73fcd3c9b780c58e7bf813.
Audit effectue le 9 octobre 2026. Aucun executable tiers n'a ete lance.

## Licence et sources

HEAD contient README.md et ACRally Advanced Setup Extractor.zip. Le tag contient
README.md et ACR - Advanced Setup Extractor v3.0.zip. Les deux archives contiennent
un EXE, documentation et images ; aucun .ps1/.cs/.py ni licence. Aucun LICENSE,
COPYING ou condition autorisant une reprise de code n'a ete trouve dans ces
arbres/archives. Un depot public n'est pas une autorisation generale de copier
ou redistribuer son logiciel. Demander a l'auteur les sources et une licence
explicite avant toute reprise. Aucun code, EXE, image ni texte de prompt tiers
n'est embarque dans ACR-Optimal. Notre prototype est une implementation propre.

Les EXE des deux archives examinees ont le meme SHA256 :
f6f9cddd87dbf54306a91c1afd7b9b41399e87683216f6951b0b3e687d2460a2.
Cela ne prouve ni leur securite ni leurs fonctionnalites. Les assets de Releases
n'ont pas pu etre interroges via l'API (403 Forbidden) : cet audit porte sur Git
et ses archives, pas sur tous les assets publies separement.

## Ce que la documentation permet d'etablir

Elle decrit une recolte heuristique ASCII/Unicode, des reperes de version et
une separation des setups par positions de chaines. Elle mentionne une GUI
PowerShell compilee via Win-PS2EXE et des exports HTML. Le README de l'archive
annonce pour 3.0 une amelioration des prompts de dynamique vehicule et des liens
vers des plateformes IA. Aucun appel API IA, moteur de recommandation, fonction
d'extraction precise ni validation binaire n'a pu etre audite dans les sources,
car elles ne sont pas publiees dans les artefacts examines.

Les promesses « 100 % », compatibilite universelle ou extraction de donnees
chiffrees ne sont pas demontrees. Une recolte de texte lisible n'est pas un
decryptage. Les unites professionnelles ajoutees aux exports ne prouvent pas
les unites physiques du jeu. La technique conceptuelle de lecture passive est
pertinente ; aucune fonction de leur implementation n'est actuellement reutilisable.

## Preuve independante sur la copie utilisateur

Copie 000001.sav, SHA256
96a7d45d0acd9913eedf982c9658d850b6522d9dc496ec64ed3aa09edfd26771.
Signature GVAS, CarSetupsSaveGameData ; donnees non chiffrees dans les blocs lus.
Deux setups complets, chacun 65 paires FString cle/valeur :
- VWPoloGTIR5, « Sisteron 06 », version 0.6.0.100866,
  indication de speciale MonteCarloS2Sisteron.
- SkodaFabiaRSRally2, « alsace 06 », version 0.6.0.100866,
  indication de speciale Saverne (ne prouve pas Obersteigen ni un sens precis).

Exemples Fabia extraits : bias 0.530000 ; ressorts avant 55000.000000,
arriere 50000.000000 ; ARB avant 7950.000000 et arriere 16750.000000 ; pressions
avant 27.000000 et arriere 28.000000 ; carrossage avant -1.700000.
Il s'agit de VALEURS BRUTES, sans unites/ranges certifies. Les composants nommes
(GearsSets, Discs, LSDRampAngles) restent des enums brutes : pas de choix autorises
inventes. AjusterRing n'est pas assimile automatiquement a la garde au sol.
Toe n'est pas transforme en degres ni interprete en pincement/ouverture.

Format observe : nom du setup + auteur (FString), token de 8 octets, version
FString, voiture FString, indication de speciale FString, 12 octets nuls,
uint32 nombre de parametres, puis paires FString cle/valeur. Le prototype valide
ces bornes, les comptes, les cles uniques et le format des chaines. Ce n'est pas
un parseur GVAS universel ; les headers inconnus sont refuses. Le token n'est
pas interprete comme une date, ni comme une preuve de setup actif.

## Architecture et limites

SetupEngine.psm1 ne depend pas de WPF : lecture, modele, versions JSON,
comparaison, hypotheses de comportement, template de liaison. SetupWindow.ps1
est une vue WPF separable. Le tableau de bord ACR-Optimal ouvre cette vue depuis
son bouton Setup Engineer. Aucune migration de SQLite, aucune ecriture SAV.
Stockage separable dans SetupEngineer, pas dans la base de chronos existante.

Les unites et plages sont null/unknown, avec UnitCandidate distinct pour les
hypotheses. Un catalogue futur devra etre atteste par voiture, version de jeu,
cle et menu (unite, minimum/maximum/pas ou liste discrete + preuve). La valeur
presente dans une sauvegarde n'est pas une preuve de plage autorisee.

Analyse de comportement : ressenti DECLARE + phase + surface + parametres
presents. Six familles de regles conditionnelles : sous-virage, survirage,
freinage, motricite, stabilite et bosses. Aucune inference telemetrique ni cible
numerique non validee. Pas de service IA ni d'envoi de sauvegardes. Une version
IA future devra etre optionnelle, avec donnees verifiees et consentement explicite.

Versions : snapshots independants conserves sans ecrasement ; VersionId est
un hash du contenu logique + contexte, PAS un identifiant du setup actif.
Comparaison B-A par cle, valeurs numeriques et enums, sans melanger les voitures.
Versions de jeu differentes signalees, pas d'equivalence physique garantie.

Liaison : template acr-setup-performance-link-v1, VersionId, CarId, Profile,
AttemptKey, StageId, ConfirmedUsed=false et preuve. Rien n'est automatiquement
relie par heure, dernier fichier, nom de speciale ni meilleur temps. Aucun
setup historique n'est attribue aux 7/8 tentatives existantes. Il faut observer
un setup applique avant une nouvelle tentative, puis verifier l'arrivee/cle
et conserver cette preuve. Le template n'active aucun calcul causal de performance.

## Etapes suivantes

1. Comparer les valeurs brutes avec les menus du jeu pour les deux voitures.
2. Creer et sauvegarder une seconde version ne changeant qu'un reglage connu.
3. Verifier l'extraction et une seule difference attendue (nom/token exclus).
4. Attester les unites et limites sur la version du jeu testee.
5. Tester une lecture live apres sauvegarde volontaire du setup ; une lecture
   automatique du fichier est possible techniquement, mais la sauvegarde du setup
   actuellement applique n'est pas prouvee. Pas de watcher setup ajoute ici.
6. Observer prospectivement setup applique -> tentative -> secteurs confirmes,
   avant tout lien fiable avec les performances. Jamais retroactivement par supposition.
7. Ne considerer une ecriture SAV qu'apres documentation complete, roundtrip et
   validation fiable ; aucun encodeur SAV ni application de recommandations ici.
