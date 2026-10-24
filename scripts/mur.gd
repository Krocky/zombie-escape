extends StaticBody2D
## Obstacle du décor : mur, étagère, caisse...
## position = milieu du bord bas de l'emprise au sol (coordonnées monde).
## Affichage isométrique (voir Iso) : le niveau place visuels() dans ses calques.

enum Style { MUR, ETAGERE, CAISSE }

@export var taille := Vector2(200, 60)   # emprise au sol (collision)
@export var hauteur := 60.0              # hauteur du dessin de secours (pixels d'écran)
@export var style := Style.MUR
## Fenêtres du mur : position (x ou y local, selon le sens du mur) de leur centre.
@export var fenetres := PackedFloat32Array()
## Portes (même repère) : le pan de mur à cet endroit n'est pas dessiné (la porte le remplace).
@export var portes := PackedFloat32Array()
## Mur de devant (en bas de l'écran) : un simple rebord bas, sinon il cacherait la pièce.
@export var rebord := false

const LONGUEUR_PANNEAU := 200.0   # longueur d'un pan de mur (monde), voir Sortie
const LONGUEUR_RAYON := 140.0     # longueur d'un rayon d'étagère (monde)
const HAUTEUR_REBORD := 18.0

static var _texture_lune: GradientTexture2D

var _vue := Node2D.new()   # dans le calque Vue (trié en profondeur)
var _sol := Node2D.new()   # dans le calque du sol (ombre)


func _ready() -> void:
	var forme := RectangleShape2D.new()
	forme.size = taille
	var collision := CollisionShape2D.new()
	collision.shape = forme
	collision.position = Vector2(0, -taille.y / 2.0)
	add_child(collision)
	_vue.y_sort_enabled = true
	if style != Style.MUR:
		_sol.draw.connect(func() -> void: Iso.ombre(_sol, emprise(), 0.8))
	_construire()


## Nœuds d'affichage, placés par le niveau : {"vue": ..., "sol": ...}.
func visuels() -> Dictionary:
	return {"vue": _vue, "sol": _sol}


func emprise() -> Rect2:
	return Rect2(global_position + Vector2(-taille.x / 2.0, -taille.y), taille)


func _construire() -> void:
	var long_en_x := taille.x >= taille.y
	var longueur := maxf(taille.x, taille.y)
	match style:
		Style.MUR:
			if rebord:
				_secours(emprise(), HAUTEUR_REBORD, Palette.MUR, Palette.MUR_FACE, Palette.MUR_COTE)
				return
			var n := maxi(roundi(longueur / LONGUEUR_PANNEAU), 1)
			for i in n:
				var morceau := _morceau(i, n, long_en_x)
				var milieu := -longueur / 2.0 + longueur * (i + 0.5) / n
				var nom := "mur"
				var porte := false
				for p in portes:
					porte = porte or absf(p - milieu) < longueur / n / 2.0
				if porte:
					continue
				for f in fenetres:
					if absf(f - milieu) < longueur / n / 2.0:
						nom = "mur_fenetre"
						_ajouter_lune(morceau)
				_habiller(nom, morceau, long_en_x, Palette.MUR, Palette.MUR_FACE, Palette.MUR_COTE)
		Style.ETAGERE:
			var n := maxi(roundi(longueur / LONGUEUR_RAYON), 1)
			for i in n:
				_habiller("etagere", _morceau(i, n, long_en_x), long_en_x, Palette.ETAGERE, Palette.ETAGERE_FACE, Palette.ETAGERE_COTE, Palette.ETAGERE_TEINTE)
		Style.CAISSE:
			# Petite ou grande caisse, dans un sens ou l'autre : toujours pareil pour une même caisse
			var h := hash(Vector2i(position))
			var nom := "caisse_grande" if h % 3 == 0 else "caisse"
			_habiller(nom, emprise(), h % 2 == 0, Palette.CAISSE_BOIS, Palette.CAISSE_BOIS_FACE, Palette.CAISSE_BOIS_COTE)


## i-ème morceau (sur n) de l'emprise, découpée dans sa longueur.
func _morceau(i: int, n: int, long_en_x: bool) -> Rect2:
	var e := emprise()
	if long_en_x:
		return Rect2(e.position.x + e.size.x * i / n, e.position.y, e.size.x / n, e.size.y)
	return Rect2(e.position.x, e.position.y + e.size.y * i / n, e.size.x, e.size.y / n)


func _habiller(nom: String, morceau: Rect2, long_en_x: bool, dessus: Color, face: Color, cote: Color, teinte := Color.WHITE) -> void:
	if Images.existe(nom):
		Iso.habiller(nom, morceau, _vue, Iso.miroir_pour(nom, long_en_x), teinte)
	else:
		_secours(morceau, hauteur, dessus, face, cote)


## Dessin de secours : boîte isométrique en aplats, triée sur son coin avant.
func _secours(morceau: Rect2, haut: float, dessus: Color, face: Color, cote: Color) -> void:
	var boite := Node2D.new()
	var c := Iso.coins(morceau)
	boite.position = c[1]
	for i in c.size():
		c[i] -= boite.position
	boite.draw.connect(func() -> void: Dessin.boite_iso(boite, c, haut, dessus, face, cote))
	_vue.add_child(boite)


## Flaque de lumière de lune froide au sol, devant une fenêtre.
func _ajouter_lune(morceau: Rect2) -> void:
	if _texture_lune == null:
		var degrade := Gradient.new()
		degrade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		_texture_lune = GradientTexture2D.new()
		_texture_lune.gradient = degrade
		_texture_lune.width = 128
		_texture_lune.height = 128
		_texture_lune.fill = GradientTexture2D.FILL_RADIAL
		_texture_lune.fill_from = Vector2(0.5, 0.5)
		_texture_lune.fill_to = Vector2(1.0, 0.5)
	var lune := PointLight2D.new()
	lune.texture = _texture_lune
	lune.texture_scale = 2.6
	lune.color = Palette.LUNE
	lune.energy = 0.6
	# Au sol, devant le milieu de la fenêtre
	var devant := morceau.get_center() + (Vector2(0, 110) if taille.x >= taille.y else Vector2(110, 0))
	lune.position = Iso.ecran(devant)
	_vue.add_child(lune)
