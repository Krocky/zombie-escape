extends Node
## Résultat de la dernière partie, inventaire et constructions de la base, sauvegardés (user://).
## Retient aussi le lieu choisi sur la carte (pas sauvegardé).
## Sauvegarde version 10 : {"version": 10, "inventaire": {type: nombre}, "constructions": [nom, ...],
## "remede": fioles dans la jauge, "remede_annonce": écran « Remède trouvé ! » déjà vu,
## "skin": héros choisi ("heros" ou "heroine", "" = pas encore choisi), "prenom": prénom du joueur,
## "rescapes": rescapés sauvés, "lieux_sauves": [id, ...] lieux dont le rescapé est sauvé (il n'y réapparaît plus),
## "batiments_vus": [id, ...] bâtiments de la base déjà tombés du ciel (leur chute n'est montrée qu'une fois),
## "etoiles": {id: meilleur nombre d'étoiles (1 à 3) gagné dans ce lieu},
## "poses": [{"nom": construction, "x": .., "y": ..}, ...] constructions posées dans la base (centre de l'emprise,
## dans l'ordre de pose ; une barricade ou une tourelle par entrée),
## "tourelles": [balles, ...] balles de chaque tourelle, dans l'ordre de pose,
## "fruit_cueilli": heure système (secondes) de la dernière cueillette du fruit du potager (0 = jamais),
## "fruit": un fruit cueilli attend le prochain lieu (bool)}.
## Une sauvegarde plus ancienne est reprise telle quelle (ses fioles vont dans la jauge, ses constructions gardent
## leur place de l'étape a du lot 4, PLACES_DEPART, pas de cueillette : le fruit est prêt), puis réécrite en version 10.
## Plusieurs parties (lot 4 d) : une sauvegarde (format ci-dessus) par partie dans DOSSIER (« p1.json », « p2.json »...),
## et un index INDEX = {"version": 1, "en_cours": id, "parties": [{"id": .., "nom": .., "date": secondes unix}, ...]}.
## L'ancienne sauvegarde unique (ANCIEN_FICHIER) est copiée une fois dans SECOURS (jamais écrasée), puis devient la
## première partie ; elle reste sur place, mais n'est plus lue. Les réglages (ParametresJeu) restent communs.

const ANCIEN_FICHIER := "user://sauvegarde.json"
const SECOURS := "user://sauvegarde_avant_lot4d.json"
const DOSSIER := "user://parties/"
const INDEX := "user://parties/index.json"
const NOM_PARTIE_MAX := 20
const VERSION := 10
const NOMS := {
	"conserve": "Conserve",
	"eau": "Bouteille d'eau",
	"bandage": "Bandage",
	"piles": "Piles",
	"fiole": "Fiole de remède",
	"balles": "Boîte de balles",
}
## Objets qu'on ne gagne jamais en bonus de mission ni par les rescapés (la fiole se mérite, les balles
## se trouvent dans les lieux) ; ils n'entrent pas non plus dans les coûts des constructions (Reglages).
const HORS_GAINS := ["fiole", "balles"]
## Pseudo-objet des objectifs « guérir N zombies » (après le remède) : une guérison faite compte comme un « guerison »
## parmi les objets donnés à avancee_objectif.
const GUERISON := "guerison"
## Objets à part, hors inventaire de la base, coûts, objectifs et bonus, jamais rapportés ni comptés dans
## « Objets à trouver » : la clef ouvre la porte (Porte) de même teinte (Palette.CLEF) dans le lieu.
const NOMS_SPECIAUX := {"clef": "Clef"}
## Constructions de la base, dans l'ordre des cartes : nom -> nom affiché (coûts et effets dans Reglages)
const CONSTRUCTIONS := {
	"barricade": "Barricade",
	"atelier": "Atelier",
	"lampe": "Lampe renforcée",
	"infirmerie": "Infirmerie",
	"jardin": "Jardin",
	"tourelle": "Tourelle",
}
## Constructions qui ont un bâtiment dans la base, posé librement par le joueur (pas l'infirmerie).
const BATIMENTS := ["barricade", "atelier", "lampe", "jardin", "tourelle"]
## Place d'origine des constructions de l'étape a (centre de l'emprise, monde), gardée par les anciennes
## sauvegardes : nom -> place (la tourelle, venue après, n'en a pas : elle est toujours posée par le joueur).
const PLACES_DEPART := {
	"barricade": Vector2(1560, 1120),
	"atelier": Vector2(1600, 680),
	"lampe": Vector2(870, 1060),
	"jardin": Vector2(1250, 420),
}
## Héros au choix (écran « Choisis ton héros ») : skin -> nom affiché. Images : images/v3/<skin>_<pose>.png
const SKINS := {"heros": "Garçon", "heroine": "Fille"}
const PRENOM_MAX := 12

