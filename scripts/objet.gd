extends Node2D
## Un objet à ramasser. Le niveau le ramasse quand le héros marche dessus.
## Origine = au sol (coordonnées monde). Affichage isométrique dans le calque Vue.

@export_enum("conserve", "eau", "bandage", "piles", "fiole") var type := "conserve"

## Image V2 de chaque type (la fiole n'en a pas : dessinée en code).
const IMAGES := {"conserve": "conserve", "eau": "eau", "bandage": "trousse", "piles": "piles"}
const HAUTEUR_ICONE := 46.0   # pixels d'écran

var _temps := randf() * TAU
var _ramasse := 0.0   # > 0 : animation de ramassage
var _vue := Node2D.new()


## Appelé par le niveau. Renvoie le type, puis l'objet s'envole et disparaît.
func ramasser() -> String:
	remove_from_group("objets")
	_ramasse = 0.4
	return type


## Nœuds d'affichage, placés par le niveau.
func visuels() -> Dictionary:
	return {"vue": _vue}


func _ready() -> void:
	_vue.position = Iso.ecran(global_position)
	_vue.draw.connect(_dessiner)


func _exit_tree() -> void:
	if is_instance_valid(_vue):
		_vue.queue_free()


func _process(delta: float) -> void:
	_temps += delta
	if _ramasse > 0.0:
		_ramasse -= delta
		if _ramasse <= 0.0:
			queue_free()
	_vue.queue_redraw()


func _dessiner() -> void:
	var flotte := sin(_temps * 3.0) * 4.0 - 14.0
	if _ramasse > 0.0:
		var avance := 1.0 - _ramasse / 0.4
		flotte -= avance * 50.0
		_vue.modulate.a = 1.0 - avance
	Dessin.ombre(_vue, Rect2(-22, -7, 44, 14))
	# Petite lueur pour le repérer dans le noir
	_vue.draw_circle(Vector2(0, flotte - HAUTEUR_ICONE / 2.0), 30.0, Palette.LAMPE * Color(1, 1, 1, 0.12 + 0.06 * sin(_temps * 4.0)))
	var nom: String = IMAGES.get(type, "")
	if nom != "" and Images.existe(nom):
		Images.dessiner_pieds(_vue, nom, Vector2(0, flotte), HAUTEUR_ICONE / Images.region(nom).size.y)
	else:
		_dessiner_secours(Vector2(0, flotte - 20.0))


## Dessin en code (fiole, ou image manquante).
func _dessiner_secours(c: Vector2) -> void:
	_vue.draw_set_transform(c, 0.0, Vector2(1.4, 1.4))
	c = Vector2.ZERO
	match type:
		"conserve":
			Dessin.rect(_vue, Rect2(c + Vector2(-11, -14), Vector2(22, 28)), Palette.UI_BORD)
			_vue.draw_rect(Rect2(c + Vector2(-11, -6), Vector2(22, 12)), Palette.COEUR)
		"eau":
			Dessin.rect(_vue, Rect2(c + Vector2(-9, -12), Vector2(18, 28)), Palette.FENETRE)
			Dessin.rect(_vue, Rect2(c + Vector2(-5, -19), Vector2(10, 7)), Palette.UI_TEXTE)
		"bandage":
			Dessin.rect(_vue, Rect2(c + Vector2(-15, -11), Vector2(30, 22)), Palette.UI_TEXTE)
			_vue.draw_rect(Rect2(c + Vector2(-3, -8), Vector2(6, 16)), Palette.COEUR)
			_vue.draw_rect(Rect2(c + Vector2(-8, -3), Vector2(16, 6)), Palette.COEUR)
		"piles":
			for dx: float in [-7.0, 7.0]:
				Dessin.rect(_vue, Rect2(c + Vector2(dx - 5, -13), Vector2(10, 26)), Palette.LAMPE)
				_vue.draw_rect(Rect2(c + Vector2(dx - 5, 3), Vector2(10, 10)), Palette.CONTOUR)
		"fiole":
			Dessin.cercle(_vue, c + Vector2(0, 4), 12.0, Palette.ZOMBIE_PEAU.lightened(0.3))
			Dessin.rect(_vue, Rect2(c + Vector2(-5, -18), Vector2(10, 12)), Palette.UI_TEXTE)
			_vue.draw_circle(c + Vector2(-4, 1), 3.0, Color(1, 1, 1, 0.7))
	_vue.draw_set_transform(Vector2.ZERO)
