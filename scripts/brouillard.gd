extends Node2D
## Léger brouillard : des nappes grises qui dérivent lentement au-dessus du niveau.

const NOMBRE := 22

@export var taille := Vector2(2400, 1600)

var _nappes := []   # chaque nappe : [position, rayon, vitesse]


func _ready() -> void:
	for i in NOMBRE:
		_nappes.append([
			Vector2(randf() * taille.x, randf() * taille.y),
			randf_range(140.0, 280.0),
			Vector2(randf_range(8.0, 22.0), randf_range(-4.0, 4.0)),
		])


func _process(delta: float) -> void:
	for nappe in _nappes:
		nappe[0] += nappe[2] * delta
		# Sortie à droite : la nappe revient par la gauche
		if nappe[0].x - nappe[1] > taille.x:
			nappe[0].x = -nappe[1]
	queue_redraw()


func _draw() -> void:
	for nappe in _nappes:
		# Plusieurs cercles transparents empilés = bord doux
		for i in 4:
			draw_circle(nappe[0], nappe[1] * (1.0 - i * 0.2), Palette.BROUILLARD * Color(1, 1, 1, Reglages.BROUILLARD_OPACITE))
