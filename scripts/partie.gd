extends Node
## Résultat de la dernière partie, inventaire et constructions de la base, sauvegardés (user://).
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
