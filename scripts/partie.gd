extends Node
## Résultat de la dernière partie et inventaire sauvegardé (user://).
## La base n'existe pas encore : l'inventaire est juste affiché sur l'écran de fin.

const FICHIER := "user://sauvegarde.json"
const NOMS := {
	"conserve": "Conserve",
	"eau": "Bouteille d'eau",
	"bandage": "Bandage",
	"piles": "Piles",
	"fiole": "Fiole de remède",
}

## Objets rangés à la base, cumulés sur toutes les parties : { type: nombre }
var inventaire := {}
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
		fichier.store_string(JSON.stringify({"version": 1, "inventaire": inventaire}))


func charger() -> void:
	if not FileAccess.file_exists(FICHIER):
		return
	var donnees = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if donnees is Dictionary and donnees.get("inventaire") is Dictionary:
		for type in donnees["inventaire"]:
			inventaire[type] = int(donnees["inventaire"][type])
