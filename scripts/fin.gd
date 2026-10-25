extends Control
## Écran de fin : Victoire ou Retour à la base, objets rapportés ou perdus, inventaire de la base.
## Le bouton « Retour à la base » ramène à l'écran Base.
## Fond illustré (DecorEcran) et icônes des objets (Dessin.icone_objet).

const TAILLE_ICONE := 54.0

var _temps := 0.0
var _partie := Control.new()   # icônes : objets rapportés, puis perdus (barrés)
var _base := Control.new()     # icônes : inventaire de la base, avec le nombre


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

	$Centre/Colonne/RetourBase.couleur = Palette.LAMPE
	$Centre/Colonne/RetourBase.appuye.connect(_retour_base)
	$Centre/Colonne/Resume.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Centre/Colonne/Resume.add_theme_constant_override("outline_size", 6)
	$Centre/Colonne/Inventaire.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Centre/Colonne/Inventaire.add_theme_constant_override("outline_size", 6)
	# Lignes d'icônes sous les textes
	for ligne in [[_partie, $Centre/Colonne/Resume], [_base, $Centre/Colonne/Inventaire]]:
		ligne[0].custom_minimum_size = Vector2(0, TAILLE_ICONE + 12)
		ligne[0].mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Centre/Colonne.add_child(ligne[0])
		$Centre/Colonne.move_child(ligne[0], ligne[1].get_index() + 1)
	_partie.draw.connect(_dessiner_partie)
	_base.draw.connect(_dessiner_base)


func _liste(types: Array) -> String:
	if types.is_empty():
		return "aucun"
	var noms := []
	for type in types:
		noms.append(Partie.nom(type))
	return ", ".join(noms)


func _retour_base() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()


func _draw() -> void:
	var scene := DecorEcran.Scene.VICTOIRE if Partie.resultat["victoire"] else DecorEcran.Scene.DEFAITE
	DecorEcran.dessiner(self, size, _temps, scene)


## Objets rapportés (en couleur) puis perdus (sombres, barrés d'une croix rouge), centrés.
func _dessiner_partie() -> void:
	var rapportes: Array = Partie.resultat["rapportes"]
	var perdus: Array = Partie.resultat["perdus"]
	var types := rapportes + perdus
	var x0 := _partie.size.x / 2.0 - (types.size() - 1) * (TAILLE_ICONE + 14) / 2.0
	for i in types.size():
		var pieds := Vector2(x0 + i * (TAILLE_ICONE + 14), TAILLE_ICONE + 6)
		var perdu := i >= rapportes.size()
		Dessin.icone_objet(_partie, types[i], pieds, TAILLE_ICONE, Color(0.65, 0.65, 0.75, 0.8) if perdu else Color.WHITE)
		if perdu:
			var c := pieds - Vector2(0, TAILLE_ICONE / 2.0)
			for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
				_partie.draw_line(c - d * 18.0, c + d * 18.0, Palette.COEUR, 6.0, true)


## Inventaire de la base : une icône par type, avec « x N ».
func _dessiner_base() -> void:
	var types := []
	for type in Partie.NOMS:
		if Partie.inventaire.get(type, 0) > 0:
			types.append(type)
	var pas := TAILLE_ICONE + 56
	var x0 := _base.size.x / 2.0 - (types.size() - 1) * pas / 2.0
	for i in types.size():
		Dessin.objet_compte(_base, types[i], Vector2(x0 + i * pas - 16, TAILLE_ICONE + 6), TAILLE_ICONE, Partie.inventaire[types[i]])
