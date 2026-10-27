extends Node
## Palette unique du jeu, extraite de docs/reference/style-b-supermarche.png.
## Toutes les couleurs du jeu doivent venir d'ici.

# Nuit et décor
const FOND_NUIT := Color("221e33")        # fond, noir bleuté
const CONTOUR := Color("14121e")          # contours épais
const SOL := Color("4a5577")              # carrelage
const SOL_JOINT := Color("3a4462")        # joints du carrelage
const MUR := Color("2a2438")              # murs
const MUR_FACE := Color("211a21")         # face avant des murs
const MUR_COTE := Color("1a1520")         # côté des murs (plus sombre)
const FENETRE := Color("6890c5")          # fenêtre éclairée par la lune
const FENETRE_REFLET := Color("a9c4ea")   # reflet de la lune sur la vitre (murs V3)
const FENETRE_CADRE := Color("4a4258")    # cadre des fenêtres peintes sur les murs V3
const ETAGERE := Color("3b3550")          # étagères métal
const ETAGERE_FACE := Color("2a2540")
const ETAGERE_COTE := Color("221e34")
const ETAGERE_TEINTE := Color(0.78, 0.8, 0.95)   # assombrit le métal clair des images d'étagères
const CAISSE_BOIS := Color("4a3a3e")      # caisses en bois
const CAISSE_BOIS_FACE := Color("3d363e")
const CAISSE_BOIS_COTE := Color("2f292f")
const CARTON := Color("7a6058")           # cartons
const CARTON_FACE := Color("645055")
const CARTON_COTE := Color("4e3f45")
const CONGELATEUR := Color("6a7ca0")      # congélateur
const CONGELATEUR_FACE := Color("4e5c79")
const CONGELATEUR_COTE := Color("3d4862")
const ARMOIRE := Color("6b4e45")          # armoire de la maison (bois)
const ARMOIRE_FACE := Color("54403f")
const ARMOIRE_COTE := Color("3f2d2e")
const LIT_DRAP := Color("b9b4cf")         # matelas et oreiller
const LIT_COUVERTURE := Color("5a6aa0")   # couverture bleue
const BAIGNOIRE := Color("c8cde0")        # émail de la baignoire
const BAIGNOIRE_FACE := Color("9fa5bf")
const BAIGNOIRE_COTE := Color("7f86a3")
const BAIGNOIRE_EAU := Color("2e3a5c")    # fond sombre de la baignoire
const BROUILLARD := Color("4c5576")
const BRUME_CLAIRE := Color("7d88ad")    # brume au sol, visible même dans le noir
const OMBRE := Color(0.05, 0.04, 0.09, 0.6)
const NUIT := Color(0.13, 0.13, 0.24)     # assombrit tout le niveau (CanvasModulate)
const VIGNETTE := Color(0.03, 0.02, 0.07, 0.85)   # bords de l'écran assombris
const LUNE := Color("8aa8e0")             # lumière froide qui tombe des fenêtres
# Ambiance de chaque lieu (Niveau.ambiance) : nuit et faisceau de la lampe. Les nuits gardent à peu près
# la clarté de NUIT (luminance ~0,14) : seule la teinte change, le niveau reste aussi sombre.
const NUIT_MAISON := Color(0.2, 0.13, 0.11)          # nuit chaude, ambrée
const NUIT_SUPERMARCHE := Color(0.09, 0.15, 0.17)    # nuit froide, vert-cyan (néons)
const FAISCEAU_MAISON := Color("ffb84a")             # lampe plus orangée, comme une ampoule
const FAISCEAU_SUPERMARCHE := Color("fff0a0")        # lampe plus blanche sous les néons
const NEON := Color("b8f5e0")                        # tube néon qui grésille (supermarché)
const NEON_PHARMACIE := Color("3dff7a")              # croix verte lumineuse de la pharmacie
## Images V3 bien plus claires que les V2 (sol blanc, mur carrelé...) : leurs couleurs sont multipliées par
## ce facteur au chargement, pour que la nuit reste aussi sombre qu'avec les dalles et murs V2.
const CLARTE_V3 := {
	"floor_market_tiles": 0.4,
	"floor_house_wood": 0.7,
	"floor_house_kitchen": 0.55,
	"wall_market": 0.45,
	"wall_house": 0.65,
	"prop_freezer": 0.75,
	"prop_checkout_2c": 0.8,
	"floor_pharmacy": 0.4,
	"wall_pharmacy": 0.45,
	"prop_pharmacy_counter_2c": 0.75,
	"prop_pharmacy_shelf_2c": 0.75,
	"prop_medical_cabinet": 0.75,
	"prop_pharmacy_display": 0.8,
}
## ambiance -> [nuit, faisceau]
const AMBIANCES := {
	"maison": [NUIT_MAISON, FAISCEAU_MAISON],
	"supermarche": [NUIT_SUPERMARCHE, FAISCEAU_SUPERMARCHE],
}

# Lampe torche
const LAMPE := Color("f8e989")
const LAMPE_DOUCE := Color("d7c884")
const LAMPE_FAISCEAU := Color("ffcc4a")   # couleur de la lumière de la lampe (plus saturée : la lumière s'additionne)

# Héros
const HEROS_VESTE := Color("2e2838")
const HEROS_JEAN := Color("1c2033")
const HEROS_PEAU := Color("e3b48c")
const HEROS_CHEVEUX := Color("3a2a26")
const HEROS_SAC := Color("4a3f52")
const BATTE := Color("b08a5a")