## Lieux de la carte, dans l'ordre : id -> nom, « sortir de... » (écran de fin), scène.
## Sans scène, le lieu est affiché « Bientôt » sur la carte.
const LIEUX := {
	"supermarche": {"nom": "Supermarché", "du": "du supermarché", "scene": "res://scenes/lieux/supermarche.tscn"},
	"maison": {"nom": "Maison", "du": "de la maison", "scene": "res://scenes/lieux/maison.tscn"},
	"pharmacie": {"nom": "Pharmacie", "du": "de la pharmacie", "scene": "res://scenes/lieux/pharmacie.tscn"},
	"defense": {"nom": "Défense de la base", "du": "de la base", "scene": "res://scenes/lieux/defense.tscn"},
}
## Niveau 4 : la défense de la base (vagues de zombies sur le parking). Disponible avec Reglages.DEFENSE_RESCAPES
## rescapés à la base ; pas d'objet à trouver, l'objectif est de battre toutes les vagues.
const DEFENSE := "defense"

## Lieu choisi sur la carte (clé de LIEUX)
var lieu := "supermarche"
## Dernier tirage des places de chaque lieu (lieu -> liste d'indices, en mémoire seulement) : la partie
## suivante dans ce lieu en tire un autre (Niveau._tirer_places).
var derniers_tirages := {}
## Objets rangés à la base, cumulés sur toutes les parties : { type: nombre }
var inventaire := {}
## Constructions faites à la base (noms, voir CONSTRUCTIONS ; une seule fois chacun, même avec plusieurs barricades)
var constructions := []
## Constructions posées dans la base, dans l'ordre : [nom, centre de l'emprise (monde)] ; une entrée par barricade
## ou par tourelle
var poses := []
## Balles de chaque tourelle (dans l'ordre de pose des tourelles)
var balles_tourelles := []
## Fioles versées dans la jauge du remède (au plus Reglages.REMEDE_FIOLES)
var remede := 0
## Vrai quand l'écran « Remède trouvé ! » a été montré (une seule fois)
var remede_annonce := false
## Héros choisi (clé de SKINS), "" tant que le joueur n'a pas choisi
var skin := ""
## Prénom du joueur ("" s'il n'en a pas mis)
var prenom := ""
## Rescapés sauvés en tout, et lieux dont le rescapé est sauvé (clés de LIEUX)
var rescapes := 0
var lieux_sauves := []
## Bâtiments de la base déjà apparus (ids de Base : "abri_1", "feu", "tente_1"...), pour ne montrer leur chute qu'une fois
var batiments_vus := []
## Meilleur nombre d'étoiles gagné dans chaque lieu : { id: 1 à 3 } (lieu absent = pas encore d'étoile)
var etoiles_lieux := {}
## Fruit du potager : heure système (secondes) de la dernière cueillette (0 = jamais : le premier fruit est prêt dès
## que le jardin est construit), et fruit cueilli gardé pour le prochain lieu (un seul)
var fruit_cueilli := 0.0
var fruit := false
## Dernière partie : victoire (bool), rapportes (Array), perdus (Array),
## mission (objectif rempli, bool), bonus (Array), fioles (versées dans la jauge, int), rescape (sauvé, bool),
## intact (aucun cœur perdu, bool), jardin (objets offerts par le jardin au retour, Array),
## trouvailles (objets rapportés par les rescapés de la base, Array), gueris (zombies guéris avec une fiole, int),
## defense (c'était la défense de la base, bool), emportes (rescapés emportés par les zombies pendant la défense, int)
var resultat := {"victoire": false, "rapportes": [], "perdus": [], "mission": false, "bonus": [], "fioles": 0, "rescape": false,
	"intact": false, "jardin": [], "trouvailles": [], "gueris": 0, "defense": false, "emportes": 0}


## Parties sauvegardées, dans l'ordre de création : [{"id": "p1", "nom": .., "date": secondes unix}, ...]
var parties := []
## Id de la partie en cours (celle que le jeu lit et sauvegarde)
var en_cours := ""


## L'index est lu dès la création (les tests touchent au fichier de la partie en cours avant le _ready).
func _init() -> void:
	_preparer_parties()


func _ready() -> void:
	charger()


## Sauvegarde aussi quand l'application passe en arrière-plan ou se ferme.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if en_cours != "":
			sauvegarder()


