# 9. Sur un vrai CPC

V-OS n'a été testé que sur des émulateurs : Caprice32, 1984 et CPCEMU. Un vrai CPC peut se comporter autrement avec son lecteur de disquettes, son clavier, son CRTC, son moniteur ou une souris AMX. Ce chapitre est une liste de choses à essayer, avec ce que chacune doit faire. Si quelque chose fait autre chose, dites-le-nous. Même « tout a marché » nous aide.

## Mettre V-OS sur le CPC

La version publiée a deux images de disquette, `vos.dsk` (A:) et `apps.dsk` (B:). Chacune tient sur une disquette 3" (180K). Quelques façons de les utiliser :

- **Un Gotek ou un HxC** à la place d'un lecteur : copiez les fichiers `.dsk` sur sa clé USB.
- **Un lecteur 3,5" de PC** branché sur le CPC comme lecteur B: : écrivez les images sur des disquettes (par exemple avec SAMdisk ou DiskImager sous Windows).
- **Une carte M4 :** copiez les images sur sa carte SD et montez-les depuis son menu.

Ensuite, en BASIC : `RUN"VOS`.

## Ce qu'il faut noter d'abord

- Le modèle (CPC 6128 ou 6128 Plus) et, si vous le connaissez, le type de CRTC (0 à 4).
- L'extension mémoire (aucune, 64K, 512K…), les lecteurs, la souris, une carte M4.
- Le moniteur (CTM644 couleur, GT65 vert, une télé avec un adaptateur…).

## La liste

Chaque ligne : ce qu'il faut faire, et ce que vous devez voir.

**Le démarrage**
- [ ] `RUN"VOS` depuis A:. En quelques secondes : le Bureau, la barre de menus en haut, les icônes des lecteurs à droite. Rien ne scintille ni ne saute.
- [ ] L'image remplit tout l'écran (overscan, 384×272), sans rien de coupé sur les côtés ni en bas.
- [ ] AIDE > À PROPOS DE V-OS montre le numéro de la version publiée.
- [ ] SYSINFO (dans le Lanceur, F2) montre la mémoire que vous avez.

**Le lecteur de disquettes**
- [ ] TAB sur le Bureau ouvre la fenêtre de A:, avec ses fichiers en icônes. Un second TAB : B:.
- [ ] Dans le Commander (F3), copiez un fichier de A: vers B: (^C). Puis quittez V-OS (CONTROL+Q) et, en BASIC, `CAT` sur B: le montre et `LOAD` le lit.
- [ ] Renommez (^N) et supprimez (^D) un fichier sur B:.
- [ ] FORMATER LE DISQUE (DATA) dans le menu FICHIER du Commander, sur une disquette dont vous n'avez pas besoin. Puis `CAT` en BASIC : une disquette vide.
- [ ] Une disquette au format SYSTEM (celui de CP/M) se lit aussi.
- [ ] Réglages (F4) : changez la LANGUE, ^S. Relancez avec `RUN"VOS` : V-OS démarre dans cette langue.
- [ ] Sans disquette en B:, le Commander le dit, et V-OS ne se bloque pas.

**Le clavier**
- [ ] Chaque touche dans NOTEPAD : lettres, chiffres, symboles, SHIFT, CAPS LOCK, les flèches, DEL, CLR, COPY.
- [ ] CONTROL+SHIFT change la langue du clavier (EN, ΕΛ, …, à droite de la barre de menus). Les lettres grecques et accentuées sortent correctement.
- [ ] Une touche tenue se répète à la vitesse de DÉLAI RÉPÉTITION et VITESSE RÉPÉTITION des Réglages.
- [ ] Les touches de fonction : F1 Bureau, F2 Lanceur, F3 Commander, F4 Réglages, F6 les programmes en cours.

**La souris AMX**
- [ ] Réglages : SOURIS AMX à OUI. Le pointeur suit la souris à la même vitesse en largeur et en hauteur, en mode 1 (le Bureau) et en mode 0 (le Lanceur).
- [ ] S'il saute ou va dans le mauvais sens, essayez l'autre valeur de LECTURE AMX.
- [ ] Bouton gauche : un clic ; sur le titre d'une fenêtre, il la déplace ; dans le coin en bas à droite, il la redimensionne.

**La mémoire**
- [ ] Sans extension : NOTEPAD et PONG ensemble, F6 pour passer de l'un à l'autre ; STUDIO tourne seul.
- [ ] Avec une extension : quatre programmes à la fois, chacun là où vous l'avez laissé. PAINT avec une grande image. Une image sur le Bureau (Réglages, IMAGE DE FOND).

**L'écran**
- [ ] PAINT et le Lanceur en mode 0 (16 couleurs) : les couleurs sont justes.
- [ ] READER ou NOTEPAD avec une page en mode 2 (80 colonnes) : lisible, aussi sur un moniteur couleur.
- [ ] L'écran mixte de Studio (mode 0 en haut, mode 1 en bas) : la ligne de séparation reste immobile, rien ne scintille.
- [ ] Le thème sombre (Réglages, THÈME).

**Le son**
- [ ] MUSIC joue un morceau ; il continue à jouer pendant que vous allez sur le Bureau et lancez un autre programme.
- [ ] Les jeux (VROUVES, BRICKS, PONG) ont leurs sons.

**La carte M4** (si vous en avez une)
- [ ] TAB sur le Bureau passe de B: à DISK, la carte SD, avec ses dossiers.
- [ ] NOTEPAD enregistre un fichier sur DISK, et le rouvre.
- [ ] La barre de menus montre l'heure de la M4 ; INFOS DU FICHIER d'un fichier sur DISK donne sa date.
- [ ] WEBGET télécharge un fichier ; READER ouvre une page du web.
- [ ] TELNET se connecte à un serveur (un BBS) et montre ce qu'il envoie.

**La vitesse** (combien de temps, montre en main)
- [ ] De `RUN"VOS` jusqu'au Bureau.
- [ ] De F2 jusqu'au Lanceur, et de l'icône d'un programme jusqu'au programme.
- [ ] SHEET : BUDGET.VSH ouvert et calculé.

## Nous le dire

Ouvrez une issue sur <https://github.com/vaspervnp/V-OS-CPC/issues> avec :

- ce que vous avez noté d'abord (le modèle, la mémoire, le moniteur…) ;
- les lignes qui ont fait autre chose, et ce qu'elles ont fait ;
- une photo de l'écran, si quelque chose a l'air faux.
