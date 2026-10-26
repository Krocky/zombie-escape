# Lot 4 : les idées d'Eliott (octobre 2026)

Demandes d'Eliott recueillies le 26 octobre 2026. Un bloc = une nouvelle discussion Claude Code, à envoyer dans l'ordre, après validation de l'étape précédente sur la tablette.
Le prompt complet de l'étape suivante est rédigé quand la précédente est validée (il dépend de ce qui a été fait). Les valeurs entre crochets [ ] sont des propositions qu'Eliott peut changer.

Avancement : [ ] L4-a [ ] L4-b [ ] L4-c [ ] L4-d [ ] L4-e [ ] L4-f [ ] L4-g [ ] L4-h [ ] L4-i

Règle commune : ne jamais casser une sauvegarde existante, ne jamais perdre ce que le joueur a déjà construit.

## Vue d'ensemble

| Étape | Contenu | Dépend de |
|---|---|---|
| L4-a | La base devient un parking où l'on marche (corrige le bug des constructions qui flottent), voiture de survie | |
| L4-b | Placement libre des constructions, barricades multiples | a |
| L4-c | Rescapés qui se promènent et remercient | a |
| L4-d | Sauvegarde multi-parties | |
| L4-e | Deux musiques (base / niveaux) | fichier musique d'Eliott |
| L4-f | Potager : fruit bonus de vitesse | a |
| L4-g | Tourelles automatiques et balles | b |
| L4-h | Niveau 4 : défense de la base, ferraille | a, b, c, g |
| L4-i | Niveau 5 : big boss (à préciser avec Eliott) | h |

Ordre changé par rapport à la liste d'Eliott : la base explorable passe en premier, parce que le placement libre et le niveau 4 ont besoin d'un vrai sol sur lequel poser les choses. Faire le placement libre sur l'écran fixe actuel obligerait à le refaire ensuite.

---

## L4-a : la base devient un parking où l'on marche

```
Tu es mon développeur Godot sur "Zombie Escape". Lis d'abord CLAUDE.md en entier (vision, conventions, décisions, journal) et respecte-le, puis docs/lot4-prompts.md (demandes d'Eliott pour tout le lot 4, pour comprendre où on va ; ne fais QUE l'étape a).
Règles pour cette session :
- Commence par `git pull origin main`. Une autre discussion modifie le rendu visuel en parallèle (dessins, palette, docs/reference, docs/raw) : ne modifie pas le dessin des entités existantes sauf si l'étape l'exige ; en cas de conflit, garde leurs changements visuels.
- Travaille et pousse sur main. Si ta session t'impose une branche, pousse aussi sur main en fast-forward (j'autorise).
- Installe Godot 4.4.1 headless et valide : import sans erreur, `tests/lancer.sh` en 1280x800 et 800x1280 (CLAUDE.md, section Tests), plus le nouveau test demandé. Regarde les captures d'écran.
- Toutes les nouvelles valeurs d'équilibrage dans data/reglages.gd (Eliott les modifie) ; si elles se règlent en jeu, ajoute-les dans ParametresJeu.PAGES.
- Paysage et portrait, boutons tactiles >= 100 px.
- Commit à chaque étape fonctionnelle, pousse, vérifie que le build GitHub Actions est vert et que la Release build-N est publiée.
- Mets à jour CLAUDE.md (décisions prises, journal des lots, vision et avancée si elles changent) et coche l'étape dans docs/lot4-prompts.md.
- Point ambigu : prends la solution la plus simple, note-la dans CLAUDE.md, continue. Ne pose une question que si tu es bloqué.
- N'ajoute rien hors de l'étape demandée.
- À la fin : résume en 3 lignes ce que je dois tester à la main sur la tablette.

Lot 4, étape (a) : LA BASE DEVIENT UN PARKING OÙ L'ON MARCHE (demande d'Eliott).
Problème signalé par Eliott : dans la base, les constructions et les tentes des rescapés « volent dans les airs » au lieu d'être posées sur le parking.
1. Diagnostic d'abord : sauvegarde de test avec toutes les constructions et 4 tentes, captures de la base actuelle en paysage et en portrait. Trouve la cause (positions `PLACES` sur le fond `bg_base` recadré, chute du ciel, ancrage des images...) et note-la en 2 lignes dans CLAUDE.md.
2. La base n'est plus un écran fixe : c'est une scène où le héros se déplace, avec la même logique que les lieux (vue isométrique, joystick, caméra qui suit, tri en profondeur, collisions). Réutilise la mécanique des lieux plutôt que de la dupliquer.
- Décor : un grand parking [environ 2400x1600 unités monde], sol d'asphalte avec lignes de places, quelques obstacles (voitures abandonnées ou blocs de béton en dessin de secours si aucune image n'existe), bords fermés. Pas besoin de nouvelles images : images existantes si elles conviennent, sinon dessin en code. La place doit permettre plus tard beaucoup de barricades (étape b) et une attaque de zombies (étape h).
- Éclairé : pas de nuit noire, pas besoin de la lampe torche (réglage [BASE_CLARTE]).
- Aucun zombie. HUD de la base : pas de boutons Frapper, Cacher, Soigner, Guérir, ni d'objectif. Garder l'inventaire, la jauge du remède, le tiroir « Construire », le bouton Réglages.
- Toutes les constructions existantes et les tentes sont posées AU SOL (pieds dans leur emprise), à des emplacements fixes pour l'instant [constructions au centre du camp, tentes groupées dans un coin], avec collision. Le placement libre viendra à l'étape b.
- Une construction faite dans le tiroir apparaît aussitôt à son emplacement. La chute du ciel peut rester, mais elle se termine posée au sol.
- Voiture de survie garée dans le parking : quand le héros est à côté, un bouton « Start » (>= 100 px) apparaît ; il ouvre la Carte. Il remplace le bouton « Partir ». Au retour de mission, le héros réapparaît près de la voiture.
- Sauvegarde : une partie existante (version 7) doit se charger sans rien perdre. Si tu dois changer de version, reprends l'ancienne comme d'habitude.
- L'écran « Remède trouvé ! », les gains du jardin, de l'infirmerie et des rescapés au retour fonctionnent comme avant. Retour Android dans la base : comme avant.
- Adapte les tests qui passent par la base (ceux qui appuient sur « Partir » passent maintenant par la voiture).
- Nouveau test test_aa : déplacement du héros dans la base, aucun zombie, chaque construction et chaque tente a ses pieds au sol dans le parking, voiture -> Start -> Carte, sauvegarde version 7 reprise sans perte.
Hors étape (ne pas faire) : placement libre et nouvelles barricades (b), rescapés qui se promènent (c), sauvegarde multi-parties (d).
```

