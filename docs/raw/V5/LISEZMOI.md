Images V5 brutes (Gemini, fond magenta), déposées par le père : visuels du jeu encore dessinés en code
(base du lot 4, objets, icônes, restes V2 des lieux) et ceux de l'étape h2 (barricades abîmées, ferraille).
Pas besoin de les renommer : Claude les reconnaît, les renomme (git mv), range les ratés dans `ecartees/`,
découpe les planches (`planches/`, tools/decoupe_planche.py) et les traite :
`python3 tools/process_assets.py --source docs/raw/V5` (sortie dans images/v3, même manifest).
Planches de références à joindre dans Gemini : `references/planche_lot_<N>.jpg`.

Lots prévus :
1. Base : voiture de survie, 3 épaves, bloc de béton, tourelle (planche de 5 directions), asphalte, infirmerie.
2. Étape h2 et objets : barricade abîmée (2 stades) et effondrée, ferraille, clé à molette (Réparer), boîte de balles, pomme.
3. Icônes des boutons : Soigner, Guérir, Sortir, Pause, Jouer, Réglages, Héros.
4. Lieux (restes V2) : caisses, carton-cachette, porte à cadenas, porte de sortie, muret du parking.

Lot 1 déposé et traité (7 images sur 8 : manque prop_wreck_yellow). La planche de la tourelle est recomposée par
tools/tourelle_v5.py (même pied pour les 5 directions).
