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
const BROUILLARD := Color("4c5576")
const BRUME_CLAIRE := Color("7d88ad")    # brume au sol, visible même dans le noir
const OMBRE := Color(0.05, 0.04, 0.09, 0.6)
const NUIT := Color(0.13, 0.13, 0.24)     # assombrit tout le niveau (CanvasModulate)
const VIGNETTE := Color(0.03, 0.02, 0.07, 0.85)   # bords de l'écran assombris
const LUNE := Color("8aa8e0")             # lumière froide qui tombe des fenêtres

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
const ZOMBIE_VUE := Color(0.56, 0.69, 0.54, 0.13)          # cône de vue calme
const ZOMBIE_VUE_ALERTE := Color(0.88, 0.34, 0.42, 0.16)   # cône de vue en poursuite

# Interface
const UI_FOND := Color(0.08, 0.07, 0.13, 0.55)
const UI_BORD := Color("8a93b8")
const UI_TEXTE := Color("e8e4f0")
const COEUR := Color("e0566b")
const SORTIE := Color("7ed38f")            # panneau et lumière de la sortie
