extends Node2D
## Un objet à ramasser. Le niveau le ramasse quand le héros marche dessus.
## Origine = au sol.

@export_enum("conserve", "eau", "bandage", "piles", "fiole") var type := "conserve"

var _temps := randf() * TAU
var _ramasse := 0.0   # > 0 : animation de ramassage


## Appelé par le niveau. Renvoie le type, puis l'objet s'envole et disparaît.
func ramasser() -> String:
	remove_from_group("objets")
	_ramasse = 0.4
	return type


func _process(delta: float) -> void:
	_temps += delta
	if _ramasse > 0.0:
		_ramasse -= delta
		if _ramasse <= 0.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var flotte := sin(_temps * 3.0) * 4.0 - 26.0
	if _ramasse > 0.0:
		var avance := 1.0 - _ramasse / 0.4
		flotte -= avance * 50.0
		modulate.a = 1.0 - avance
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.4, 1.4))
	Dessin.ellipse(self, Vector2.ZERO, Vector2(14, 5), Palette.OMBRE, false)
	# Petite lueur pour le repérer dans le noir
	draw_circle(Vector2(0, flotte), 26.0, Palette.LAMPE * Color(1, 1, 1, 0.12 + 0.06 * sin(_temps * 4.0)))
	var c := Vector2(0, flotte)
	match type:
		"conserve":
			Dessin.rect(self, Rect2(c + Vector2(-11, -14), Vector2(22, 28)), Palette.UI_BORD)
			draw_rect(Rect2(c + Vector2(-11, -6), Vector2(22, 12)), Palette.COEUR)
		"eau":
			Dessin.rect(self, Rect2(c + Vector2(-9, -12), Vector2(18, 28)), Palette.FENETRE)
			Dessin.rect(self, Rect2(c + Vector2(-5, -19), Vector2(10, 7)), Palette.UI_TEXTE)
		"bandage":
			Dessin.rect(self, Rect2(c + Vector2(-15, -11), Vector2(30, 22)), Palette.UI_TEXTE)
			draw_rect(Rect2(c + Vector2(-3, -8), Vector2(6, 16)), Palette.COEUR)
			draw_rect(Rect2(c + Vector2(-8, -3), Vector2(16, 6)), Palette.COEUR)
		"piles":
			for dx in [-7.0, 7.0]:
				Dessin.rect(self, Rect2(c + Vector2(dx - 5, -13), Vector2(10, 26)), Palette.LAMPE)
				draw_rect(Rect2(c + Vector2(dx - 5, 3), Vector2(10, 10)), Palette.CONTOUR)
		"fiole":
			Dessin.cercle(self, c + Vector2(0, 4), 12.0, Palette.ZOMBIE_PEAU.lightened(0.3))
			Dessin.rect(self, Rect2(c + Vector2(-5, -18), Vector2(10, 12)), Palette.UI_TEXTE)
			draw_circle(c + Vector2(-4, 1), 3.0, Color(1, 1, 1, 0.7))
