extends Node
## RÉGLAGES DU JEU : Eliott, c'est ici que tu changes les valeurs !
## Change seulement les nombres après le signe "=".
## Les vitesses sont en pixels par seconde (l'écran fait 1280 pixels de large).

# --- Héros ---
const HEROS_VITESSE := 260.0          # vitesse de déplacement du héros
const HEROS_PV := 5                   # nombre de cœurs du héros
const HEROS_INVULNERABLE := 1.0       # secondes où il ne prend plus de coup après avoir été touché
const HEROS_RECUL := 400.0            # force du recul quand un zombie le touche

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
