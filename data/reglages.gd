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
var BASE_CLARTE := 1.0              # clarté de la base (parking éclairé, pas de lampe) : 1 = normal, 0.5 = plus sombre
var BROUILLARD_OPACITE := 0.05      # 0 = pas de brouillard, 0.1 = brouillard épais
var CAMERA_AVANCE := 70.0          # la caméra regarde en avant du héros (pixels), 0 = centrée sur lui
var AFFICHER_IPS := false           # true = affiche les images par seconde en haut (pour tester la fluidité)
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
var PORTE_PORTEE := 90.0            # distance de la porte à clef pour l'ouvrir (avec la clef)
var SORTIE_PORTEE := 70.0           # distance de la porte pour sortir (victoire)
var VOITURE_PORTEE := 110.0         # distance de la voiture de survie (base) pour voir le bouton Start

# --- Rescapé (un enfant caché dans chaque lieu : touche-le, il te suit jusqu'à la sortie) ---
var RESCAPE_VITESSE := 230.0        # sa vitesse quand il te suit (un peu moins vite que le héros)
var RESCAPE_PORTEE := 60.0          # distance pour le toucher et qu'il te suive
var RESCAPE_DISTANCE := 70.0        # il reste à cette distance derrière toi
var RESCAPE_DISTANCE_MAX := 400.0   # bloqué plus loin que ça : il réapparaît juste derrière toi
var RESCAPE_OBJETS := 1             # objets (au hasard, jamais de fiole) rapportés par chaque rescapé sauvé, à chaque retour

# --- Rescapés dans la base (ils se promènent sur le parking et te remercient) ---
var RESCAPE_BASE_VITESSE := 70.0       # vitesse de promenade (lente)
var RESCAPE_BASE_PAUSE_MIN := 2.0      # arrêt entre deux promenades : au moins (s)
var RESCAPE_BASE_PAUSE_MAX := 5.0      # ... et au plus (s)
var RESCAPE_BASE_PORTEE_MERCI := 120.0 # le héros passe plus près que ça : il s'arrête et te remercie
var RESCAPE_BASE_DUREE_MERCI := 2.5    # durée de la bulle « Merci » (s)
var RESCAPE_BASE_DELAI_MERCI := 20.0   # un même rescapé ne remercie pas plus souvent que ça (s)

# --- Variété des lieux ---
var LIEUX_VARIES := true            # objets, rescapé et un zombie changent de place à chaque partie (places dans la scène du lieu)

# --- Attaque du héros (batte) ---
var ATTAQUE_DEGATS := 1             # cœurs enlevés au zombie à chaque coup
var ATTAQUE_PORTEE := 90.0          # distance à laquelle la batte touche
var ATTAQUE_DELAI := 0.5            # secondes entre deux coups

# --- Constructions de la base (chacune une seule fois, sauf la barricade : jusqu'à BARRICADE_MAX) ---
# Coût : { objet: nombre }. Objets : "conserve", "eau", "bandage", "piles" (pas "fiole" : elle sert au remède).
var BARRICADE_COUT := {"conserve": 2, "eau": 1}
var BARRICADE_COEURS := 1             # cœurs en plus pour le héros (seulement la première barricade)
var BARRICADE_MAX := 20               # barricades au plus dans la base (les suivantes bloqueront les zombies au niveau 4)
var ATELIER_COUT := {"piles": 2, "conserve": 1}
var ATELIER_DEGATS := 1               # dégâts en plus à chaque coup de batte
var LAMPE_RENFORCEE_COUT := {"piles": 2}
var LAMPE_RENFORCEE_PORTEE := 40      # faisceau de la lampe plus long, en pourcentage
var INFIRMERIE_COUT := {"bandage": 3}
var INFIRMERIE_BANDAGES := 1          # bandages de soin donnés au début de chaque mission
var JARDIN_COUT := {"eau": 2, "conserve": 1}
var JARDIN_CONSERVES := 1             # conserves offertes à chaque retour de mission (gagnée ou perdue)

