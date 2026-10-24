extends Node
## RÉGLAGES DU JEU : Eliott, c'est ici que tu changes les valeurs !
## Change seulement les nombres après le signe "=".
## Les vitesses sont en pixels par seconde (l'écran fait 1280 pixels de large).

# --- Héros ---
const HEROS_VITESSE := 260.0          # vitesse de déplacement du héros

# --- Joystick ---
const JOYSTICK_ZONE_MORTE := 0.2      # entre 0 et 1 : en dessous, le héros ne bouge pas

# --- Zombie lent (gros et résistant) ---
const ZOMBIE_LENT_VITESSE := 140.0             # vitesse quand il te poursuit
const ZOMBIE_LENT_VITESSE_PATROUILLE := 55.0   # vitesse quand il se promène

# --- Zombie rapide (maigre et fragile) ---
const ZOMBIE_RAPIDE_VITESSE := 210.0
const ZOMBIE_RAPIDE_VITESSE_PATROUILLE := 80.0

# --- Tous les zombies ---
const ZOMBIE_DISTANCE_DETECTION := 350.0   # à cette distance, le zombie te repère
const ZOMBIE_DISTANCE_ABANDON := 600.0     # plus loin que ça, il commence à t'oublier
const ZOMBIE_DELAI_ABANDON := 2.0          # secondes loin de lui avant qu'il abandonne
