extends Node2D
## La sortie du supermarché : une porte ouverte dans le mur du fond, avec un panneau.
## Le niveau détecte quand le héros l'atteint. Origine = au sol, devant la porte (coordonnées monde).
## Affichage isométrique : la porte (image V2) remplace un pan du mur du fond (voir Mur.portes).

const LARGEUR := 200.0     # = Mur.LONGUEUR_PANNEAU
const EPAISSEUR := 80.0    # épaisseur du mur du fond

var _vue := Node2D.new()
var _devant := Node2D.new()   # panneau « SORTIE », par-dessus la porte
var _hauteur := 140.0         # hauteur de la porte à l'écran


## Nœuds d'affichage, placés par le niveau.
func visuels() -> Dictionary:
	return {"vue": _vue}


func _ready() -> void:
	var lumiere: PointLight2D = $Lumiere
	lumiere.color = Palette.SORTIE
	_vue.y_sort_enabled = true
	if Images.existe("porte_ouverte"):
		# La porte remplace le pan de mur derrière elle (Mur.portes) : même longueur, même alignement
		var emprise := Rect2(global_position.x - LARGEUR / 2.0, global_position.y - 5.0 - EPAISSEUR, LARGEUR, EPAISSEUR)
		Iso.habiller("porte_ouverte", emprise, _vue, Iso.miroir_pour("porte_ouverte", true))
		_hauteur = Iso.hauteur_image("porte_ouverte", emprise)
	else:
		var porte := Node2D.new()
		porte.position = Iso.ecran(global_position)
		porte.draw.connect(func() -> void:
			Dessin.rect(porte, Rect2(-50, -115, 100, 110), Palette.CONTOUR)
			Dessin.rect(porte, Rect2(-42, -107, 84, 102), Palette.SORTIE * Color(0.6, 0.8, 0.6, 1)))
		_vue.add_child(porte)
	# Lumière verte sur le sol devant la porte
	remove_child(lumiere)
	lumiere.position = Iso.ecran(global_position + Vector2(0, 70))
	_vue.add_child(lumiere)
	_devant.position = Iso.ecran(global_position) + Vector2(0, 2)
	# Le panneau brille dans le noir (pas assombri par la nuit)
	var sans_ombre := CanvasItemMaterial.new()
	sans_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_devant.material = sans_ombre
	_devant.draw.connect(_dessiner_panneau)
	_vue.add_child(_devant)


func _dessiner_panneau() -> void:
	# Panneau « SORTIE » au-dessus de l'ouverture
	var haut := Vector2(-20, -_hauteur * 0.92)
	Dessin.rect(_devant, Rect2(haut + Vector2(-58, 0), Vector2(116, 36)), Palette.SORTIE)
	var police := ThemeDB.fallback_font
	var largeur := police.get_string_size("SORTIE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_devant.draw_string(police, haut + Vector2(-largeur / 2.0, 27), "SORTIE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.CONTOUR)