## Appelé par le niveau à la fin. En cas de défaite, on perd la moitié des objets (au hasard, arrondi en dessous).
## rescape : le rescapé du lieu suivait le héros à la sortie ; intact : le héros n'a perdu aucun cœur ;
## gueris : zombies guéris avec une fiole (chacun compte comme un rescapé sauvé, même en cas de défaite) ;
## emportes : défense de la base, numéros des tentes (0 = la première) dont le rescapé a été emporté (emporter_rescapes).
## Défense : la victoire vaut une mission réussie (Reglages.DEFENSE_BONUS objets en bonus).
func terminer(victoire: bool, ramasses: Array, rescape := false, intact := false, gueris := 0, emportes := []) -> void:
	var defense := lieu == DEFENSE
	var rapportes := ramasses.duplicate()
	var perdus := []
	if not victoire:
		rapportes.shuffle()
		for i in rapportes.size() / 2:
			perdus.append(rapportes.pop_back())
	# Objectif rempli en sortant vivant : bonus d'objets au hasard (jamais de fiole, elle se mérite)
	var mission := victoire and (defense or objectif_rempli(lieu, rapportes + avec_guerisons([], gueris)))
	var types := NOMS.keys().filter(func(t: String) -> bool: return not t in HORS_GAINS)
	var bonus := []
	if mission:
		for i in (Reglages.DEFENSE_BONUS if defense else Reglages.MISSION_BONUS):
			bonus.append(types.pick_random())
	# Rescapés au travail : chacun de ceux qui étaient déjà à la base rapporte des objets (jamais de fiole), à chaque retour
	var trouvailles := []
	for i in rescapes * Reglages.RESCAPE_OBJETS:
		trouvailles.append(types.pick_random())
	# Jardin construit : des conserves à chaque retour, mission gagnée ou perdue
	var jardin := []
	if est_construit("jardin"):
		for i in Reglages.JARDIN_CONSERVES:
			jardin.append("conserve")
	for type in rapportes + bonus + jardin + trouvailles:
		inventaire[type] = inventaire.get(type, 0) + 1
	var sauve := victoire and rescape and not rescape_sauve(lieu)
	if sauve:
		rescapes += 1
		lieux_sauves.append(lieu)
	emporter_rescapes(emportes)
	rescapes += gueris
	resultat = {"victoire": victoire, "rapportes": rapportes, "perdus": perdus, "mission": mission, "bonus": bonus,
		"fioles": _remplir_remede(), "rescape": sauve, "intact": intact,
		"jardin": jardin, "trouvailles": trouvailles, "gueris": gueris, "defense": defense, "emportes": emportes.size()}
	# Meilleur nombre d'étoiles du lieu (gardé s'il n'est pas battu)
	if etoiles() > meilleures_etoiles(lieu):
		etoiles_lieux[lieu] = etoiles()
	sauvegarder()


## Rescapés emportés pendant la défense de la base : tentes[i] = numéro de la tente (0 = la première ; ordre de
## persos_base : ceux des lieux sauvés, puis les zombies guéris). Il n'est plus à la base : son lieu redevient
## « rescapé à sauver » ; un zombie guéri emporté est simplement perdu. Les tentes en trop retomberont du ciel
## au prochain rescapé.
func emporter_rescapes(tentes: Array) -> void:
	var lieux := []
	for k in tentes:
		if k < lieux_sauves.size():
			lieux.append(lieux_sauves[k])
	for id in lieux:
		lieux_sauves.erase(id)
	for n in tentes.size():
		batiments_vus.erase("tente_%d" % (rescapes - n))
	rescapes = maxi(rescapes - tentes.size(), 0)


## Étoiles de l'écran de victoire (0 à 3) : 1 pour être sorti, +1 objectif rempli, +1 rescapé sauvé (ou zombie guéri)
## ou aucun cœur perdu. Défense de la base : 1 pour la victoire, +1 aucun rescapé emporté, +1 aucun cœur perdu.
func etoiles() -> int:
	if not resultat["victoire"]:
		return 0
	if resultat.get("defense", false):
		return 1 + int(resultat.get("emportes", 0) == 0) + int(resultat.get("intact", false))
	var sauve: bool = resultat.get("rescape", false) or resultat.get("gueris", 0) > 0
	return 1 + int(resultat["mission"]) + int(sauve or resultat.get("intact", false))


## Meilleur nombre d'étoiles gagné dans un lieu (0 s'il n'a jamais été réussi).
func meilleures_etoiles(id: String) -> int:
	return etoiles_lieux.get(id, 0)


# --- Héros choisi ---

## Skin à dessiner (garçon par défaut tant que le joueur n'a pas choisi).
func perso() -> String:
	return skin if SKINS.has(skin) else "heros"


func choisir_heros(nouveau_skin: String, nouveau_prenom: String) -> void:
	skin = nouveau_skin if SKINS.has(nouveau_skin) else "heros"
	prenom = nouveau_prenom.strip_edges().left(PRENOM_MAX)
	sauvegarder()


## Accord selon le héros : accord("sorti", "sortie").
func accord(masculin: String, feminin: String) -> String:
	return feminin if perso() == "heroine" else masculin


func nom(type: String) -> String:
	return NOMS.get(type, NOMS_SPECIAUX.get(type, type))


# --- Lieux ---

var _infos_lieux := {}


## Le rescapé de ce lieu est-il déjà sauvé ?
func rescape_sauve(id: String) -> bool:
	return id in lieux_sauves


## Personnage (images V3 / V4 « <perso>_hiding / _follow / _happy ») du rescapé de chaque lieu, et de ceux
## qui rejoignent la base autrement (zombies guéris), à tour de rôle. Garçon au chat si l'image manque.
const RESCAPES_LIEUX := {"supermarche": "survivor", "maison": "survivor_girl", "pharmacie": "survivor_nurse"}
const RESCAPES_GUERIS := ["survivor_grandpa", "survivor_teen"]


