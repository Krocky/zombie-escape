extends StaticBody2D
## Une cachette : carton ou congélateur (supermarché), armoire, dessous de lit ou baignoire (maison).
## Le héros s'y cache tout près. Image V3 (meubles), sinon V2 (carton, congélateur), sinon dessin en code
## (formes simples). Avec une image, l'emprise (collision) prend ses proportions (même grand côté).
## position = milieu du bord bas de l'emprise au sol (coordonnées monde).
## Affichage isométrique (voir Iso) : le niveau place visuels() dans ses calques.

enum Style { CARTON, CONGELATEUR, ARMOIRE, LIT, BAIGNOIRE }

@export var style := Style.CARTON
@export var taille := Vector2(110, 70)   # emprise au sol (collision)
@export var hauteur := 70.0              # hauteur du dessin de secours (pixels d'écran)

## Images de chaque style, la première qui existe est utilisée.
const IMAGES := {
	Style.CARTON: ["prop_cardboard", "carton"],
	Style.CONGELATEUR: ["prop_freezer", "congelateur"],
	Style.ARMOIRE: ["prop_wardrobe"],
	Style.LIT: ["prop_bed_2c"],
	Style.BAIGNOIRE: ["prop_bathtub_2c"],
}
## Où se montrent les yeux du héros caché, en pixels de l'image V3 (non retournée) : entre les portes
## de l'armoire, en bas du cadre du lit, au-dessus du bord de la baignoire, sous le couvercle du congélateur.
const YEUX := {
	"prop_wardrobe": Vector2(300, 330),
	"prop_bed_2c": Vector2(455, 512),
	"prop_bathtub_2c": Vector2(450, 960),
	"prop_freezer": Vector2(228, 168),
	"prop_cardboard": Vector2(200, 100),
}
## Images V5 qui gardent l'emprise de la scène (pas ses proportions : la collision ne change pas)
const TAILLE_FIXE := ["prop_cardboard"]

var _occupee := false
var _temps := 0.0
var _vue := Node2D.new()      # dans le calque Vue (trié en profondeur)
var _sol := Node2D.new()      # dans le calque du sol (ombre)
var _dessus := Node2D.new()   # par-dessus la cachette : les yeux du héros caché
var _haut_dessus := Vector2.ZERO   # milieu du dessus, à l'écran
var _secousse := 0.0
var _image_ecran := Rect2()   # image à l'écran (transparence quand le héros est derrière)


## Distance entre un point et le bord de la cachette (0 si dedans).
func distance_a(point: Vector2) -> float:
	var emprise := Rect2(global_position + Vector2(-taille.x / 2.0, -taille.y), taille)
	var proche := point.clamp(emprise.position, emprise.end)
	return point.distance_to(proche)


func occuper(occupee: bool) -> void:
	_occupee = occupee
	_secousse = 0.3
	_dessus.queue_redraw()


## Nœuds d'affichage, placés par le niveau : {"vue": ..., "sol": ...}.
func visuels() -> Dictionary:
	return {"vue": _vue, "sol": _sol}


func _ready() -> void:
	var nom := ""
	for n: String in IMAGES[style]:
		if nom == "" and Images.existe(n):
			nom = n
	if Images.v3_existe(nom) and not nom in TAILLE_FIXE:
		taille = Iso.taille_image(nom, taille)[0]
	var forme := RectangleShape2D.new()
	forme.size = taille
	var collision := CollisionShape2D.new()
	collision.shape = forme
	collision.position = Vector2(0, -taille.y / 2.0)
	add_child(collision)
	var emprise := Rect2(global_position + Vector2(-taille.x / 2.0, -taille.y), taille)
	var c := Iso.coins(emprise)
	_vue.y_sort_enabled = true
	if not Images.v3_existe(nom):   # les images V3 ont déjà leur ombre
		_sol.draw.connect(func() -> void: Iso.ombre(_sol, emprise, 0.8))
	var haut_image := hauteur
	var miroir := Iso.miroir_pour(nom, taille.x >= taille.y) if nom != "" else false
	if nom != "":
		_image_ecran = Iso.habiller(nom, emprise, _vue, miroir)
		haut_image = Iso.hauteur_image(nom, emprise) * 0.62
	else:
		var boite := Node2D.new()
		boite.position = c[1]
		boite.draw.connect(func() -> void: _dessiner_meuble(boite, emprise))
		_vue.add_child(boite)
	# Les yeux se dessinent juste après la cachette (trié un pixel plus bas que son coin avant)
	_dessus.position = c[1] + Vector2(0, 1)
	_haut_dessus = (c[0] + c[2]) * 0.5 - Vector2(0, haut_image) - _dessus.position
	if YEUX.has(nom):
		_haut_dessus = Iso.point_image(nom, emprise, YEUX[nom], miroir) - _dessus.position
	elif style == Style.LIT:
		# Sous le lit : les yeux dépassent en bas, sous le matelas
		_haut_dessus = (c[0] + c[1]) * 0.5 - Vector2(0, 9) - _dessus.position
	_dessus.draw.connect(_dessiner_dessus)
	_vue.add_child(_dessus)


## Appelé par le niveau à chaque pas : la cachette devient transparente quand le héros est caché derrière.
## `pieds` = pieds du héros à l'écran (Vector2.INF s'il n'y a rien à montrer).
func voir_a_travers(pieds: Vector2, delta: float) -> void:
	if _image_ecran.size == Vector2.ZERO:
		return
	var emprise := Rect2(global_position + Vector2(-taille.x / 2.0, -taille.y), taille)
	var vise := Iso.opacite_devant(_image_ecran, Iso.coins(emprise), pieds)
	_vue.modulate.a = move_toward(_vue.modulate.a, vise, delta * 3.0)


