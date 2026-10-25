extends Node
## Résultat de la dernière partie, inventaire et constructions de la base, sauvegardés (user://).
## Retient aussi le lieu choisi sur la carte (pas sauvegardé).
## Sauvegarde version 4 : {"version": 4, "inventaire": {type: nombre}, "constructions": [nom, ...],
## "remede": fioles dans la jauge, "remede_annonce": écran « Remède trouvé ! » déjà vu,
## "skin": héros choisi ("heros" ou "heroine", "" = pas encore choisi), "prenom": prénom du joueur}.
## Une sauvegarde plus ancienne est reprise telle quelle (ses fioles vont dans la jauge), puis réécrite en version 4.

const FICHIER := "user://sauvegarde.json"
const VERSION := 4
const NOMS := {
	"conserve": "Conserve",
	"eau": "Bouteille d'eau",
	"bandage": "Bandage",
	"piles": "Piles",
	"fiole": "Fiole de remède",
}
## Constructions de la base, dans l'ordre des cartes : nom -> nom affiché (coûts et effets dans Reglages)
const CONSTRUCTIONS := {
	"barricade": "Barricade",
	"atelier": "Atelier",
	"lampe": "Lampe renforcée",
}
## Héros au choix (écran « Choisis ton héros ») : skin -> nom affiché. Images : images/v3/<skin>_<pose>.png
const SKINS := {"heros": "Garçon", "heroine": "Fille"}
const PRENOM_MAX := 12

## Lieux de la carte, dans l'ordre : id -> nom, « sortir de... » (écran de fin), scène.
## Sans scène, le lieu est affiché « Bientôt » sur la carte.
const LIEUX := {
	"supermarche": {"nom": "Supermarché", "du": "du supermarché", "scene": "res://scenes/lieux/supermarche.tscn"},
	"maison": {"nom": "Maison", "du": "de la maison", "scene": "res://scenes/lieux/maison.tscn"},
}

## Lieu choisi sur la carte (clé de LIEUX)
var lieu := "supermarche"
## Objets rangés à la base, cumulés sur toutes les parties : { type: nombre }
var inventaire := {}
## Constructions faites à la base (noms, voir CONSTRUCTIONS)
var constructions := []
## Fioles versées dans la jauge du remède (au plus Reglages.REMEDE_FIOLES)
var remede := 0
## Vrai quand l'écran « Remède trouvé ! » a été montré (une seule fois)
var remede_annonce := false
## Héros choisi (clé de SKINS), "" tant que le joueur n'a pas choisi
var skin := ""
## Prénom du joueur ("" s'il n'en a pas mis)
var prenom := ""
## Dernière partie : victoire (bool), rapportes (Array), perdus (Array),
## mission (objectif rempli, bool), bonus (Array), fioles (versées dans la jauge, int)
var resultat := {"victoire": false, "rapportes": [], "perdus": [], "mission": false, "bonus": [], "fioles": 0}


func _ready() -> void:
	charger()


## Appelé par le niveau à la fin. En cas de défaite, on perd la moitié des objets (au hasard, arrondi en dessous).
func terminer(victoire: bool, ramasses: Array) -> void:
	var rapportes := ramasses.duplicate()
	var perdus := []
	if not victoire:
		rapportes.shuffle()
		for i in rapportes.size() / 2:
			perdus.append(rapportes.pop_back())
	# Objectif rempli en sortant vivant : bonus d'objets au hasard (jamais de fiole, elle se mérite)
	var mission := victoire and objectif_rempli(lieu, rapportes)
	var bonus := []
	if mission:
		var types := NOMS.keys()
		types.erase("fiole")
		for i in Reglages.MISSION_BONUS:
			bonus.append(types.pick_random())
	for type in rapportes + bonus:
		inventaire[type] = inventaire.get(type, 0) + 1
	resultat = {"victoire": victoire, "rapportes": rapportes, "perdus": perdus, "mission": mission, "bonus": bonus,
		"fioles": _remplir_remede()}
	sauvegarder()


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
	return NOMS.get(type, type)


# --- Lieux ---

var _infos_lieux := {}


func lieu_disponible(id: String) -> bool:
	return LIEUX.has(id) and LIEUX[id]["scene"] != ""


func choisir_lieu(id: String) -> void:
	lieu = id


func scene_lieu() -> String:
	return LIEUX[lieu]["scene"]