# --- Fruit du potager (le jardin construit fait pousser un fruit, cueilli à la base, mangé au lieu suivant) ---
var FRUIT_DELAI := 10800.0            # secondes entre deux fruits (3 h, en vrai temps, même jeu fermé)
var FRUIT_VITESSE := 1.5              # le héros court 1,5 fois plus vite...
var FRUIT_DUREE := 10.0               # ... pendant 10 secondes, à l'arrivée dans le lieu suivant

# --- Soin pendant la mission (bouton Soigner : un bandage ramassé ou de l'infirmerie -> des cœurs) ---
var SOIN_COEURS := 1                  # cœurs rendus par un bandage
var SOIN_PAR_MISSION := 1             # soins au plus par mission

# --- Missions (objectif de chaque lieu : { objet: nombre } à rapporter en sortant vivant) ---
var SUPERMARCHE_OBJECTIF := {"fiole": 1}
var MAISON_OBJECTIF := {"bandage": 2}
var PHARMACIE_OBJECTIF := {"piles": 2}
var MISSION_BONUS := 1                # objets en plus, au hasard, quand l'objectif est rempli

# --- Remède (jauge de la base) ---
var REMEDE_FIOLES := 3                # fioles à rapporter pour trouver le remède
# Après le remède (jauge pleine) : une fiole ramassée se lance sur un zombie proche (bouton Guérir),
# il redevient humain et compte comme un rescapé sauvé
var GUERIR_PORTEE := 200.0            # distance jusqu'à laquelle on peut lancer la fiole sur un zombie
var SUPERMARCHE_OBJECTIF_REMEDE := {"guerison": 1}   # objectif du supermarché après le remède ("guerison" = zombies à guérir)

# --- Joystick ---
var JOYSTICK_ZONE_MORTE := 0.2      # entre 0 et 1 : en dessous, le héros ne bouge pas

# --- Zombie lent (gros et résistant) ---
var ZOMBIE_LENT_VITESSE := 140.0             # vitesse quand il te poursuit
var ZOMBIE_LENT_VITESSE_PATROUILLE := 55.0   # vitesse quand il se promène
var ZOMBIE_LENT_PV := 5                      # nombre de coups de batte pour le battre
var ZOMBIE_LENT_GARDE := 2                   # garde : sonné et repoussé seulement un coup sur 2 (1 = à chaque coup)
var ZOMBIE_LENT_DEGATS := 1                  # cœurs qu'il t'enlève quand il te touche

# --- Zombie rapide (maigre et fragile) ---
var ZOMBIE_RAPIDE_VITESSE := 210.0
var ZOMBIE_RAPIDE_VITESSE_PATROUILLE := 80.0
var ZOMBIE_RAPIDE_PV := 3
var ZOMBIE_RAPIDE_DEGATS := 1

# --- Zombie coureur (combinaison orange) : il fonce sur toi, puis s'arrête essoufflé ---
# Il ne t'entend pas et ne te sent pas de dos : il te repère seulement dans son cône de vue.
var ZOMBIE_COUREUR_PV := 2                   # coups de batte pour le battre
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
var ZOMBIE_DELAI_BLOQUE := 1.0               # coincé contre le décor (en patrouille ou en rentrant) : il repart d'où il est
var ZOMBIE_PORTEE_CONTACT := 45.0       # distance à laquelle il te touche
var ZOMBIE_DELAI_DEGATS := 1.0          # secondes entre deux coups du même zombie
var ZOMBIE_PREPARATION := 0.3          # secondes où il lève les bras avant de frapper (recule pour esquiver !)
var ZOMBIE_RECUL := 350.0               # force du recul quand tu le frappes
var ZOMBIE_ETOURDI := 0.4               # secondes où il est sonné après un coup
var ZOMBIE_DELAI_CRI := 6.0             # secondes minimum entre deux cris du même zombie

# --- Sons ---
var SONS_VOLUME := -6.0                 # volume en décibels : -6 = moins fort, +6 = plus fort
var MUSIQUE_VOLUME := -14.0             # volume de la musique de fond (plus bas que les bruitages)
