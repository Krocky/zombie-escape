# Images V5 : prompt de la session Claude Code

Prompt à coller dans une NOUVELLE session Claude Code pour remplacer par des images les visuels du lot 4
encore dessinés en code (voiture, épaves, blocs de béton, tourelle...). Même méthode que les images V4
(voir CLAUDE.md, « Images V4 »).

```
Je veux remplacer par des images Gemini les visuels du jeu encore dessinés en code, surtout ceux ajoutés au lot 4 (voiture de survie, épaves / ferrailles, blocs de béton, tourelle, et tout ce que tu trouveras d'autre). On l'a déjà fait pour les images V4 (lots A à D) : relis la section « Images V4 » de CLAUDE.md, elle contient la méthode et les pièges. Je n'ai pas de PC : je travaille depuis mon téléphone, je ne peux PAS copier un texte depuis un fichier .md de GitHub, seulement depuis tes messages ici.

Étape 1, inventaire (sans rien changer au jeu) :
- git pull origin main, lis CLAUDE.md.
- Liste tous les visuels du jeu dessinés en code qui gagneraient à devenir des images : pour chacun, le fichier et la fonction qui le dessinent, où il apparaît (base, lieux, défense...), son emprise au sol en unités monde et son orientation. Commence par la base du lot 4 (scripts/voiture.gd, Mur.Style.BLOC, scripts/tourelle.gd, scripts/fruit.gd, sol d'asphalte et murets de base.gd...), puis regarde ailleurs (decor_ecran.gd, dessins de secours qui servent encore, etc.).
- Fais des captures du rendu actuel (tests/capture_lieu.gd charge scenes/lieux/<lieu>.tscn : adapte-le ou écris un petit script dans ton scratchpad pour la base, avec une sauvegarde de test où tout est construit) et montre-les-moi.
- Propose une liste triée par effet visuel, en lots de 5 à 10 images au plus, et attends mon accord avant de continuer.

Étape 2, références et prompts Gemini :
- Crée docs/raw/V5/ (avec un LISEZMOI.md) et docs/raw/V5/references/. Pour chaque lot, fabrique UNE planche de références étiquetées R1, R2... (images V3/V4 existantes pour le style, et captures du rendu actuel pour la forme et la taille), envoie-la-moi avec SendUserFile et commite-la. Gemini ne lit PAS les liens GitHub : il invente d'après le nom du fichier. Je joins donc la planche moi-même.
- Donne-moi dans le chat, dans des blocs de code, UN seul message à coller dans une nouvelle conversation Gemini : règles communes (une image par réponse, son code puis attendre « suivant », « refais » pour corriger ; fond magenta pur uni #FF00FF ; style dark cartoon des références ; pas de texte, pas de cadre, rien de coupé ; vue isométrique depuis l'avant-gauche comme les meubles existants), la vérification « décris-moi R1 et R2 avant de commencer », puis la liste des images avec leur nom de fichier final (préfixe prop_, base_, etc. compris par tools/process_assets.py).
- Pièges déjà rencontrés, à prévenir dans le prompt :
  - Meubles : socle de dalles bleu-gris pour mesurer l'emprise, mais pas d'objet de la même couleur que le socle (le fauteuil roulant bleu marine a été effacé avec lui).
  - Gemini écrit parfois du texte sous les dessins, fait des doublons ou mélange deux sujets.
  - Plusieurs poses du même objet (variantes d'épaves, tourelle qui tourne...) : une PLANCHE de poses côte à côte bien séparées, découpée par tools/decoupe_planche.py.
  - Pour une variante d'un objet existant : RETOUCHE de l'image (« garde tout identique, change uniquement... »), plus fidèle que de redessiner.
- Dis-moi ce que je dois vérifier sur chaque image avant d'écrire « suivant ».

Étape 3, intégration (quand je te dis « lot déposé ») :
- Je dépose les images dans docs/raw/V5 SANS les renommer : reconnais-les visuellement, renomme-les (git mv), mets doublons et ratés dans docs/raw/V5/ecartees, puis python3 tools/process_assets.py --source docs/raw/V5 (sortie dans images/v3, même manifest). Montre-moi le résultat détouré sur fond sombre et dis-moi franchement ce qui est raté. Si une image est inutilisable, donne-moi le prompt pour la refaire plutôt que de la mettre quand même.
- Branche les images dans le jeu en gardant le dessin en code comme secours quand l'image manque. Emprise au sol mesurée sur une grille (Images.EMPRISES_V3), clarté de nuit (Palette.CLARTE_V3), tri en profondeur par bandes comme les autres décors. Ne change ni collision, ni emprise, ni gameplay, ni réglage, sauf si je le demande.
- Vérifie avec des captures en jeu, en paysage et en portrait, que tu m'envoies.
- Lance les tests en 1280x800 et 800x1280 (tests/lancer.sh), pas de « ECHEC », d'erreur de script ni de plantage.
- Mets à jour CLAUDE.md (section « Images V5 » sous « Images V4 », journal), git pull origin main avant de pousser (d'autres discussions travaillent en parallèle : garde leurs changements), pousse sur main.
```
