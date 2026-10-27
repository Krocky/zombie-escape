extends StaticBody2D
## Obstacle du décor : mur, étagère, caisse...
## position = milieu du bord bas de l'emprise au sol (coordonnées monde).
## Affichage isométrique (voir Iso) : le niveau place visuels() dans ses calques.

enum Style { MUR, ETAGERE, CAISSE, BLOC }   # BLOC : bloc de béton (parking de la base), image BLOC_IMAGE ou dessin en code

@export var taille := Vector2(200, 60)   # emprise au sol (collision)
@export var hauteur := 60.0              # hauteur du dessin de secours (pixels d'écran)
@export var style := Style.MUR
## Fenêtres du mur : position (x ou y local, selon le sens du mur) de leur centre.
@export var fenetres := PackedFloat32Array()
## Portes (même repère) : le pan de mur à cet endroit n'est pas dessiné (la porte le remplace).
@export var portes := PackedFloat32Array()
## Mur de devant (en bas de l'écran) : un simple rebord bas, sinon il cacherait la pièce.
@export var rebord := false
## Image du décor (V3, ex. « prop_sofa_2c », ou « wall_house » pour un mur) ; le dessin du style reste en
## secours si elle manque. Meuble : l'emprise (collision) prend les proportions de l'image, découpée en
## rayons si `taille` est bien plus longue. Mur : pan de mur à la place de « mur » (fenêtres peintes dessus).
@export var image := ""
## Cloison intérieure basse (`rebord`) : on passe des deux côtés, elle est donc dessinée en tronçons triés
## chacun (sinon elle passerait par-dessus un meuble ou un personnage juste derrière elle).
@export var cloison := false

const LONGUEUR_PANNEAU := 200.0   # longueur d'un pan de mur (monde), voir Sortie
const LONGUEUR_RAYON := 140.0     # longueur d'un rayon d'étagère (monde)
const HAUTEUR_REBORD := 18.0
const LONGUEUR_TRONCON := 40.0    # tronçons d'une cloison (voir `cloison`)
const BLOC_IMAGE := "prop_concrete_block"   # image V5 du bloc de béton (posée sur l'emprise, sans en changer la taille)

static var _texture_lune: GradientTexture2D

var _vue := Node2D.new()   # dans le calque Vue (trié en profondeur)
var _sol := Node2D.new()   # dans le calque du sol (ombre)
var _image_ecran := Rect2()   # image du meuble à l'écran (transparence quand le héros est derrière)


func _ready() -> void:
	if style != Style.MUR and image != "" and Images.existe(image):
		taille = Iso.taille_image(image, taille)[0]
	var forme := RectangleShape2D.new()
	forme.size = taille
	var collision := CollisionShape2D.new()
	collision.shape = forme
	collision.position = Vector2(0, -taille.y / 2.0)
	add_child(collision)
	_vue.y_sort_enabled = true
	# Ombre douce au sol (les images V3 ont déjà la leur)
	if style != Style.MUR and not Images.v3_existe(image) and not (style == Style.BLOC and Images.existe(BLOC_IMAGE)):
		_sol.draw.connect(func() -> void: Iso.ombre(_sol, emprise(), 0.8))
	_construire()


## Nœuds d'affichage, placés par le niveau : {"vue": ..., "sol": ...}.
func visuels() -> Dictionary:
	return {"vue": _vue, "sol": _sol}


func emprise() -> Rect2:
	return Rect2(global_position + Vector2(-taille.x / 2.0, -taille.y), taille)


## Appelé par le niveau à chaque pas : un meuble haut devient transparent quand le héros est caché derrière.
## `pieds` = pieds du héros à l'écran (Vector2.INF s'il n'y a rien à montrer).
func voir_a_travers(pieds: Vector2, delta: float) -> void:
	if _image_ecran.size == Vector2.ZERO:
		return
	var vise := Iso.opacite_devant(_image_ecran, Iso.coins(emprise()), pieds)
	_vue.modulate.a = move_toward(_vue.modulate.a, vise, delta * 3.0)