# Zombies
const ZOMBIE_PEAU := Color("8fb08a")
const ZOMBIE_PEAU_OMBRE := Color("718f79")
const ZOMBIE_TSHIRT := Color("5a5266")
const ZOMBIE_PANTALON := Color("2c3044")
const ZOMBIE_YEUX := Color("f2e6a0")
const ZOMBIE_YEUX_LUEUR := Color(0.95, 0.9, 0.4, 0.28)   # halo autour des yeux dans le noir
const GUERISON := Color("b8f5b0")         # nuage vert clair d'un zombie guéri par une fiole (après le remède)
const BOUTON_GUERIR := Color("8fe0c8")    # disque du bouton Guérir
const ZOMBIE_VUE := Color(1.0, 0.94, 0.62, 0.05)           # cône de vue calme (non assombri par la nuit : léger)
const ZOMBIE_VUE_ALERTE := Color(0.95, 0.25, 0.25, 0.08)   # cône de vue en poursuite
const ZOMBIE_VUE_BORD := Color(1.0, 0.94, 0.62, 0.45)      # contour du cône, jaune pâle (patrouille)
const ZOMBIE_VUE_BORD_ALERTE := Color(1.0, 0.28, 0.25, 0.8) # contour du cône, rouge (poursuite)
const ZOMBIE_PREPARATION := Color("ff4a3d")                # « ! » rouge : il lève les bras, il va frapper
const ONDE_BRUIT := Color("e4ecff")                        # onde de bruit (pas, batte) au sol

# Interface
const UI_FOND := Color(0.08, 0.07, 0.13, 0.55)
const UI_BORD := Color("8a93b8")
const UI_TEXTE := Color("e8e4f0")
const UI_BOUTON := Color("3c4670")          # bouton sombre (Cacher), comme les boutons V1
const UI_CADRE := Color(0.1, 0.09, 0.16, 0.85)   # cadres (compteur d'objets)
const BOUTON_FRAPPER := Color("f5c84a")    # disque du bouton Frapper (icône V3 icon_hit)
const BOUTON_CACHER := Color("5f5cb8")     # disque du bouton Cacher (icône V3 icon_hide)
const COEUR := Color("e0566b")
const COEUR_VIDE := Color("3a2433")        # cœur perdu (sombre)
const DEGATS := Color(0.85, 0.08, 0.12, 0.75)   # bords rouges quand le héros est touché
const SORTIE := Color("7ed38f")            # panneau et lumière de la sortie
## Étiquette de la clef (item_key, rouge dans l'image) : teinte -> couleur, pour de futures portes verrouillées
const CLEF := {"rouge": Color("fe4240"), "bleue": Color("3f86ff"), "verte": Color("45cf5a")}

# Base (abri en planches et feu de camp)
const BOIS := Color("6b4e45")              # planches de l'abri
const BOIS_CLAIR := Color("7d5d50")
const BOIS_SOMBRE := Color("3f2d2e")       # bûches, poutres
const TOLE := Color("4c5070")              # toit en tôle
const TERRE := Color("2b2a3c")             # sol de la base, autour du feu
const PIERRE := Color("5d5f78")            # pierres autour du feu
const FEU := Color("f08a3c")               # flammes
const FEU_COEUR := Color("ffd25a")         # cœur des flammes
const FEU_LUEUR := Color(1.0, 0.62, 0.25, 0.16)   # lumière chaude du feu sur le sol
# Parking de la base (lot 4 a), couleurs prises sur bg_base : asphalte, fissures, lignes des places, blocs de béton
const BASE_LUMIERE := Color(0.95, 0.95, 1.0)   # lumière du soir sur la base (CanvasModulate, x Reglages.BASE_CLARTE)
const ASPHALTE := Color("474a5b")
const ASPHALTE_TACHE := Color("3e4150")
const ASPHALTE_FISSURE := Color("33354a")
const LIGNE_PARKING := Color("8a8799")
const BETON := Color("6a6c80")
# Fruit du potager (lot 4 f) : pomme rouge brillante, dessinée en code
const POMME := Color("e2363a")
const POMME_OMBRE := Color("9e1f2e")
const POMME_REFLET := Color(1.0, 0.95, 0.9, 0.85)
const POMME_FEUILLE := Color("5fbf4a")
const POMME_QUEUE := Color("5a3d2e")
const BETON_FACE := Color("54566a")
const BETON_COTE := Color("43455a")
# Voitures (dessinées en code) : carrosseries, vitres, phares ; la voiture de survie est verte et chargée
const VOITURES := {"survie": Color("5f8a5a"), "rouille": Color("8a5a44"), "bleue": Color("4f6390"), "grise": Color("7a7a88")}
const VITRE := Color("2c3a58")
const VITRE_REFLET := Color("7f9cc8")
const PHARE := Color("ffe9a0")
const PNEU := Color("1e1c26")
const BAGAGE := Color("7a5c40")

# Écrans de fin (images V3 bg_victory_* / bg_defeat_*)
const AUBE := [Color("1f2150"), Color("5a3a7a"), Color("c8607e"), Color("f59a62"), Color("ffc27a")]   # ciel d'aube, du haut vers l'horizon
const AUBE_SOLEIL := Color(1.0, 0.82, 0.55, 0.22)   # lueur du soleil levant derrière l'illustration
const SAC := Color("8a6a4e")                # sac en toile où volent les objets rapportés
const SAC_OMBRE := Color("5e4636")
const SAC_CORDE := Color("d0a86a")
const ETOILE_VIDE := Color(0.55, 0.55, 0.65, 0.55)   # étoile pas gagnée (icon_star grisée)
const DEFAITE_NUIT := Color(0.5, 0.5, 0.62)   # assombrit l'illustration de défaite
const SORTIE_PANNEAU := Color("1e5a36")     # fond de l'étiquette SORTIE posée sur le panneau EXIT
