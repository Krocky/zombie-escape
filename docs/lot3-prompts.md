# Lot 3 : prompts proposés (après la revue d'octobre 2026)

Propositions issues de `docs/revue.md` (à lire pour le pourquoi). Rien n'est décidé : le père et Eliott choisissent
les étapes et leur ordre. Un prompt = une session Claude Code, comme au lot 2.
Les valeurs entre crochets [ ] sont des propositions : Eliott peut les changer avant de lancer le prompt.
Ordre conseillé : L3-a d'abord (il protège la sauvegarde), puis L3-b ; les autres dans l'ordre voulu.

---

## Prompt commun (à coller au début de chaque étape)

Le même que celui du lot 2 (`docs/lot2-prompts.md`, section « Prompt commun »), en remplaçant « Lot 2 » par « Lot 3 ».

---

## Étape L3-a : robustesse (pause, retour Android, sauvegarde sûre)

```
Lot 3, étape (a) : ROBUSTESSE. Lis docs/revue.md, section 2.2 (bugs B1 à B10).
- Geste / bouton « retour » d'Android : il ne doit plus quitter le jeu (application/config/quit_on_go_back=false).
  Dans un lieu : il ouvre la pause. Sur la carte, la base, les réglages, le choix du héros : écran précédent. Sur le titre : rien.
- Bouton Pause dans le HUD (rond >= 100 px, [en haut au centre, sous l'objectif]) : jeu figé (zombies, héros, sons), fond assombri,
  boutons « Reprendre » et « Retour à la base ». Retour à la base pendant une mission = [défaite normale : moitié des objets perdus].
- Sauvegardes (Partie et ParametresJeu) : écrire dans un fichier .tmp puis le renommer ; à la lecture, reprendre le .tmp si le fichier principal est illisible.
- Corriger B4 (chutes perdues quand l'écran « Remède trouvé ! » s'ouvre), B5 (zombie bloqué en RETOUR ou PATROUILLE : au bout de [1 s] sans avancer, il prend sa place actuelle comme nouveau départ), B6 (recul annulé en se cachant), B7 (AFFICHER_IPS = false).
- GitHub Actions : lancer tests/lancer.sh en 1280x800 dans le workflow, après l'export ; un test qui affiche « ECHEC » ou une erreur de script fait échouer le build.
- Un test test_t (pause, retour, sauvegarde reprise depuis le .tmp).
```

## Étape L3-b : un combat qui fait peur, une menace qu'on comprend

```
Lot 3, étape (b) : COMBAT et LISIBILITÉ. Aujourd'hui, frapper dès que la batte est prête bat n'importe quel zombie seul sans perdre de cœur (docs/revue.md, 3.1). Il faut que fuir et se cacher redeviennent utiles, sans rendre le jeu dur pour un enfant.
- Le gros zombie a une « garde » : il n'est sonné et repoussé qu'[un coup sur deux] (les autres coups font des dégâts avec un flash, sans l'arrêter).
- Avant de frapper, un zombie lève les bras [0,3 s] (pose ou dessin qui le montre) : on peut esquiver en reculant. Le coup part seulement à la fin de ce geste, s'il est encore au contact.
- Ondes de bruit visibles : un cercle clair qui s'agrandit jusqu'à la portée du bruit (pas et coups de batte), sur le calque sans ombre, discret pour les pas, plus fort pour la batte.
- Cônes de vue visibles dans la nuit : contour du cône sur un calque non assombri (jaune pâle en patrouille, rouge en poursuite), remplissage léger.
- Toutes les nouvelles valeurs dans data/reglages.gd et dans la page Zombies de l'écran Réglages.
- Refaire la mesure : héros immobile qui frappe dès que possible contre chaque zombie seul ; attendu : [au moins 1 cœur perdu contre le gros], 0 contre le coureur.
- Un test test_u (garde du gros, préparation du coup, esquive possible, ondes émises).
```

## Étape L3-c : des objets qui servent

```
Lot 3, étape (c) : OBJETS UTILES et nouvelles constructions.
- Soin pendant la mission : bouton rond « Soigner » (icône cœur + bandage) dans le HUD, actif seulement si le héros est blessé et a ramassé un bandage dans cette mission.
  Un appui : +[1] cœur, le bandage est consommé (il ne compte plus dans les objets rapportés ni dans l'objectif). [1] soin par mission au plus.
- 2 nouvelles constructions (même système de cartes que les 3 existantes) :
  - [Infirmerie] : coûte [3 bandages] -> on commence chaque mission avec [1 bandage] de soin.
  - [Jardin] (image base_garden et place PLACES.jardin déjà prêtes) : coûte [2 eau + 1 conserve] -> [1 conserve] offerte à chaque retour de mission.
- Coûts et effets dans data/reglages.gd. Le tiroir de la base doit garder ses 5 cartes lisibles en paysage et en portrait.
- Un test test_v (soin, consommation, constructions).
```

## Étape L3-d : des lieux qui changent à chaque partie

```
Lot 3, étape (d) : VARIÉTÉ. Les objets et le rescapé sont toujours aux mêmes endroits ; on veut qu'une partie ne ressemble pas à la précédente.
- Chaque objet d'un lieu peut avoir [2 ou 3] places possibles (marqueurs dans la scène du lieu, en coordonnées monde, hors des obstacles) ; une place est tirée au hasard à chaque partie.
- Même chose pour le rescapé ([2] cachettes possibles par lieu) et pour la patrouille de [1] zombie par lieu.
- Le sol, les murs et la sortie ne bougent pas. La fiche de la carte (Partie.infos_lieu) doit toujours compter les bons objets.
- Un test test_w (deux parties de suite : au moins un objet a changé de place ; jamais dans un mur).
```

## Étape L3-e : étoiles retenues et rescapés qui travaillent

```
Lot 3, étape (e) : MOTIVATION.
- Meilleur nombre d'étoiles retenu par lieu (sauvegarde version 7, reprise de la version 6 sans étoiles) : affiché sous la vignette du lieu sur la carte et dans sa fiche (3 étoiles, grises si pas encore gagnées).
- Rescapés au travail : chaque rescapé sauvé rapporte [1] objet au hasard (jamais de fiole) à chaque retour à la base. L'écran de fin l'annonce (« Tes rescapés ont trouvé : ... ») et l'objet rejoint l'inventaire.
- Valeurs dans data/reglages.gd. Un test test_x.
```

## Étape L3-f : la pharmacie et le remède qui guérit

```
Lot 3, étape (f) : 3e LIEU et SUITE DU REMÈDE. (Gros morceau : peut être coupé en deux sessions.)
- La pharmacie devient jouable (vignette map_pharmacy déjà prête) : [1 grande salle + 1 réserve], [1 gros, 1 maigre, 1 coureur], [5] objets, 3 cachettes, un rescapé.
  Objectif : [rapporter 2 piles]. La réserve est fermée par une porte à clef : la clef (type clef, déjà préparé) est dans la salle.
  Attention : la clef ne doit pas compter dans « Objets à trouver » ni dans le compteur du HUD (voir CLAUDE.md, « Clef »).
- Après le remède (jauge pleine) : une fiole ramassée peut être lancée sur un zombie (bouton « Guérir », actif près d'un zombie) ; il s'assoit, redevient humain et compte comme un rescapé sauvé.
  Pas de gore : nuage vert clair, le zombie redevient une silhouette de survivant [image survivor_happy].
- L'objectif du supermarché après le remède devient [guérir 1 zombie].
- Un test test_y.
```
