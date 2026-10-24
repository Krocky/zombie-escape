extends Node2D
## Le niveau : le supermarché abandonné. Relie le HUD au héros et dessine le sol.

const TAILLE := Vector2(2400, 1600)
const CARREAU := 80.0


func _ready() -> void:
	$HUD.deplacement.connect($Monde/Heros.definir_direction)
	$Monde/Heros.regler_limites_camera(Rect2(Vector2.ZERO, TAILLE))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, TAILLE), Palette.SOL)
	var x := CARREAU
	while x < TAILLE.x:
		draw_line(Vector2(x, 0), Vector2(x, TAILLE.y), Palette.SOL_JOINT, 3.0)
		x += CARREAU
	var y := CARREAU
	while y < TAILLE.y:
		draw_line(Vector2(0, y), Vector2(TAILLE.x, y), Palette.SOL_JOINT, 3.0)
		y += CARREAU