func _process(delta: float) -> void:
	# La cachette tremble un instant (de côté seulement : le tri en profondeur ne bouge pas)
	if _secousse > 0.0:
		_secousse = maxf(_secousse - delta, 0.0)
		_vue.position.x = sin(_secousse * 70.0) * 4.0 * _secousse / 0.3
	if _occupee:
		_temps += delta
		_dessus.queue_redraw()


## Dessin en code (secours, ou styles sans image) : boîtes isométriques en aplats, relatives au coin avant.
func _dessiner_meuble(ci: Node2D, emprise: Rect2) -> void:
	var origine: Vector2 = Iso.coins(emprise)[1]
	match style:
		Style.ARMOIRE:
			_boite(ci, origine, emprise, 0.0, hauteur, Palette.ARMOIRE, Palette.ARMOIRE_FACE, Palette.ARMOIRE_COTE)
			# Deux portes sur la grande face visible, avec leurs poignées
			var c := _coins(origine, emprise)
			var a: Vector2 = c[0] if taille.x >= taille.y else c[2]
			var milieu := (a + c[1]) * 0.5
			var h := Vector2(0, -hauteur)
			ci.draw_line(milieu + Vector2(0, -6), milieu + h * 0.94, Palette.CONTOUR, Dessin.EPAISSEUR * 0.6)
			for cote: float in [-1.0, 1.0]:
				var poignee := milieu + h * 0.5 + (a - c[1]).normalized() * 9.0 * cote
				Dessin.cercle(ci, poignee, 3.5, Palette.LAMPE_DOUCE, false)
		Style.LIT:
			# Cadre en bois, matelas, oreiller à la tête (au fond), couverture au pied
			var cadre := hauteur * 0.45
			_boite(ci, origine, emprise, 0.0, cadre, Palette.ARMOIRE, Palette.ARMOIRE_FACE, Palette.ARMOIRE_COTE)
			_boite(ci, origine, emprise.grow(-6), cadre, hauteur - cadre, Palette.LIT_DRAP, Palette.LIT_DRAP.darkened(0.2), Palette.LIT_DRAP.darkened(0.35))
			var long_en_x := taille.x >= taille.y
			var longueur := maxf(taille.x, taille.y)
			var pied := Rect2(emprise.position + (Vector2(longueur * 0.35, 0) if long_en_x else Vector2(0, longueur * 0.35)),
				emprise.size - (Vector2(longueur * 0.35, 0) if long_en_x else Vector2(0, longueur * 0.35)))
			_boite(ci, origine, pied.grow(-3), hauteur - 2.0, 6.0, Palette.LIT_COUVERTURE, Palette.LIT_COUVERTURE.darkened(0.2), Palette.LIT_COUVERTURE.darkened(0.35))
			var tete := Rect2(emprise.position + Vector2(18, 18), (Vector2(longueur * 0.2, taille.y - 36) if long_en_x else Vector2(taille.x - 36, longueur * 0.2)))
			_boite(ci, origine, tete, hauteur - 2.0, 8.0, Palette.LIT_DRAP, Palette.LIT_DRAP.darkened(0.2), Palette.LIT_DRAP.darkened(0.35))
		Style.BAIGNOIRE:
			# Bac émaillé, creux sombre sur le dessus, robinet à un bout
			_boite(ci, origine, emprise, 0.0, hauteur, Palette.BAIGNOIRE, Palette.BAIGNOIRE_FACE, Palette.BAIGNOIRE_COTE)
			var creux := _coins(origine, emprise.grow(-14))
			var h := Vector2(0, -hauteur)
			Dessin.polygone(ci, PackedVector2Array([creux[0] + h, creux[1] + h, creux[2] + h, creux[3] + h]), Palette.BAIGNOIRE_EAU)
			var bout := _coins(origine, emprise)[3].lerp(_coins(origine, emprise)[0] if taille.x < taille.y else _coins(origine, emprise)[2], 0.5)
			Dessin.cercle(ci, bout + h + Vector2(0, 4), 5.0, Palette.BAIGNOIRE_COTE)
		_:
			var couleurs := [Palette.CARTON, Palette.CARTON_FACE, Palette.CARTON_COTE] if style == Style.CARTON \
				else [Palette.CONGELATEUR, Palette.CONGELATEUR_FACE, Palette.CONGELATEUR_COTE]
			_boite(ci, origine, emprise, 0.0, hauteur, couleurs[0], couleurs[1], couleurs[2])


## Coins à l'écran d'un rectangle du monde, relatifs à « origine ».
func _coins(origine: Vector2, r: Rect2) -> PackedVector2Array:
	var c := Iso.coins(r)
	for i in c.size():
		c[i] -= origine
	return c


## Boîte isométrique sur le rectangle « r » du monde, posée à « socle » pixels au-dessus du sol.
func _boite(ci: Node2D, origine: Vector2, r: Rect2, socle: float, haut: float, dessus: Color, face: Color, cote: Color) -> void:
	var c := _coins(origine, r)
	for i in c.size():
		c[i] += Vector2(0, -socle)
	Dessin.boite_iso(ci, c, haut, dessus, face, cote)


func _dessiner_dessus() -> void:
	if not _occupee:
		return
	# Fente sombre et deux yeux qui regardent à gauche et à droite
	Dessin.ellipse(_dessus, _haut_dessus, Vector2(22, 9), Palette.CONTOUR, false)
	var regard := sin(_temps * 1.5) * 2.0
	for dx: float in [-7.0, 7.0]:
		_dessus.draw_circle(_haut_dessus + Vector2(dx, 0), 5.0, Palette.UI_TEXTE)
		_dessus.draw_circle(_haut_dessus + Vector2(dx + regard, 0), 2.2, Palette.CONTOUR)
