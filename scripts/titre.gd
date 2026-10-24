extends Control
## Écran titre : le nom du jeu et le bouton Jouer.

var _temps := 0.0


func _ready() -> void:
	$Centre/Colonne/Titre.add_theme_color_override("font_color", Palette.LAMPE)
	$Centre/Colonne/Titre.add_theme_color_override("font_outline_color", Palette.CONTOUR)
	$Centre/Colonne/SousTitre.add_theme_color_override("font_color", Palette.UI_TEXTE)
	$Centre/Colonne/Jouer.couleur = Palette.LAMPE
	$Centre/Colonne/Jouer.appuye.connect(_jouer)


func _jouer() -> void:
	get_tree().change_scene_to_file("res://scenes/niveau.tscn")


func _process(delta: float) -> void:
	_temps += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.FOND_NUIT)
	# Faisceau de lampe torche qui balaie l'écran
	var centre := Vector2(size.x / 2.0, size.y / 2.0)
	var lampe := centre + Vector2(sin(_temps * 0.7) * size.x * 0.3, cos(_temps * 0.5) * size.y * 0.15)
	for i in 4:
		draw_circle(lampe, 260.0 - i * 50.0, Palette.LAMPE * Color(1, 1, 1, 0.04))
	# Des yeux de zombies qui clignent dans le noir
	var yeux := [Vector2(0.12, 0.2), Vector2(0.85, 0.3), Vector2(0.2, 0.8), Vector2(0.8, 0.82)]
	for i in yeux.size():
		if fmod(_temps + i * 1.3, 4.0) < 0.15:
			continue
		var p := Vector2(yeux[i].x * size.x, yeux[i].y * size.y)
		for dx in [-12.0, 12.0]:
			draw_circle(p + Vector2(dx, 0), 8.0, Palette.ZOMBIE_YEUX)
			draw_circle(p + Vector2(dx + 2, 0), 3.0, Palette.CONTOUR)