func perso_rescape(id: String) -> String:
	return _perso_ou_garcon(RESCAPES_LIEUX.get(id, "survivor"))


## Personnage du n-ième zombie guéri (0 = le premier) : grand-père, ado, grand-père...
func perso_gueri(n: int) -> String:
	return _perso_ou_garcon(RESCAPES_GUERIS[posmod(n, RESCAPES_GUERIS.size())])


## Rescapés de la base, dans l'ordre des tentes : ceux des lieux sauvés, puis les zombies guéris.
func persos_base() -> Array:
	var liste := []
	for id in lieux_sauves:
		liste.append(perso_rescape(id))
	for n in maxi(rescapes - liste.size(), 0):
		liste.append(perso_gueri(n))
	return liste


func _perso_ou_garcon(perso: String) -> String:
	return perso if Images.v3_pose(perso, "happy") != "" else "survivor"


## Lieu jouable : il a une scène ; la défense de la base demande en plus des rescapés à défendre.
func lieu_disponible(id: String) -> bool:
	if id == DEFENSE and rescapes < Reglages.DEFENSE_RESCAPES:
		return false
	return LIEUX.has(id) and LIEUX[id]["scene"] != ""


func choisir_lieu(id: String) -> void:
	lieu = id


func scene_lieu() -> String:
	return LIEUX[lieu]["scene"]


## Ce qu'on trouve dans un lieu, lu dans sa scène sans l'instancier (les entités créent leurs nœuds
## d'affichage dès leur création) : {"zombies": [type, ...], "objets": [type, ...], "rescapes": nombre}.
func infos_lieu(id: String) -> Dictionary:
	if not _infos_lieux.has(id):
		var infos := {"zombies": [], "objets": [], "rescapes": 0}
		if lieu_disponible(id):
			var etat: SceneState = load(LIEUX[id]["scene"]).get_state()
			for i in etat.get_node_count():
				var modele := etat.get_node_instance(i)
				if modele == null:
					continue
				if modele.resource_path == "res://scenes/zombie.tscn":
					infos["zombies"].append(_propriete(etat, i, "type", 0))
				elif modele.resource_path == "res://scenes/objet.tscn":
					var type: String = _propriete(etat, i, "type", "conserve")
					if not NOMS_SPECIAUX.has(type):   # la clef n'est pas un objet à trouver
						infos["objets"].append(type)
				elif modele.resource_path == "res://scenes/rescape.tscn":
					infos["rescapes"] += 1
		_infos_lieux[id] = infos
	return _infos_lieux[id]


## Valeur d'une propriété réglée dans la scène, sinon la valeur par défaut.
func _propriete(etat: SceneState, noeud: int, nom_propriete: String, defaut: Variant) -> Variant:
	for k in etat.get_node_property_count(noeud):
		if etat.get_node_property_name(noeud, k) == nom_propriete:
			return etat.get_node_property_value(noeud, k)
	return defaut


# --- Missions ---

## Objets à rapporter dans un lieu : { type: nombre } (GUERISON : zombies à guérir).
## Après le remède, le supermarché ne demande plus de fiole mais de guérir un zombie.
func objectif(id: String) -> Dictionary:
	match id:
		"supermarche":
			return Reglages.SUPERMARCHE_OBJECTIF_REMEDE if remede_trouve() else Reglages.SUPERMARCHE_OBJECTIF
		"maison":
			return Reglages.MAISON_OBJECTIF
		"pharmacie":
			return Reglages.PHARMACIE_OBJECTIF
	return {}


## L'objectif en quelques mots : « rapporter 2 bandages », « guérir 1 zombie ».
func texte_objectif(id: String) -> String:
	var morceaux := []
	var o := objectif(id)
	for type in o:
		if type == GUERISON:
			continue
		var mots := nom(type).to_lower().split(" ")
		if o[type] > 1 and not mots[0].ends_with("s"):
			mots[0] += "s"
		morceaux.append("%d %s" % [o[type], " ".join(mots)])
	var phrases := []
	if o.has(GUERISON):
		phrases.append("guérir %d zombie%s" % [o[GUERISON], "s" if o[GUERISON] > 1 else ""])
	if not morceaux.is_empty():
		phrases.append("rapporter " + " et ".join(morceaux))
	return " et ".join(phrases)


## Objets ramassés + un GUERISON par zombie guéri (pour avancee_objectif et objectif_rempli).
func avec_guerisons(objets: Array, gueris: int) -> Array:
	var liste := objets.duplicate()
	for i in gueris:
		liste.append(GUERISON)
	return liste


func objectif_rempli(id: String, objets: Array) -> bool:
	return avancee_objectif(id, objets) == total_objectif(id) and total_objectif(id) > 0


## Nombre d'objets demandés par l'objectif.
func total_objectif(id: String) -> int:
	var total := 0
	for nombre in objectif(id).values():
		total += nombre
	return total


