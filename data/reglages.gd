extends Node
## RÉGLAGES DU JEU : Eliott, c'est ici que tu changes les valeurs !
## Change seulement les nombres après le signe "=".
## Les vitesses sont en pixels par seconde (l'écran fait 1280 pixels de large).

# --- Héros ---
const HEROS_VITESSE := 260.0          # vitesse de déplacement du héros
const HEROS_PV := 5                   # nombre de cœurs du héros
const HEROS_INVULNERABLE := 1.0       # secondes où il ne prend plus de coup après avoir été touché
const HEROS_RECUL := 400.0            # force du recul quand un zombie le touche

# --- Lampe torche ---
const LAMPE_PORTEE := 520.0           # longueur du faisceau
const LAMPE_ANGLE := 50.0             # largeur du faisceau, en degrés

# --- Ambiance ---
const NUIT_CLARTE := 1.0              # 1 = normal, 0.5 = deux fois plus sombre, 2 = deux fois plus clair
const BROUILLARD_OPACITE := 0.05      # 0 = pas de brouillard, 0.1 = brouillard épais
const CAMERA_AVANCE := 70.0          # la caméra regarde en avant du héros (pixels), 0 = centrée sur lui
const AFFICHER_IPS := true            # true = affiche les images par seconde en haut (pour tester la fluidité)
const QUALITE_AUTO := true            # true = passe en qualité basse si le jeu rame (moins net, plus fluide)
const QUALITE_SEUIL_IPS := 30         # en dessous de ce nombre d'images par seconde...
const QUALITE_DELAI := 3.0            # ... pendant ces secondes (dans un lieu) : qualité basse
const QUALITE_BASSE_FORCEE := false   # true = toujours en qualité basse (pour comparer sur la tablette)

# --- Bruit (les zombies entendent jusqu'à cette distance) ---
const BRUIT_PAS := 130.0              # bruit des pas quand le héros marche
const BRUIT_ATTAQUE := 450.0          # bruit d'un coup de batte

# --- Cachettes ---
const CACHETTE_PORTEE := 70.0         # distance pour pouvoir se cacher

# --- Objets et sortie ---
const OBJET_PORTEE := 45.0            # distance pour ramasser un objet en marchant dessus
const SORTIE_PORTEE := 70.0           # distance de la porte pour sortir (victoire)

# --- Attaque du héros (batte) ---
const ATTAQUE_DEGATS := 1             # cœurs enlevés au zombie à chaque coup
const ATTAQUE_PORTEE := 90.0          # distance à laquelle la batte touche
const ATTAQUE_DELAI := 0.5            # secondes entre deux coups

# --- Constructions de la base (chacune se construit une seule fois) ---
# Coût : { objet: nombre }. Objets : "conserve", "eau", "bandage", "piles" (pas "fiole" : elle sert au remède).
const BARRICADE_COUT := {"conserve": 2, "eau": 1}
const BARRICADE_COEURS := 1             # cœurs en plus pour le héros
const ATELIER_COUT := {"piles": 2, "conserve": 1}
const ATELIER_DEGATS := 1               # dégâts en plus à chaque coup de batte
const LAMPE_RENFORCEE_COUT := {"piles": 2}
const LAMPE_RENFORCEE_PORTEE := 40      # faisceau de la lampe plus long, en pourcentage

# --- Missions (objectif de chaque lieu : { objet: nombre } à rapporter en sortant vivant) ---
const SUPERMARCHE_OBJECTIF := {"fiole": 1}
const MAISON_OBJECTIF := {"bandage": 2}
const MISSION_BONUS := 1                # objets en plus, au hasard, quand l'objectif est rempli

# --- Remède (jauge de la base) ---
const REMEDE_FIOLES := 3                # fioles à rapporter pour trouver le remède

# --- Joystick ---
const JOYSTICK_ZONE_MORTE := 0.2      # entre 0 et 1 : en dessous, le héros ne bouge pas

# --- Zombie lent (gros et résistant) ---
const ZOMBIE_LENT_VITESSE := 140.0             # vitesse quand il te poursuit
const ZOMBIE_LENT_VITESSE_PATROUILLE := 55.0   # vitesse quand il se promène
const ZOMBIE_LENT_PV := 4                      # nombre de coups de batte pour le battre
const ZOMBIE_LENT_DEGATS := 1                  # cœurs qu'il t'enlève quand il te touche

# --- Zombie rapide (maigre et fragile) ---
const ZOMBIE_RAPIDE_VITESSE := 210.0
const ZOMBIE_RAPIDE_VITESSE_PATROUILLE := 80.0
const ZOMBIE_RAPIDE_PV := 2
const ZOMBIE_RAPIDE_DEGATS := 1

# --- Zombie coureur (combinaison orange) : il fonce sur toi, puis s'arrête essoufflé ---
# Il ne t'entend pas et ne te sent pas de dos : il te repère seulement dans son cône de vue.
const ZOMBIE_COUREUR_PV := 1                   # un seul coup de batte suffit
const ZOMBIE_COUREUR_VITESSE_FOIS := 1.8       # vitesse de charge = 1,8 x la vitesse du zombie lent (ZOMBIE_LENT_VITESSE)
const ZOMBIE_COUREUR_VITESSE_PATROUILLE := 60.0
const ZOMBIE_COUREUR_DEGATS := 1
const ZOMBIE_COUREUR_DUREE_CHARGE := 2.0       # secondes de charge au maximum
const ZOMBIE_COUREUR_ESSOUFFLE := 1.5          # secondes où il s'arrête, essoufflé, après chaque charge

# --- Tous les zombies ---
const ZOMBIE_VUE_DISTANCE := 380.0             # jusqu'où il voit quand il se promène
const ZOMBIE_VUE_DISTANCE_POURSUITE := 600.0   # jusqu'où il voit quand il te poursuit
const ZOMBIE_VUE_ANGLE := 100.0                # largeur du cône de vue, en degrés
const ZOMBIE_DELAI_ABANDON := 2.0              # secondes sans te voir avant de te chercher
const ZOMBIE_DELAI_RECHERCHE := 3.0            # secondes à te chercher avant de repartir
const ZOMBIE_PORTEE_CONTACT := 45.0       # distance à laquelle il te touche
const ZOMBIE_DELAI_DEGATS := 1.0          # secondes entre deux coups du même zombie
const ZOMBIE_RECUL := 350.0               # force du recul quand tu le frappes
const ZOMBIE_ETOURDI := 0.4               # secondes où il est sonné après un coup
const ZOMBIE_DELAI_CRI := 6.0             # secondes minimum entre deux cris du même zombie

# --- Sons ---
const SONS_VOLUME := -6.0                 # volume en décibels : -6 = moins fort, +6 = plus fort
const MUSIQUE_VOLUME := -14.0             # volume de la musique de fond (plus bas que les bruitages)
