extends Node2D
## Brume au sol : des nappes plates et douces qui dérivent lentement (coordonnées écran).
## Une seule texture dégradée, dessinée étirée pour chaque nappe (pas d'allocation par image).
## Deux couches dans le niveau : sous les personnages (dense) et par-dessus (légère).
## Performance : les nappes sont dessinées en petit (1/DIVISEUR) dans une image à part, puis cette
## image est affichée agrandie en tuiles. Chaque pixel de l'écran ne reçoit qu'une couche de brume
## au lieu de plusieurs nappes superposées, et chaque tuile n'est éclairée que par les lumières
## qui la touchent (les tuiles hors de l'écran ne sont pas dessinées). La brume est très floue :
## la différence ne se voit pas.

const NOMBRE := 34
const DIVISEUR := 4            # l'image de la brume est 4 fois plus petite que l'écran
const TUILE := 512.0           # côté d'une tuile d'affichage (multiple de DIVISEUR)
const MARGE := Vector2(320, 160)   # les nappes dépassent du rectangle (rayon max, aplati)

@export var taille := Vector2(2400, 1600)
@export var force := 1.0          # multiplie Reglages.BROUILLARD_OPACITE
## Vrai : la brume n'est pas assombrie par la nuit (elle reste visible, comme une brume claire).
@export var lumineuse := false
@export var graine := 1

var _nappes := []   # chaque nappe : [position, rayon, vitesse]
var _texture: GradientTexture2D
var _image := SubViewport.new()   # la brume en petit
var _dessin := Node2D.new()       # dessine les nappes dans _image


func _ready() -> void:
	var degrade := Gradient.new()
	var couleur := Palette.BRUME_CLAIRE if lumineuse else Palette.BROUILLARD
	degrade.colors = PackedColorArray([couleur, Color(couleur, 0.0)])
	_texture = GradientTexture2D.new()
	_texture.gradient = degrade
	_texture.width = 64
	_texture.height = 64
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(1.0, 0.5)
	# Toujours la même brume au départ (graine fixe)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	for i in NOMBRE:
		_nappes.append([
			Vector2(rng.randf() * taille.x, rng.randf() * taille.y),
			rng.randf_range(160.0, 320.0),
			Vector2(rng.randf_range(8.0, 22.0), rng.randf_range(-3.0, 3.0)),
		])
	# Image de la brume en petit, transparente (elle garde l'opacité des nappes)
	var etendue := taille + MARGE * 2.0
	_image.size = Vector2i((etendue / DIVISEUR).ceil())
	_image.transparent_bg = true
	_image.disable_3d = true
	_image.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_dessin.scale = Vector2.ONE / DIVISEUR
	_dessin.position = MARGE / DIVISEUR
	_dessin.draw.connect(_dessiner)
	_image.add_child(_dessin)
	add_child(_image)
	# L'image contient des couleurs déjà multipliées par l'opacité : mélange « prémultiplié »
	var melange := CanvasItemMaterial.new()
	melange.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	if lumineuse:
		melange.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var y := 0.0
	while y < etendue.y:
		var x := 0.0
		while x < etendue.x:
			var tuile := Sprite2D.new()
			tuile.texture = _image.get_texture()
			tuile.centered = false
			tuile.region_enabled = true
			tuile.region_rect = Rect2(Vector2(x, y) / DIVISEUR, Vector2(TUILE, TUILE).min(etendue - Vector2(x, y)) / DIVISEUR)
			tuile.scale = Vector2(DIVISEUR, DIVISEUR)
			tuile.position = Vector2(x, y) - MARGE
			tuile.material = melange
			add_child(tuile)
			x += TUILE
		y += TUILE


func _process(delta: float) -> void:
	for nappe in _nappes:
		nappe[0] += nappe[2] * delta
		# Sortie à droite : la nappe revient par la gauche
		if nappe[0].x - nappe[1] > taille.x:
			nappe[0].x = -nappe[1]
	_dessin.queue_redraw()


func _dessiner() -> void:
	# Opacité du centre de la nappe ; les nappes sont plates (au ras du sol)
	var teinte := Color(1, 1, 1, clampf(Reglages.BROUILLARD_OPACITE * 4.0 * force, 0.0, 1.0))
	for i in range(0, _nappes.size(), 2 if Qualite.basse else 1):   # qualité basse : une nappe sur deux
		var nappe: Array = _nappes[i]
		var rayon: float = nappe[1]
		_dessin.draw_texture_rect(_texture, Rect2(nappe[0] - Vector2(rayon, rayon * 0.45), Vector2(rayon * 2.0, rayon * 0.9)), false, teinte)