## Combien d'objets de l'objectif sont parmi « objets » (sans compter ceux en trop).
func avancee_objectif(id: String, objets: Array) -> int:
	var o := objectif(id)
	var avancee := 0
	for type in o:
		avancee += mini(objets.count(type), o[type])
	return avancee


# --- Remède ---

## Verse les fioles de l'inventaire dans la jauge, jusqu'à ce qu'elle soit pleine. Renvoie le nombre versé.
func _remplir_remede() -> int:
	var versees := mini(inventaire.get("fiole", 0), Reglages.REMEDE_FIOLES - remede)
	if versees > 0:
		inventaire["fiole"] -= versees
		remede += versees
	return maxi(versees, 0)


func remede_trouve() -> bool:
	return remede >= Reglages.REMEDE_FIOLES


## Vrai une seule fois : la jauge est pleine et l'écran « Remède trouvé ! » n'a pas encore été vu.
func annoncer_remede() -> bool:
	if not remede_trouve() or remede_annonce:
		return false
	remede_annonce = true
	sauvegarder()
	return true


# --- Constructions ---

## Objets à donner pour construire : { type: nombre }.
func cout(construction: String) -> Dictionary:
	match construction:
		"barricade":
			return Reglages.BARRICADE_COUT
		"atelier":
			return Reglages.ATELIER_COUT
		"lampe":
			return Reglages.LAMPE_RENFORCEE_COUT
		"infirmerie":
			return Reglages.INFIRMERIE_COUT
		"jardin":
			return Reglages.JARDIN_COUT
		"tourelle":
			return Reglages.TOURELLE_COUT
	return {}


## L'effet en une phrase (carte de la base).
func effet(construction: String) -> String:
	match construction:
		"barricade":
			if est_construit("barricade"):
				return "Bloque les zombies"   # seule la première barricade donne des cœurs
			return "+%d cœur%s pour le héros" % [Reglages.BARRICADE_COEURS, "s" if Reglages.BARRICADE_COEURS > 1 else ""]
		"atelier":
			return "La batte fait +%d dégât%s" % [Reglages.ATELIER_DEGATS, "s" if Reglages.ATELIER_DEGATS > 1 else ""]
		"lampe":
			return "Lampe +%d %% plus loin" % Reglages.LAMPE_RENFORCEE_PORTEE
		"infirmerie":
			return "+%d bandage%s par mission" % [Reglages.INFIRMERIE_BANDAGES, "s" if Reglages.INFIRMERIE_BANDAGES > 1 else ""]
		"jardin":
			return "+%d conserve%s à chaque retour" % [Reglages.JARDIN_CONSERVES, "s" if Reglages.JARDIN_CONSERVES > 1 else ""]
		"tourelle":
			return "Tire seule sur les zombies"
	return ""


func est_construit(construction: String) -> bool:
	return construction in constructions


## Combien de fois cette construction est faite (0 ou 1, jusqu'à maximum() pour la barricade et la tourelle).
func nombre_construit(construction: String) -> int:
	if not est_construit(construction):
		return 0
	var n := 0
	for pose in poses:
		n += int(pose[0] == construction)
	return maxi(n, 1)


## Nombre de fois qu'on peut la faire : BARRICADE_MAX pour la barricade, TOURELLE_MAX pour la tourelle, 1 sinon.
func maximum(construction: String) -> int:
	match construction:
		"barricade":
			return Reglages.BARRICADE_MAX
		"tourelle":
			return Reglages.TOURELLE_MAX
	return 1


## Bâtiments des constructions dans la base, dans l'ordre de pose : [nom, centre de l'emprise]. Une construction
## faite sans position (ancienne sauvegarde) est à sa place d'origine (PLACES_DEPART), avant les autres.
func poses_camp() -> Array:
	var liste := []
	for nom_construction in constructions:
		if PLACES_DEPART.has(nom_construction) and not poses.any(func(p: Array) -> bool: return p[0] == nom_construction):
			liste.append([nom_construction, PLACES_DEPART[nom_construction]])
	for pose in poses:
		if est_construit(pose[0]):
			liste.append(pose)
	return liste


func peut_construire(construction: String) -> bool:
	if nombre_construit(construction) >= maximum(construction):
		return false
	var c := cout(construction)
	for type in c:
		if inventaire.get(type, 0) < c[type]:
			return false
	return true


## Retire les objets de l'inventaire, ajoute la construction (posée à `centre` dans la base si elle a un
## bâtiment, sinon à sa place d'origine) et sauvegarde. Faux si impossible.
func construire(construction: String, centre := Vector2.INF) -> bool:
	if not peut_construire(construction):
		return false
	var c := cout(construction)
	for type in c:
		inventaire[type] -= c[type]
	if construction in BATIMENTS:
		poses = poses_camp()   # une construction sans position garde sa place d'origine
		poses.append([construction, centre if centre != Vector2.INF else PLACES_DEPART.get(construction, Vector2.ZERO)])
	if construction == "tourelle":
		balles_tourelles.append(0)   # une tourelle neuve est vide
	if not est_construit(construction):
		constructions.append(construction)
	sauvegarder()
	return true


