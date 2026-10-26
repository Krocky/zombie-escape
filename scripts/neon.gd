extends Node2D
## Néon suspendu dont la lumière grésille au hasard : tube du supermarché (image V3 « prop_neon ») ou
## croix verte de la pharmacie (« prop_pharmacy_cross », `image` réglée dans la scène du lieu).
## Pas de collision (il pend du plafond). Origine = au sol, milieu du bord bas de son emprise (monde).
## Affichage isométrique : le niveau place visuels() dans ses calques.

const TAILLE := Vector2(110, 110)        # emprise au sol de l'image (monde)
const TAILLE_CROIX := Vector2(80, 80)    # croix de la pharmacie, plus petite
const ENERGIE := 0.6                     # lumière allumée
const ENERGIE_COUPEE := 0.1              # lumière pendant un raté
const ATTENTE := Vector2(1.5, 5.0)       # secondes entre deux grésillements (au hasard)
const DUREE_GRESILLEMENT := Vector2(0.25, 0.9)
const RATE := 0.06                       # durée d'un clignotement pendant le grésillement
## Milieu de la flaque de lumière dans l'image (pixels) et couleur de la lumière, par image
const FLAQUES := {"prop_neon": Vector2(110, 255), "prop_pharmacy_cross": Vector2(150, 565)}

@export var image := "prop_neon"

static var _texture_lumiere: GradientTexture2D

var _vue := Node2D.new()
var _lumiere := PointLight2D.new()
var _hasard := RandomNumberGenerator.new()
var _attente := 1.0
var _gresille := 0.0
var _clignote := 0.0
var _image_ecran := Rect2()   # image à l'écran (transparence quand le héros est derrière)
var _coins := PackedVector2Array()


## Nœuds d'affichage, placés par le niveau.
func visuels() -> Dictionary:
	return {"vue": _vue}


func _ready() -> void:
	_hasard.randomize()
	_vue.y_sort_enabled = true
	var t := TAILLE_CROIX if image == "prop_pharmacy_cross" else TAILLE
	var emprise := Rect2(global_position + Vector2(-t.x / 2.0, -t.y), t)
	_coins = Iso.coins(emprise)
	if Images.existe(image):
		_image_ecran = Iso.habiller(image, emprise, _vue)
		_lumiere.position = Iso.point_image(image, emprise, FLAQUES.get(image, Vector2.ZERO))
	else:
		# Secours : un tube clair suspendu
		var tube := Node2D.new()
		tube.position = Iso.ecran(global_position)
		tube.draw.connect(func() -> void:
			Dessin.polygone(tube, PackedVector2Array([Vector2(-40, -150), Vector2(40, -190), Vector2(46, -180), Vector2(-34, -140)]), Palette.NEON))
		_vue.add_child(tube)
		_lumiere.position = Iso.ecran(emprise.get_center())
	if _texture_lumiere == null:
		var degrade := Gradient.new()
		degrade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		_texture_lumiere = GradientTexture2D.new()
		_texture_lumiere.gradient = degrade
		_texture_lumiere.width = 128
		_texture_lumiere.height = 128
		_texture_lumiere.fill = GradientTexture2D.FILL_RADIAL
		_texture_lumiere.fill_from = Vector2(0.5, 0.5)
		_texture_lumiere.fill_to = Vector2(1.0, 0.5)
	_lumiere.texture = _texture_lumiere
	_lumiere.texture_scale = 2.6
	_lumiere.color = Palette.NEON_PHARMACIE if image == "prop_pharmacy_cross" else Palette.NEON
	_lumiere.energy = ENERGIE
	_vue.add_child(_lumiere)
	_attente = _hasard.randf_range(ATTENTE.x, ATTENTE.y)


## Appelé par le niveau à chaque pas : le néon devient transparent quand le héros est caché derrière.
func voir_a_travers(pieds: Vector2, delta: float) -> void:
	if _image_ecran.size == Vector2.ZERO:
		return
	_vue.modulate.a = move_toward(_vue.modulate.a, Iso.opacite_devant(_image_ecran, _coins, pieds), delta * 3.0)


func _process(delta: float) -> void:
	_attente -= delta
	if _attente <= 0.0:
		_gresille = _hasard.randf_range(DUREE_GRESILLEMENT.x, DUREE_GRESILLEMENT.y)
		_attente = _gresille + _hasard.randf_range(ATTENTE.x, ATTENTE.y)
	if _gresille > 0.0:
		_gresille -= delta
		_clignote -= delta
		if _clignote <= 0.0:
			_clignote = RATE * _hasard.randf_range(0.5, 1.5)
			_lumiere.energy = ENERGIE if _hasard.randf() < 0.45 else ENERGIE_COUPEE
		if _gresille <= 0.0:
			_lumiere.energy = ENERGIE