---

## Étapes suivantes : demandes d'Eliott (prompts à rédiger)

### L4-b : placement libre et barricades
- Le joueur choisit où poser chaque nouvelle construction (aperçu, validation, emplacement refusé s'il chevauche autre chose). Les constructions déjà faites restent en place.
- Beaucoup de barricades à construire sur le parking (chacune avec son coût). [L'effet +1 cœur reste acquis une fois ; les barricades suivantes servent au niveau 4.]
- CLAUDE.md classe « construction libre » en hors périmètre définitif : Eliott la demande maintenant, mettre la vision à jour.

### L4-c : rescapés vivants
- Les rescapés se promènent dans la base.
- Quand le héros passe près d'un rescapé, il le remercie de l'avoir sauvé (bulle).

### L4-d : sauvegarde multi-parties
- Sauvegarde automatique (comme aujourd'hui) et bouton en haut pour forcer la sauvegarde.
- Plusieurs parties, chacune avec un nom.
- Nouvelle partie : « Êtes-vous sûr ? », sauvegarde de la partie en cours, puis création.
- Effacer une partie (avec confirmation).
- La partie actuelle d'Eliott devient la première partie nommée.

### L4-e : musiques
- Musique actuelle pour la base, nouvelle musique (fournie par Eliott) pour les niveaux.

### L4-f : potager
- Un fruit à ramasser dans le potager toutes les 3 h de temps réel, même jeu fermé ; un seul à la fois, pas de cumul.
- Effet : au prochain niveau, le héros court plus vite pendant 10 secondes.
- À relier au jardin existant (lot 3 c).

### L4-g : tourelles
- Construction « tourelle automatique », 4 maximum, placée librement.
- Balles de tourelle à trouver dans les niveaux ; dans la base, le héros recharge une tourelle.
- Une tourelle tire toute seule sur les zombies à portée tant qu'elle a des balles.

### L4-h : niveau 4, défense de la base
- Se joue sur le parking de la base. Zombies par vagues, de plusieurs côtés, les 3 types tirés au hasard.
- Flèches au-dessus du héros : d'où arrive chaque zombie.
- Les barricades bloquent les zombies jusqu'à ce qu'ils les cassent. Ferraille (nouvelle ressource à trouver dans les niveaux) : le héros répare une barricade petit à petit pendant l'attaque.
- Les tourelles chargées tirent.
- Pendant l'attaque, les rescapés restent devant leur tente. Un rescapé attrapé est perdu et retourne dans son lieu d'origine, où il faut aller le sauver à nouveau ; le niveau continue.
- Le héros a ses cœurs comme ailleurs ; plus de cœurs : défaite, on peut recommencer.
- Victoire : tous les zombies tués. Victoire parfaite : tous les rescapés encore là.

### L4-i : niveau 5, big boss
- À préciser avec Eliott.
