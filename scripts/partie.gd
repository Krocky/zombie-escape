extends Node
## Résultat de la dernière partie, inventaire et constructions de la base, sauvegardés (user://).
## Retient aussi le lieu choisi sur la carte (pas sauvegardé).
## Sauvegarde version 2 : {"version": 2, "inventaire": {type: nombre}, "constructions": [nom, ...]}.
## Une sauvegarde version 1 (sans constructions) est reprise telle quelle, puis réécrite en version 2.

const FICHIER := "user://sauvegarde.json"
const VERSION := 2
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
## Dernière partie : victoire (bool), rapportes (Array), perdus (Array)
var resultat := {"victoire": false, "rapportes": [], "perdus": []}


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
	for type in rapportes:
		inventaire[type] = inventaire.get(type, 0) + 1
	resultat = {"victoire": victoire, "rapportes": rapportes, "perdus": perdus}
	sauvegarder()


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
		fichier.store_string(JSON.stringify({"version": VERSION, "inventaire": inventaire, "constructions": constructions}))


## Lit la sauvegarde (version 1 ou 2). Une version 1 est aussitôt réécrite en version 2.
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
	if int(donnees.get("version", 1)) < VERSION:
		sauvegarder()
