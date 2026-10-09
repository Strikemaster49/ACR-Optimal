# Installateur unique — préparation

ACR-Optimal.iss prépare un installateur Inno Setup 6 pour Windows 10/11 x64,
par utilisateur, sans admin et sans Python. Inno Setup est uniquement nécessaire
sur la machine de construction ; l'utilisateur final n'a pas à l'installer.
Le raccourci ouvre l'unique fenêtre ACR-Optimal via le lanceur avec consentement
PowerShell temporaire. Il ne modifie aucune politique de sécurité permanente.

Sur une machine Windows de construction, installer Inno Setup 6 (version prenant
en charge x64compatible), ouvrir ACR-Optimal.iss et compiler, ou utiliser :

```text
ISCC.exe packaging-windows\ACR-Optimal.iss
```

Le fichier attendu est packaging-windows\build\ACR-Optimal-Setup-0.1.0.exe.
La compilation et l'installation n'ont pas été exécutées dans l'environnement
Linux. Aucun EXE installateur vérifié n'est publié à ce stade.

À vérifier avant distribution : installation sans admin, raccourci, navigation,
lecture de la base/snapshots existants, comparaison de setups, mise à jour puis
désinstallation. L'installateur ne fournit aucun fichier .sqlite3/.sav/snapshot
et ne remplace pas les données dans %LOCALAPPDATA%\ACR-Optimal. La désinstallation
supprime les fichiers installés sous Programs, conserve la base, les rapports,
les snapshots et preuves. Signer et vérifier l'EXE avant diffusion publique.
