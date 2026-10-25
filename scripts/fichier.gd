class_name Fichier
## Sauvegardes sûres (Partie, ParametresJeu) : on écrit d'abord dans « <fichier>.tmp », puis on le renomme.
## Si Android tue l'appli pendant l'écriture, seul le .tmp est abîmé : l'ancienne sauvegarde reste entière.
## À la lecture, si le fichier principal est absent ou illisible, on reprend le .tmp (écriture coupée juste avant le renommage).

const SUFFIXE := ".tmp"


## Écrit « donnees » en JSON dans « chemin » (user://...). Faux si l'écriture a échoué.
static func ecrire_json(chemin: String, donnees: Variant) -> bool:
	var provisoire := chemin + SUFFIXE
	var fichier := FileAccess.open(provisoire, FileAccess.WRITE)
	if fichier == null:
		return false
	fichier.store_string(JSON.stringify(donnees))
	fichier.close()
	if DirAccess.rename_absolute(provisoire, chemin) != OK:
		# Certains systèmes refusent de renommer par-dessus un fichier existant
		DirAccess.remove_absolute(chemin)
		return DirAccess.rename_absolute(provisoire, chemin) == OK
	return true


## Lit le dictionnaire JSON de « chemin », sinon celui du .tmp ; null si aucun des deux n'est lisible.
static func lire_json(chemin: String) -> Variant:
	for nom in [chemin, chemin + SUFFIXE]:
		if FileAccess.file_exists(nom):
			var donnees = JSON.parse_string(FileAccess.get_file_as_string(nom))
			if donnees is Dictionary:
				return donnees
	return null


## Efface le fichier et son .tmp (tests).
static func effacer(chemin: String) -> void:
	for nom in [chemin, chemin + SUFFIXE]:
		if FileAccess.file_exists(nom):
			DirAccess.remove_absolute(nom)