func _construire() -> void:
	var long_en_x := taille.x >= taille.y
	var longueur := maxf(taille.x, taille.y)
	if style != Style.MUR and image != "" and Images.existe(image):
		# Meuble en image : un morceau par rayon (une seule image le plus souvent)
		var n: int = Iso.taille_image(image, taille)[1]
		for i in n:
			var r := Iso.habiller(image, _morceau(i, n, long_en_x), _vue, Iso.miroir_pour(image, long_en_x))
			_image_ecran = r if i == 0 else _image_ecran.merge(r)
		return
	match style:
		Style.MUR:
			if rebord and cloison:
				var troncons := maxi(ceili(longueur / LONGUEUR_TRONCON), 1)
				for i in troncons:
					_troncon(_morceau(i, troncons, long_en_x))
				return
			if rebord:
				_secours(emprise(), HAUTEUR_REBORD, Palette.MUR, Palette.MUR_FACE, Palette.MUR_COTE)
				return
			var n := maxi(roundi(longueur / LONGUEUR_PANNEAU), 1)
			var pan := image if image != "" and Images.v3_existe(image) else "mur"
			for i in n:
				var morceau := _morceau(i, n, long_en_x)
				var milieu := -longueur / 2.0 + longueur * (i + 0.5) / n
				var nom := pan
				var porte := false
				for p in portes:
					porte = porte or absf(p - milieu) < longueur / n / 2.0
				if porte:
					continue
				for f in fenetres:
					if absf(f - milieu) < longueur / n / 2.0:
						nom = Images.v3_fenetre(pan) if pan != "mur" else "mur_fenetre"
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
		Style.BLOC:
			if Images.existe(BLOC_IMAGE):
				Iso.habiller(BLOC_IMAGE, emprise(), _vue, Iso.miroir_pour(BLOC_IMAGE, long_en_x))
			else:
				_secours(emprise(), hauteur, Palette.BETON, Palette.BETON_FACE, Palette.BETON_COTE)


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


## Tronçon de cloison : même boîte que _secours, mais en une seule commande de dessin (faces et contour en
## un tableau de triangles : ils se regroupent avec les autres tronçons), car une cloison compte beaucoup de tronçons.
func _troncon(morceau: Rect2) -> void:
	var boite := Node2D.new()
	var c := Iso.coins(morceau)
	boite.position = c[1]
	for i in c.size():
		c[i] -= boite.position
	var h := Vector2(0, -HAUTEUR_REBORD)
	var points := PackedVector2Array()
	var couleurs := PackedColorArray()
	var triangles := PackedInt32Array()
	var faces := [[[c[0], c[1], c[1] + h, c[0] + h], Palette.MUR_FACE], [[c[1], c[2], c[2] + h, c[1] + h], Palette.MUR_COTE],
		[[c[0] + h, c[1] + h, c[2] + h, c[3] + h], Palette.MUR]]
	# Contour : chaque trait est un rectangle mince, prolongé d'une demi-épaisseur pour fermer les angles
	for segment in [[c[0], c[1]], [c[1], c[2]], [c[2], c[2] + h], [c[2] + h, c[3] + h], [c[3] + h, c[0] + h],
			[c[0] + h, c[0]], [c[0] + h, c[1] + h], [c[1] + h, c[2] + h], [c[1], c[1] + h]]:
		var d: Vector2 = (segment[1] - segment[0]).normalized() * Dessin.EPAISSEUR / 2.0
		var n := d.orthogonal()
		faces.append([[segment[0] - d + n, segment[1] + d + n, segment[1] + d - n, segment[0] - d - n], Palette.CONTOUR])
	for face in faces:
		var debut := points.size()
		for p: Vector2 in face[0]:
			points.append(p)
			couleurs.append(face[1])
		for i in [0, 1, 2, 0, 2, 3]:
			triangles.append(debut + i)
	boite.draw.connect(func() -> void:
		RenderingServer.canvas_item_add_triangle_array(boite.get_canvas_item(), triangles, points, couleurs))
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