# --- Tourelles ---

## Nombre de tourelles posées.
func nombre_tourelles() -> int:
	return balles_tourelles.size()


## Recharge la tourelle n° k (ordre de pose) avec les boîtes de balles de l'inventaire, jusqu'à
## Reglages.TOURELLE_CAPACITE : une boîte est ouverte tant qu'il reste de la place (les balles de la dernière
## qui ne rentrent pas sont perdues). Sauvegarde. Renvoie le nombre de boîtes utilisées.
func recharger_tourelle(k: int) -> int:
	if k < 0 or k >= balles_tourelles.size():
		return 0
	var boites := 0
	while balles_tourelles[k] < Reglages.TOURELLE_CAPACITE and inventaire.get("balles", 0) > 0:
		inventaire["balles"] -= 1
		balles_tourelles[k] = mini(balles_tourelles[k] + Reglages.BALLES_PAR_BOITE, Reglages.TOURELLE_CAPACITE)
		boites += 1
	if boites > 0:
		sauvegarder()
	return boites


## Recharger est utile : la tourelle n'est pas pleine et il y a des boîtes de balles.
func peut_recharger(k: int) -> bool:
	return k >= 0 and k < balles_tourelles.size() and balles_tourelles[k] < Reglages.TOURELLE_CAPACITE \
		and inventaire.get("balles", 0) > 0


## Effets des constructions dans le niveau
func heros_pv() -> int:
	return Reglages.HEROS_PV + (Reglages.BARRICADE_COEURS if est_construit("barricade") else 0)


func degats_batte() -> int:
	return Reglages.ATTAQUE_DEGATS + (Reglages.ATELIER_DEGATS if est_construit("atelier") else 0)


## Bandages de soin donnés par l'infirmerie au début de la mission (hors objets ramassés).
func bandages_infirmerie() -> int:
	return Reglages.INFIRMERIE_BANDAGES if est_construit("infirmerie") else 0


func portee_lampe() -> float:
	return Reglages.LAMPE_PORTEE * (1.0 + Reglages.LAMPE_RENFORCEE_PORTEE / 100.0 if est_construit("lampe") else 1.0)


# --- Fruit du potager ---

## Heure système en secondes (les tests peuvent la remplacer en changeant fruit_cueilli).
func maintenant() -> float:
	return Time.get_unix_time_from_system()


## Secondes avant que le prochain fruit soit prêt sur le potager (0 = prêt). Si l'heure de la tablette a reculé
## (avant la dernière cueillette), la cueillette est remise à maintenant : pas de fruit bloqué pour des heures.
func secondes_avant_fruit() -> float:
	var t := maintenant()
	if t < fruit_cueilli:
		fruit_cueilli = t
		sauvegarder()
	return maxf(fruit_cueilli + Reglages.FRUIT_DELAI - t, 0.0)


## Un fruit est sur le potager : jardin construit et délai écoulé depuis la dernière cueillette (pas de cumul).
func fruit_pret() -> bool:
	return est_construit("jardin") and secondes_avant_fruit() <= 0.0


## Cueille le fruit du potager (il attend le prochain lieu) et sauvegarde. Faux s'il n'est pas prêt ou si un
## fruit attend déjà (un seul en réserve).
func cueillir_fruit() -> bool:
	if fruit or not fruit_pret():
		return false
	fruit = true
	fruit_cueilli = maintenant()
	sauvegarder()
	return true


## À l'arrivée dans un lieu : le fruit en réserve est mangé (vrai), même si la mission est perdue ensuite.
func manger_fruit() -> bool:
	if not fruit:
		return false
	fruit = false
	sauvegarder()
	return true


## Vrai la première fois qu'un bâtiment de la base apparaît (il tombe du ciel) ; le retient et sauvegarde.
func premiere_apparition(id: String) -> bool:
	if id in batiments_vus:
		return false
	batiments_vus.append(id)
	sauvegarder()
	return true


## Écriture sûre (Fichier : .tmp puis renommage), l'ancienne sauvegarde reste entière si l'appli est tuée pendant l'écriture.
func sauvegarder() -> void:
	Fichier.ecrire_json(fichier(), {"version": VERSION, "inventaire": inventaire, "constructions": constructions,
		"remede": remede, "remede_annonce": remede_annonce, "skin": skin, "prenom": prenom,
		"rescapes": rescapes, "lieux_sauves": lieux_sauves, "batiments_vus": batiments_vus, "etoiles": etoiles_lieux,
		"poses": poses.map(func(p: Array) -> Dictionary: return {"nom": p[0], "x": p[1].x, "y": p[1].y}),
		"tourelles": balles_tourelles, "fruit_cueilli": fruit_cueilli, "fruit": fruit})
	var entree := _entree(en_cours)
	if not entree.is_empty():
		entree["date"] = int(Time.get_unix_time_from_system())
		_ecrire_index()


