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

## Objets rangés à la base, cumulés sur toutes les parties : { type: nombre }
var inventaire := {}
## Constructions faites à la base (noms), remplies à l'étape (b) du lot 2
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
