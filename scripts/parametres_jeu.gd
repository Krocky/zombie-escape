extends Node
## Réglages modifiables dans le jeu (écran Réglages de la base) : une sélection des valeurs de Reglages.
## Les valeurs de data/reglages.gd restent les valeurs d'origine ; celles changées dans le jeu sont gardées
## dans user://reglages.json ({nom: valeur}, seulement celles qui diffèrent) et remises dans Reglages au démarrage.
## Autoload placé juste après Reglages : les autres autoloads lisent déjà les valeurs changées.

const FICHIER := "user://reglages.json"

## Pages de l'écran : titre, puis réglages [nom dans Reglages, libellé, pas, minimum, maximum].
## pas = 0 : interrupteur oui / non.
const PAGES := [
	["Héros et batte", [
		["HEROS_VITESSE", "Vitesse", 10.0, 100.0, 500.0],
		["HEROS_PV", "Cœurs", 1, 1, 15],
		["HEROS_INVULNERABLE", "Protégé après un coup (s)", 0.1, 0.0, 3.0],
		["ATTAQUE_DEGATS", "Dégâts de la batte", 1, 1, 10],
		["ATTAQUE_PORTEE", "Portée de la batte", 10.0, 40.0, 200.0],
		["ATTAQUE_DELAI", "Temps entre deux coups (s)", 0.1, 0.1, 2.0],
		["SOIN_COEURS", "Cœurs rendus par un bandage", 1, 1, 10],
		["SOIN_PAR_MISSION", "Soins par mission", 1, 0, 10],
	]],
	["Lampe et nuit", [
		["LAMPE_PORTEE", "Longueur du faisceau", 20.0, 200.0, 1200.0],
		["LAMPE_ANGLE", "Largeur du faisceau (°)", 5.0, 20.0, 120.0],
		["NUIT_CLARTE", "Clarté de la nuit", 0.1, 0.3, 3.0],
		["BROUILLARD_OPACITE", "Brouillard", 0.01, 0.0, 0.2],
		["AFFICHER_IPS", "Images par seconde", 0, false, true],
	]],
	["Bruit, cachettes, sons", [
		["BRUIT_PAS", "Bruit des pas", 10.0, 0.0, 400.0],
		["BRUIT_ATTAQUE", "Bruit de la batte", 25.0, 0.0, 1000.0],
		["CACHETTE_PORTEE", "Distance pour se cacher", 10.0, 30.0, 200.0],
		["SONS_VOLUME", "Volume des bruitages (dB)", 2.0, -40.0, 10.0],
		["MUSIQUE_VOLUME", "Volume de la musique (dB)", 2.0, -40.0, 6.0],
	]],
	["Zombies", [
		["ZOMBIE_VUE_DISTANCE", "Distance de vue", 20.0, 100.0, 800.0],
		["ZOMBIE_VUE_ANGLE", "Largeur de vue (°)", 10.0, 30.0, 180.0],
		["ZOMBIE_LENT_VITESSE", "Gros : vitesse", 10.0, 50.0, 400.0],
		["ZOMBIE_LENT_PV", "Gros : coups pour le battre", 1, 1, 20],
		["ZOMBIE_LENT_GARDE", "Gros : sonné un coup sur", 1, 1, 5],
		["ZOMBIE_RAPIDE_VITESSE", "Maigre : vitesse", 10.0, 50.0, 400.0],
		["ZOMBIE_RAPIDE_PV", "Maigre : coups pour le battre", 1, 1, 20],
		["ZOMBIE_PREPARATION", "Bras levés avant le coup (s)", 0.05, 0.0, 1.0],
	]],
	["Zombie coureur", [
		["ZOMBIE_COUREUR_PV", "Coups pour le battre", 1, 1, 20],
		["ZOMBIE_COUREUR_VITESSE_FOIS", "Vitesse (x le gros)", 0.1, 1.0, 3.0],
		["ZOMBIE_COUREUR_DUREE_CHARGE", "Durée de la charge (s)", 0.25, 0.5, 5.0],
		["ZOMBIE_COUREUR_ESSOUFFLE", "Essoufflé pendant (s)", 0.25, 0.0, 5.0],
	]],
	["Rescapé et lieux", [
		["RESCAPE_VITESSE", "Vitesse", 10.0, 50.0, 500.0],
		["RESCAPE_PORTEE", "Distance pour le toucher", 10.0, 30.0, 200.0],
		["RESCAPE_DISTANCE", "Distance derrière le héros", 10.0, 30.0, 300.0],
		["RESCAPE_DISTANCE_MAX", "Réapparaît s'il est bloqué à", 50.0, 150.0, 1500.0],
		["RESCAPE_OBJETS", "Objets trouvés par rescapé", 1, 0, 5],
		["LIEUX_VARIES", "Places qui changent à chaque partie", 0, false, true],
	]],
]

var _origine := {}   # nom -> valeur de data/reglages.gd


func _ready() -> void:
	for page in PAGES:
		for r in page[1]:
			_origine[r[0]] = Reglages.get(r[0])
	charger()


func valeur(nom: String) -> Variant:
	return Reglages.get(nom)


func origine(nom: String) -> Variant:
	return _origine[nom]


func est_change(nom: String) -> bool:
	return valeur(nom) != origine(nom)


## Change un réglage d'un pas (sens = 1 ou -1), ou bascule un interrupteur. Sauvegarde aussitôt.
func changer(reglage: Array, sens: int) -> void:
	var nom: String = reglage[0]
	if is_zero_approx(float(reglage[2])):
		_mettre(nom, not valeur(nom))
	else:
		var v = clamp(valeur(nom) + reglage[2] * sens, reglage[3], reglage[4])
		_mettre(nom, snappedf(v, 0.001) if v is float else int(v))
	sauvegarder()


## Remet les réglages de la page à leurs valeurs d'origine.
func remettre_page(page: int) -> void:
	for r in PAGES[page][1]:
		_mettre(r[0], origine(r[0]))
	sauvegarder()


func _mettre(nom: String, v: Variant) -> void:
	Reglages.set(nom, v)
	if nom == "MUSIQUE_VOLUME":
		Musique.regler_volume()


func sauvegarder() -> void:
	var changes := {}
	for nom in _origine:
		if est_change(nom):
			changes[nom] = valeur(nom)
	Fichier.ecrire_json(FICHIER, changes)   # .tmp puis renommage (écriture sûre)


## Lit les valeurs changées (une valeur inconnue ou hors limites est ignorée ou ramenée dans les limites).
## Fichier illisible : on reprend le .tmp.
func charger() -> void:
	var donnees = Fichier.lire_json(FICHIER)
	if not donnees is Dictionary:
		return
	for page in PAGES:
		for r in page[1]:
			if not donnees.has(r[0]):
				continue
			var v = donnees[r[0]]
			if is_zero_approx(float(r[2])):
				Reglages.set(r[0], bool(v))
			elif _origine[r[0]] is int:
				Reglages.set(r[0], clampi(int(v), r[3], r[4]))
			else:
				Reglages.set(r[0], clampf(float(v), r[3], r[4]))
