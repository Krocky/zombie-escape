extends Node
## RÉGLAGES DU JEU : Eliott, c'est ici que tu changes les valeurs !
## Change seulement les nombres après le signe "=".
## Les vitesses sont en pixels par seconde (l'écran fait 1280 pixels de large).
## Ce sont les valeurs d'origine : une partie d'entre elles se change aussi dans le jeu
## (bouton Réglages de la base, voir scripts/parametres_jeu.gd).

# --- Héros ---
var HEROS_VITESSE := 260.0          # vitesse de déplacement du héros
var HEROS_PV := 5                   # nombre de cœurs du héros
var HEROS_INVULNERABLE := 1.0       # secondes où il ne prend plus de coup après avoir été touché
var HEROS_RECUL := 400.0            # force du recul quand un zombie le touche

# --- Lampe torche ---
var LAMPE_PORTEE := 520.0           # longueur du faisceau
var LAMPE_ANGLE := 50.0             # largeur du faisceau, en degrés

# --- Ambiance ---
var NUIT_CLARTE := 1.0              # 1 = normal, 0.5 = deux fois plus sombre, 2 = deux fois plus clair
var BROUILLARD_OPACITE := 0.05      # 0 = pas de brouillard, 0.1 = brouillard épais
var CAMERA_AVANCE := 70.0          # la caméra regarde en avant du héros (pixels), 0 = centrée sur lui
var AFFICHER_IPS := true            # true = affiche les images par seconde en haut (pour tester la fluidité)
var QUALITE_AUTO := true            # true = passe en qualité basse si le jeu rame (moins net, plus fluide)
var QUALITE_SEUIL_IPS := 30         # en dessous de ce nombre d'images par seconde...
var QUALITE_DELAI := 3.0            # ... pendant ces secondes (dans un lieu) : qualité basse
var QUALITE_BASSE_FORCEE := false   # true = toujours en qualité basse (pour comparer sur la tablette)

# --- Bruit (les zombies entendent jusqu'à cette distance) ---
var BRUIT_PAS := 130.0              # bruit des pas quand le héros marche
var BRUIT_ATTAQUE := 450.0          # bruit d'un coup de batte

# --- Cachettes ---
var CACHETTE_PORTEE := 70.0         # distance pour pouvoir se cacher

# --- Objets et sortie ---
var OBJET_PORTEE := 45.0            # distance pour ramasser un objet en marchant dessus
var SORTIE_PORTEE := 70.0           # distance de la porte pour sortir (victoire)

# --- Attaque du héros (batte) ---
var ATTAQUE_DEGATS := 1             # cœurs enlevés au zombie à chaque coup
var ATTAQUE_PORTEE := 90.0          # distance à laquelle la batte touche
var ATTAQUE_DELAI := 0.5            # secondes entre deux coups

# --- Constructions de la base (chacune se construit une seule fois) ---
# Coût : { objet: nombre }. Objets : "conserve", "eau", "bandage", "piles" (pas "fiole" : elle sert au remède).
var BARRICADE_COUT := {"conserve": 2, "eau": 1}
var BARRICADE_COEURS := 1             # cœurs en plus pour le héros
var ATELIER_COUT := {"piles": 2, "conserve": 1}
var ATELIER_DEGATS := 1               # dégâts en plus à chaque coup de batte
var LAMPE_RENFORCEE_COUT := {"piles": 2}
var LAMPE_RENFORCEE_PORTEE := 40      # faisceau de la lampe plus long, en pourcentage

# --- Missions (objectif de chaque lieu : { objet: nombre } à rapporter en sortant vivant) ---
var SUPERMARCHE_OBJECTIF := {"fiole": 1}
var MAISON_OBJECTIF := {"bandage": 2}
var MISSION_BONUS := 1                # objets en plus, au hasard, quand l'objectif est rempli

# --- Remède (jauge de la base) ---
var REMEDE_FIOLES := 3                # fioles à rapporter pour trouver le remède

# --- Joystick ---
var JOYSTICK_ZONE_MORTE := 0.2      # entre 0 et 1 : en dessous, le héros ne bouge pas

# --- Zombie lent (gros et résistant) ---
var ZOMBIE_LENT_VITESSE := 140.0             # vitesse quand il te poursuit
var ZOMBIE_LENT_VITESSE_PATROUILLE := 55.0   # vitesse quand il se promène
var ZOMBIE_LENT_PV := 4                      # nombre de coups de batte pour le battre
var ZOMBIE_LENT_DEGATS := 1                  # cœurs qu'il t'enlève quand il te touche

# --- Zombie rapide (maigre et fragile) ---
var ZOMBIE_RAPIDE_VITESSE := 210.0
var ZOMBIE_RAPIDE_VITESSE_PATROUILLE := 80.0
var ZOMBIE_RAPIDE_PV := 2
var ZOMBIE_RAPIDE_DEGATS := 1

# --- Zombie coureur (combinaison orange) : il fonce sur toi, puis s'arrête essoufflé ---
# Il ne t'entend pas et ne te sent pas de dos : il te repère seulement dans son cône de vue.
var ZOMBIE_COUREUR_PV := 1                   # un seul coup de batte suffit
var ZOMBIE_COUREUR_VITESSE_FOIS := 1.8       # vitesse de charge = 1,8 x la vitesse du zombie lent (ZOMBIE_LENT_VITESSE)
var ZOMBIE_COUREUR_VITESSE_PATROUILLE := 60.0
var ZOMBIE_COUREUR_DEGATS := 1
var ZOMBIE_COUREUR_DUREE_CHARGE := 2.0       # secondes de charge au maximum
var ZOMBIE_COUREUR_ESSOUFFLE := 1.5          # secondes où il s'arrête, essoufflé, après chaque charge

# --- Tous les zombies ---
var ZOMBIE_VUE_DISTANCE := 380.0             # jusqu'où il voit quand il se promène
var ZOMBIE_VUE_DISTANCE_POURSUITE := 600.0   # jusqu'où il voit quand il te poursuit
var ZOMBIE_VUE_ANGLE := 100.0                # largeur du cône de vue, en degrés
var ZOMBIE_DELAI_ABANDON := 2.0              # secondes sans te voir avant de te chercher
var ZOMBIE_DELAI_RECHERCHE := 3.0            # secondes à te chercher avant de repartir
var ZOMBIE_PORTEE_CONTACT := 45.0       # distance à laquelle il te touche
var ZOMBIE_DELAI_DEGATS := 1.0          # secondes entre deux coups du même zombie
var ZOMBIE_RECUL := 350.0               # force du recul quand tu le frappes
var ZOMBIE_ETOURDI := 0.4               # secondes où il est sonné après un coup
var ZOMBIE_DELAI_CRI := 6.0             # secondes minimum entre deux cris du même zombie

# --- Sons ---
var SONS_VOLUME := -6.0                 # volume en décibels : -6 = moins fort, +6 = plus fort
var MUSIQUE_VOLUME := -14.0             # volume de la musique de fond (plus bas que les bruitages)
