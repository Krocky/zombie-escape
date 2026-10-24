extends Control
## Écran de fin : Victoire ou Retour à la base, objets rapportés ou perdus, inventaire de la base.


func _ready() -> void:
	var resultat := Partie.resultat
	var titre: Label = $Centre/Colonne/Titre
	titre.text = "Victoire !" if resultat["victoire"] else "Retour à la base"
	titre.add_theme_color_override("font_color", Palette.SORTIE if resultat["victoire"] else Palette.LAMPE)
	titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)

	var lignes := []
	if resultat["victoire"]:
		lignes.append("Tu es sorti du supermarché !")
	else:
		lignes.append("Tu as été rattrapé... tes amis t'ont ramené à la base.")
	lignes.append("Objets rapportés : " + _liste(resultat["rapportes"]))
	if not resultat["victoire"]:
		lignes.append("Objets perdus en route : " + _liste(resultat["perdus"]))
	$Centre/Colonne/Resume.text = "\n".join(lignes)
	$Centre/Colonne/Resume.add_theme_color_override("font_color", Palette.UI_TEXTE)

	var stock := []
	for type in Partie.NOMS:
		if Partie.inventaire.get(type, 0) > 0:
			stock.append("%s x%d" % [Partie.nom(type), Partie.inventaire[type]])
	$Centre/Colonne/Inventaire.text = "Inventaire de la base :\n" + (", ".join(stock) if stock else "vide")
	$Centre/Colonne/Inventaire.add_theme_color_override("font_color", Palette.UI_BORD)

	$Centre/Colonne/Rejouer.couleur = Palette.LAMPE
	$Centre/Colonne/Rejouer.appuye.connect(_rejouer)


func _liste(types: Array) -> String:
	if types.is_empty():
		return "aucun"
	var noms := []
	for type in types:
		noms.append(Partie.nom(type))
	return ", ".join(noms)


func _rejouer() -> void:
	get_tree().change_scene_to_file("res://scenes/niveau.tscn")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.FOND_NUIT)
