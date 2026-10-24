extends Node2D
## Brume au sol : des nappes plates et douces qui dérivent lentement au-dessus du niveau.
## Une seule texture dégradée, dessinée étirée pour chaque nappe (pas d'allocation par image).

const NOMBRE := 34

@export var taille := Vector2(2400, 1600)

var _nappes := []   # chaque nappe : [position, rayon, vitesse]
var _texture: GradientTexture2D


func _ready() -> void:
	var degrade := Gradient.new()
	degrade.colors = PackedColorArray([Palette.BROUILLARD, Color(Palette.BROUILLARD, 0.0)])
	_texture = GradientTexture2D.new()
	_texture.gradient = degrade
	_texture.width = 64
	_texture.height = 64
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(1.0, 0.5)
	# Toujours la même brume au départ (graine fixe)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in NOMBRE:
		_nappes.append([
			Vector2(rng.randf() * taille.x, rng.randf() * taille.y),
			rng.randf_range(160.0, 320.0),
			Vector2(rng.randf_range(8.0, 22.0), rng.randf_range(-3.0, 3.0)),
		])


func _process(delta: float) -> void:
	for nappe in _nappes:
		nappe[0] += nappe[2] * delta
		# Sortie à droite : la nappe revient par la gauche
		if nappe[0].x - nappe[1] > taille.x:
			nappe[0].x = -nappe[1]
	queue_redraw()


func _draw() -> void:
	# Opacité du centre de la nappe ; les nappes sont plates (au ras du sol)
	var teinte := Color(1, 1, 1, clampf(Reglages.BROUILLARD_OPACITE * 4.0, 0.0, 1.0))
	for nappe in _nappes:
		var rayon: float = nappe[1]
		draw_texture_rect(_texture, Rect2(nappe[0] - Vector2(rayon, rayon * 0.45), Vector2(rayon * 2.0, rayon * 0.9)), false, teinte)