## Lit la sauvegarde de la partie en cours (version 1 à 10), par-dessus ce qui est en mémoire (vide au démarrage ;
## charger_partie vide d'abord). Une version plus ancienne est aussitôt réécrite en version 10
## (les fioles déjà rangées remplissent la jauge du remède, les constructions restent à leur place d'origine).
## Fichier illisible : on reprend le .tmp.
func charger() -> void:
	var donnees = Fichier.lire_json(fichier())
	if not donnees is Dictionary:
		return
	if donnees.get("inventaire") is Dictionary:
		for type in donnees["inventaire"]:
			inventaire[type] = int(donnees["inventaire"][type])
	if donnees.get("constructions") is Array:
		for nom_construction in donnees["constructions"]:
			if not nom_construction in constructions:
				constructions.append(str(nom_construction))
	remede = int(donnees.get("remede", 0))
	remede_annonce = bool(donnees.get("remede_annonce", false))
	skin = str(donnees.get("skin", ""))
	if not SKINS.has(skin):
		skin = ""
	prenom = str(donnees.get("prenom", "")).left(PRENOM_MAX)
	rescapes = int(donnees.get("rescapes", 0))
	if donnees.get("lieux_sauves") is Array:
		for id in donnees["lieux_sauves"]:
			if not str(id) in lieux_sauves:
				lieux_sauves.append(str(id))
	if donnees.get("batiments_vus") is Array:
		for id in donnees["batiments_vus"]:
			if not str(id) in batiments_vus:
				batiments_vus.append(str(id))
	if donnees.get("etoiles") is Dictionary:
		for id in donnees["etoiles"]:
			etoiles_lieux[str(id)] = clampi(int(donnees["etoiles"][id]), 0, 3)
	poses = []
	if donnees.get("poses") is Array:
		for pose in donnees["poses"]:
			if pose is Dictionary and str(pose.get("nom", "")) in BATIMENTS:
				poses.append([str(pose["nom"]), Vector2(float(pose.get("x", 0.0)), float(pose.get("y", 0.0)))])
	# Balles des tourelles : une valeur par tourelle posée (0 si elle manque, avant la version 9)
	balles_tourelles = []
	var balles: Array = donnees["tourelles"] if donnees.get("tourelles") is Array else []
	for pose in poses:
		if pose[0] == "tourelle":
			var k := balles_tourelles.size()
			balles_tourelles.append(clampi(int(balles[k]) if k < balles.size() else 0, 0, Reglages.TOURELLE_CAPACITE))
	fruit_cueilli = float(donnees.get("fruit_cueilli", 0.0))
	fruit = bool(donnees.get("fruit", false))
	if int(donnees.get("version", 1)) < VERSION:
		poses = poses_camp()
		_remplir_remede()
		sauvegarder()


## Remet une partie vide en mémoire (avant de lire une sauvegarde, ou pour une nouvelle partie).
func _vider() -> void:
	inventaire = {}
	constructions = []
	poses = []
	balles_tourelles = []
	remede = 0
	remede_annonce = false
	skin = ""
	prenom = ""
	rescapes = 0
	lieux_sauves = []
	batiments_vus = []
	etoiles_lieux = {}
	fruit_cueilli = 0.0
	fruit = false
	derniers_tirages = {}
	resultat = {"victoire": false, "rapportes": [], "perdus": [], "mission": false, "bonus": [], "fioles": 0, "rescape": false,
		"intact": false, "jardin": [], "trouvailles": [], "gueris": 0, "defense": false, "emportes": 0}


# --- Plusieurs parties (lot 4 d) ---

## Fichier de la partie en cours.
func fichier() -> String:
	return _fichier_partie(en_cours)


func _fichier_partie(id: String) -> String:
	return DOSSIER + id + ".json"


