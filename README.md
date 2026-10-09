# ACR-Optimal

Projet Windows de calcul du meilleur temps theorique par secteurs en
contre-la-montre dans Assetto Corsa Rally.

Le [cahier des charges](docs/CAHIER-DES-CHARGES.md) décrit la collecte, le stockage
local et le module avancé d'analyse par secteur. La récupération et la validation
des données restent prioritaires ; les statistiques ne doivent utiliser que des
secteurs réellement récupérés et validés.

Les outils de preuve sont dans [diagnostic-windows](diagnostic-windows/README.fr.md).
Une extraction a été démontrée sur des copies de sauvegarde utilisateur, mais
la fiabilité de la collecte automatique et la validation du mode TT restent à démontrer.

Le [stockage SQLite expérimental](stockage-windows/README.fr.md) importe les
exports sans doublons, conserve les données inconnues en quarantaine et prépare
les statistiques après revue explicite. Il se lance sous Windows sans Python.

L'[interface Windows](interface-windows/README.fr.md) ouvre la base existante en
lecture seule : records, secteurs, progression, comparaison et statuts de validation.
Le [collecteur passif expérimental](collecteur-windows/README.fr.md) surveille une
sauvegarde et importe les captures compatibles en quarantaine. Son protocole doit
encore être vérifié dans le jeu, notamment avant l'ouverture du classement.

Le prototype [ACR Setup Engineer](setup-engineer/README.fr.md) lit les setups
observés, conserve plusieurs versions JSON et compare les réglages. Son
[audit de faisabilité et de licence](setup-engineer/AUDIT.fr.md) explique les
limites du projet tiers, les unités/plages inconnues et l'absence de liaison
historique automatique avec les performances. Aucune écriture SAV.