## Ce qu'on trouve dans un lieu, lu dans sa scène sans l'instancier (les entités créent leurs nœuds
## d'affichage dès leur création) : {"zombies": [type, ...], "objets": [type, ...]}.
func infos_lieu(id: String) -> Dictionary:
	if not _infos_lieux.has(id):
		var infos := {"zombies": [], "objets": []}
		if lieu_disponible(id):
			var etat: SceneState = load(LIEUX[id]["scene"]).get_state()
			for i in etat.get_node_count():
				var modele := etat.get_node_instance(i)
				if modele == null:
					continue
				if modele.resource_path == "res://scenes/zombie.tscn":
					infos["zombies"].append(_propriete(etat, i, "type", 0))
				elif modele.resource_path == "res://scenes/objet.tscn":
					infos["objets"].append(_propriete(etat, i, "type", "conserve"))
		_infos_lieux[id] = infos
	return _infos_lieux[id]


## Valeur d'une propriété réglée dans la scène, sinon la valeur par défaut.
func _propriete(etat: SceneState, noeud: int, nom_propriete: String, defaut: Variant) -> Variant:
	for k in etat.get_node_property_count(noeud):
		if etat.get_node_property_name(noeud, k) == nom_propriete:
			return etat.get_node_property_value(noeud, k)
	return defaut


# --- Missions ---

## Objets à rapporter dans un lieu : { type: nombre }.
func objectif(id: String) -> Dictionary:
	match id:
		"supermarche":
			return Reglages.SUPERMARCHE_OBJECTIF
		"maison":
			return Reglages.MAISON_OBJECTIF
	return {}


## L'objectif en quelques mots : « rapporter 2 bandages ».
func texte_objectif(id: String) -> String:
	var morceaux := []
	var o := objectif(id)
	for type in o:
		var mots := nom(type).to_lower().split(" ")
		if o[type] > 1 and not mots[0].ends_with("s"):
			mots[0] += "s"
		morceaux.append("%d %s" % [o[type], " ".join(mots)])
	return "rapporter " + " et ".join(morceaux)


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
	return {}


## L'effet en une phrase (carte de la base).
func effet(construction: String) -> String:
	match construction:
		"barricade":
			return "+%d cœur%s pour le héros" % [Reglages.BARRICADE_COEURS, "s" if Reglages.BARRICADE_COEURS > 1 else ""]
		"atelier":
			return "La batte fait +%d dégât%s" % [Reglages.ATELIER_DEGATS, "s" if Reglages.ATELIER_DEGATS > 1 else ""]
		"lampe":
			return "Lampe +%d %% plus loin" % Reglages.LAMPE_RENFORCEE_PORTEE
	return ""


func est_construit(construction: String) -> bool:
	return construction in constructions


func peut_construire(construction: String) -> bool:
	if est_construit(construction):
		return false
	var c := cout(construction)
	for type in c:
		if inventaire.get(type, 0) < c[type]:
			return false
	return true


## Retire les objets de l'inventaire, ajoute la construction et sauvegarde. Faux si impossible.
func construire(construction: String) -> bool:
	if not peut_construire(construction):
		return false
	var c := cout(construction)
	for type in c:
		inventaire[type] -= c[type]
	constructions.append(construction)
	sauvegarder()
	return true


## Effets des constructions dans le niveau
func heros_pv() -> int:
	return Reglages.HEROS_PV + (Reglages.BARRICADE_COEURS if est_construit("barricade") else 0)


func degats_batte() -> int:
	return Reglages.ATTAQUE_DEGATS + (Reglages.ATELIER_DEGATS if est_construit("atelier") else 0)


func portee_lampe() -> float:
	return Reglages.LAMPE_PORTEE * (1.0 + Reglages.LAMPE_RENFORCEE_PORTEE / 100.0 if est_construit("lampe") else 1.0)


func sauvegarder() -> void:
	var fichier := FileAccess.open(FICHIER, FileAccess.WRITE)
	if fichier:
		fichier.store_string(JSON.stringify({"version": VERSION, "inventaire": inventaire, "constructions": constructions,
			"remede": remede, "remede_annonce": remede_annonce, "skin": skin, "prenom": prenom}))


## Lit la sauvegarde (version 1 à 4). Une version plus ancienne est aussitôt réécrite en version 4
## (les fioles déjà rangées remplissent la jauge du remède).
func charger() -> void:
	if not FileAccess.file_exists(FICHIER):
		return
	var donnees = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
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
	if int(donnees.get("version", 1)) < VERSION:
		_remplir_remede()
		sauvegarder()