## Au démarrage : copie de secours de l'ancienne sauvegarde (une seule fois), puis lecture de l'index des parties.
## Sans index lisible : on le refait avec les fichiers de parties déjà là ; s'il n'y en a aucun, l'ancienne
## sauvegarde devient la première partie (« Partie d'Eliott »), sinon une partie vide.
func _preparer_parties() -> void:
	var ancien := ""
	for nom_fichier in [ANCIEN_FICHIER, ANCIEN_FICHIER + Fichier.SUFFIXE]:
		if ancien == "" and FileAccess.file_exists(nom_fichier):
			ancien = FileAccess.get_file_as_string(nom_fichier)
	if ancien != "" and not FileAccess.file_exists(SECOURS):
		var copie := FileAccess.open(SECOURS, FileAccess.WRITE)
		if copie:
			copie.store_string(ancien)
			copie.close()
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	parties = []
	en_cours = ""
	var index = Fichier.lire_json(INDEX)
	if index is Dictionary and index.get("parties") is Array:
		for entree in index["parties"]:
			if entree is Dictionary and str(entree.get("id", "")).is_valid_filename() and str(entree.get("id", "")) != "" \
					and _entree(str(entree["id"])).is_empty():
				parties.append({"id": str(entree["id"]), "nom": str(entree.get("nom", "Partie")).left(NOM_PARTIE_MAX),
					"date": int(entree.get("date", 0))})
		en_cours = str(index.get("en_cours", ""))
	else:
		var trouvees := []
		for nom_fichier in DirAccess.get_files_at(DOSSIER):
			if nom_fichier.begins_with("p") and nom_fichier.ends_with(".json") and nom_fichier.trim_prefix("p").trim_suffix(".json").is_valid_int():
				trouvees.append(int(nom_fichier.trim_prefix("p").trim_suffix(".json")))
		trouvees.sort()
		for n in trouvees:
			parties.append({"id": "p%d" % n, "nom": "Partie %d" % n, "date": int(Time.get_unix_time_from_system())})
		if parties.is_empty():
			var donnees = JSON.parse_string(ancien) if ancien != "" else null
			var nom_partie := "Partie 1"
			if donnees is Dictionary:
				Fichier.ecrire_json(_fichier_partie("p1"), donnees)
				var son_prenom := str(donnees.get("prenom", "")).strip_edges()
				if son_prenom != "":
					nom_partie = ("Partie " + de(son_prenom)).left(NOM_PARTIE_MAX)
			parties.append({"id": "p1", "nom": nom_partie, "date": int(Time.get_unix_time_from_system())})
	if _entree(en_cours).is_empty():
		en_cours = "p1" if parties.is_empty() else parties[0]["id"]
		if parties.is_empty():
			parties.append({"id": "p1", "nom": "Partie 1", "date": int(Time.get_unix_time_from_system())})
	_ecrire_index()


func _ecrire_index() -> void:
	Fichier.ecrire_json(INDEX, {"version": 1, "en_cours": en_cours, "parties": parties})


func _entree(id: String) -> Dictionary:
	for entree in parties:
		if entree["id"] == id:
			return entree
	return {}


## « d'Eliott », « de Paul » (titre de la base, nom de la partie reprise).
func de(son_prenom: String) -> String:
	var voyelle := son_prenom.left(1).to_lower() in ["a", "e", "i", "o", "u", "y", "h", "é", "è", "ê", "à", "â", "î", "ô", "û"]
	return ("d'" if voyelle else "de ") + son_prenom


func nom_partie(id: String) -> String:
	return _entree(id).get("nom", "")


## Nom proposé pour une nouvelle partie : « Partie N » (N = nombre de parties + 1, sans doublon).
func nom_libre() -> String:
	var n := parties.size() + 1
	while parties.any(func(e: Dictionary) -> bool: return e["nom"] == "Partie %d" % n):
		n += 1
	return "Partie %d" % n


## Ce que montre la liste « Mes parties » : nom, date, prénom et skin du héros, rescapés (lus dans son fichier).
func infos_partie(id: String) -> Dictionary:
	var entree := _entree(id)
	var infos := {"nom": entree.get("nom", ""), "date": entree.get("date", 0), "prenom": prenom, "skin": skin, "rescapes": rescapes}
	if id != en_cours:
		var donnees = Fichier.lire_json(_fichier_partie(id))
		donnees = donnees if donnees is Dictionary else {}
		infos["prenom"] = str(donnees.get("prenom", ""))
		infos["skin"] = str(donnees.get("skin", ""))
		infos["rescapes"] = int(donnees.get("rescapes", 0))
	return infos


## Date d'une sauvegarde à l'heure du téléphone : « 27/10/2026 14:05 ».
func texte_date(secondes: int) -> String:
	if secondes <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(secondes + Time.get_time_zone_from_system().get("bias", 0) * 60)
	return "%02d/%02d/%d %02d:%02d" % [d["day"], d["month"], d["year"], d["hour"], d["minute"]]


## Nouvelle partie : sauvegarde celle en cours, crée la nouvelle (vide) et en fait la partie en cours. Renvoie son id.
func nouvelle_partie(nom_voulu: String) -> String:
	sauvegarder()
	var n := 1
	while not _entree("p%d" % n).is_empty() or FileAccess.file_exists(_fichier_partie("p%d" % n)):
		n += 1
	var id := "p%d" % n
	var nom_partie_ := nom_voulu.strip_edges().left(NOM_PARTIE_MAX)
	parties.append({"id": id, "nom": nom_partie_ if nom_partie_ != "" else nom_libre(), "date": 0})
	en_cours = id
	_vider()
	sauvegarder()
	return id


## Charge une autre partie (après avoir sauvegardé celle en cours).
func charger_partie(id: String) -> void:
	if id == en_cours or _entree(id).is_empty():
		return
	sauvegarder()
	en_cours = id
	_vider()
	charger()
	_ecrire_index()


## Efface une partie ; impossible pour la partie en cours (il faut d'abord en charger une autre).
func effacer_partie(id: String) -> bool:
	if id == en_cours or _entree(id).is_empty():
		return false
	parties.erase(_entree(id))
	Fichier.effacer(_fichier_partie(id))
	_ecrire_index()
	return true
